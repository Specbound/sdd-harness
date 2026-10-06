"""scripts/router/ledger.py — append-only decision audit log + bounded rollup.

Two files under `~/.sdd-router/` (design.md "Ledger / ledger.py"):

- `ledger.jsonl` — one record per call, append-only, opened `"a"`, flushed
  per line (R7.5). Every line is `json.dumps(..., sort_keys=True)` so two
  runs of the same inputs produce byte-identical output. Lines are never
  rewritten or reordered once written (R7.5: historical savings are not
  retroactively rewritten).
- `stats.json` — lifetime, rolling-30-day, and per-lane rollups, rewritten
  atomically (temp file in the same directory + `os.replace`) after every
  append, so a reader never observes a half-written file.

No dollars anywhere in either file (R7.2/R9.*, enforced structurally — this
module has no price table and no arithmetic that could produce one) and no
message bodies, ever (R11.4) — both files carry only counts, labels, and
model identifiers.

**`window_30d` rollup strategy** (the main design decision in this module):
a true sliding window relative to wall-clock "now", not a calendar bucket.
Rescanning the entire `ledger.jsonl` on every append would be O(lifetime
call count) forever, so instead:

1. Every append adds its own contribution directly into the persisted
   `window_30d` bucket (O(1)).
2. `stats.json` also tracks `window_30d_since` — the timestamp of the oldest
   record currently folded into `window_30d`.
3. Only when that oldest record has *actually* aged out (i.e.
   `window_30d_since` is more than 30 days before "now") does this module
   pay for a rebuild — and even then it reads `ledger.jsonl` **backwards
   from the tail**, stopping the instant it reaches a record older than the
   cutoff (append-only + chronological order guarantees everything before
   that point is also too old). The rebuild is therefore bounded by "how
   many calls happened in the last 30 days," never by total lifetime history,
   and happens only around the (comparatively rare) moment a boundary record
   actually expires rather than on every single call.

This satisfies "don't rescan the whole file on every append" without a
second persisted cache of raw records (`ledger.jsonl` itself is the only
source of truth the rebuild reads from).

`cost_state` is recorded and rolled into `unknown_cost_calls` faithfully
(R8.7's "exclude unknown-cost calls from priced figures" is `dashboard.py`'s
job, not this module's — this module only needs to carry the field
correctly).

Fail-open contract for this module specifically (R4.6): any `OSError` while
writing either file is logged at `warning` level and swallowed — `append()`
returns normally rather than raising. This is the deliberate, narrowly-scoped
exception to CLAUDE.md's no-bare-except rule (same convention `classify.py`
uses for its HTTP-error translation): it catches `OSError` only, never a
bare `except`, and only around the actual file I/O. A malformed *call
record* (bad `outcome`/`reason`/`cost_state`) is a programmer error, not an
I/O fault, and raises `LedgerError` immediately, before any file is touched.

Known limitation, not silently papered over: this module does no file
locking. Concurrent writers racing on `stats.json` can lose an update (last
`os.replace` wins). Single-process use (the only caller that exists today)
is unaffected; multi-process serialization is deferred to whichever task
first needs concurrent writers.
"""

from __future__ import annotations

import contextlib
import datetime as _dt
import json
import logging
import os
import tempfile
from dataclasses import dataclass
from pathlib import Path

_logger = logging.getLogger(__name__)

SCHEMA_VERSION = 1

DEFAULT_LEDGER_PATH = Path.home() / ".sdd-router" / "ledger.jsonl"
DEFAULT_STATS_PATH = Path.home() / ".sdd-router" / "stats.json"

# R11.2 / design.md: exactly these three outcome values, nothing else.
_OUTCOMES = frozenset({"applied", "failed_open", "passthrough"})

# design.md "Ledger / ledger.py": a field lookup, not an inference (R6.4) —
# "privacy_gate" must be distinct from "policy" so gate-driven routes are
# never confused with cost-driven ones.
_REASONS = frozenset(
    {
        "policy",
        "privacy_gate",
        "low_confidence",
        "long_context",
        "tool_loop",
        "no_classifier",
        "error",
    }
)

_COST_STATES = frozenset({"known", "unknown"})

_WINDOW_DAYS = 30

_TS_FORMAT = "%Y-%m-%dT%H:%M:%SZ"


class LedgerError(Exception):
    """Raised for a malformed call record (bad `outcome`/`reason`/`cost_state`).

    This is a programmer-error guard, not the "unwritable ledger" fail-open
    path — it fires before any file is touched, so a caller that passes bad
    data finds out immediately rather than having it silently swallowed.
    """


@dataclass(frozen=True)
class CallRecord:
    """One routing decision, as `append()` expects it.

    `gate_p`/`confidence` are `None` when no classification happened for
    this call (e.g. a tool-loop continuation, or a fail-open before the
    classifier was ever reached) — mirrors `policy.py`'s `DecisionLike`
    Protocol, which allows the same for the identical reason.

    `suspect_escalation` always defaults to `False` here — task 4.1's scope
    is the field existing on every record; the detector that sets it `True`
    is task 4.2, not built yet.
    """

    lane: str
    score: int
    gate_p: float | None
    confidence: float | None
    baseline_model: str
    selected_model: str
    outcome: str
    reason: str
    latency_ms: int
    input_tokens: int
    output_tokens: int
    cost_state: str
    suspect_escalation: bool = False


def _validate(record: CallRecord) -> None:
    if record.outcome not in _OUTCOMES:
        raise LedgerError(f"invalid outcome {record.outcome!r}, must be one of {sorted(_OUTCOMES)}")
    if record.reason not in _REASONS:
        raise LedgerError(f"invalid reason {record.reason!r}, must be one of {sorted(_REASONS)}")
    if record.cost_state not in _COST_STATES:
        raise LedgerError(
            f"invalid cost_state {record.cost_state!r}, must be one of {sorted(_COST_STATES)}"
        )


def _now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime(_TS_FORMAT)


def _parse_iso(ts: str | None) -> _dt.datetime | None:
    """`None` for a missing/unparseable timestamp — treated as "unknown age"
    by callers, never as "now" or "infinitely old" (both would be guesses).
    """
    if ts is None:
        return None
    try:
        return _dt.datetime.strptime(ts, _TS_FORMAT).replace(tzinfo=_dt.timezone.utc)
    except ValueError:
        return None


def _empty_bucket() -> dict:
    return {
        "routed": 0,
        "applied": 0,
        "failed_open": 0,
        "passthrough": 0,
        "input_tokens_by_model": {},
        "output_tokens_by_model": {},
        "baseline_input_tokens_by_model": {},
        "baseline_output_tokens_by_model": {},
        "unknown_cost_calls": 0,
    }


def _ensure_bucket(value: object) -> dict:
    """Fill in any missing keys with defaults; drop unrecognized ones. Keeps
    `_load_stats` tolerant of a hand-edited or older-shape stats.json without
    ever fabricating a figure for a key that was actually missing.
    """
    bucket = _empty_bucket()
    if isinstance(value, dict):
        for key in bucket:
            if key in value:
                bucket[key] = value[key]
    return bucket


def _bump(table: dict, model: str, amount: int) -> None:
    table[model] = table.get(model, 0) + amount


def _add_contribution(
    bucket: dict,
    *,
    outcome: str,
    cost_state: str,
    selected_model: str,
    baseline_model: str,
    input_tokens: int,
    output_tokens: int,
) -> None:
    """Fold one call's fields into `bucket` (lifetime, window_30d, or a
    by_lane entry — same shape, same rule). `selected_model` gets its real
    token counts; `baseline_model` gets the *same* token counts for the
    counterfactual (R7.3: counterfactual = starting model priced over the
    same token counts actually used, not a separately measured call).
    """
    bucket["routed"] += 1
    if outcome in _OUTCOMES:
        bucket[outcome] += 1
    _bump(bucket["input_tokens_by_model"], selected_model, input_tokens)
    _bump(bucket["output_tokens_by_model"], selected_model, output_tokens)
    _bump(bucket["baseline_input_tokens_by_model"], baseline_model, input_tokens)
    _bump(bucket["baseline_output_tokens_by_model"], baseline_model, output_tokens)
    if cost_state == "unknown":
        bucket["unknown_cost_calls"] += 1


def _add_record(bucket: dict, record: CallRecord) -> None:
    _add_contribution(
        bucket,
        outcome=record.outcome,
        cost_state=record.cost_state,
        selected_model=record.selected_model,
        baseline_model=record.baseline_model,
        input_tokens=record.input_tokens,
        output_tokens=record.output_tokens,
    )


def _reverse_lines(path: Path, chunk_size: int = 65536):
    """Yield complete lines of a text file from last to first, without
    loading the whole file at once. Safe because a jsonl line (one
    `json.dumps` call) never contains a literal newline byte, so splitting
    the raw bytes on `b"\\n"` can never cut a line in the wrong place.
    """
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            position = f.tell()
            buffer = b""
            while position > 0:
                read_size = min(chunk_size, position)
                position -= read_size
                f.seek(position)
                chunk = f.read(read_size)
                buffer = chunk + buffer
                lines = buffer.split(b"\n")
                buffer = lines[0]
                for line in reversed(lines[1:]):
                    if line:
                        yield line.decode("utf-8")
            if buffer:
                yield buffer.decode("utf-8")
    except FileNotFoundError:
        return


def _rebuild_window_from_tail(ledger_path: Path, cutoff: _dt.datetime) -> tuple[dict, str | None]:
    """Rebuild `window_30d` by reading `ledger_path` backwards, stopping the
    instant a record older than `cutoff` is reached. Bounded by "how many
    calls happened in the last 30 days", never by total file size.
    """
    bucket = _empty_bucket()
    oldest_ts: str | None = None
    for line in _reverse_lines(ledger_path):
        try:
            obj = json.loads(line)
            ts = obj["ts"]
            ts_dt = _parse_iso(ts)
        except (json.JSONDecodeError, KeyError, TypeError):
            continue  # a corrupt line doesn't abort the rebuild
        if ts_dt is None or ts_dt < cutoff:
            break  # append-only + chronological: everything earlier is too old
        try:
            _add_contribution(
                bucket,
                outcome=obj.get("outcome", ""),
                cost_state=obj.get("cost_state", ""),
                selected_model=obj.get("selected_model", ""),
                baseline_model=obj.get("baseline_model", ""),
                input_tokens=int(obj.get("input_tokens", 0)),
                output_tokens=int(obj.get("output_tokens", 0)),
            )
        except (TypeError, ValueError):
            continue  # a malformed field on one line doesn't abort the rebuild
        oldest_ts = ts
    return bucket, oldest_ts


def _default_stats() -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "lifetime": _empty_bucket(),
        "window_30d": _empty_bucket(),
        "window_30d_since": None,
        "by_lane": {},
    }


class Ledger:
    """Owns `ledger.jsonl` + `stats.json` under one directory.

    `append()` is the single public entry point. Construct one `Ledger` per
    process (or per test, pointed at a temp directory); it holds no state
    beyond the two file paths — every rollup is read from and written back
    to `stats.json` on each call, so it's safe to construct a fresh `Ledger`
    at any time without losing history.
    """

    def __init__(
        self,
        ledger_path: Path | str | None = None,
        stats_path: Path | str | None = None,
    ) -> None:
        self.ledger_path = Path(ledger_path) if ledger_path is not None else DEFAULT_LEDGER_PATH
        self.stats_path = Path(stats_path) if stats_path is not None else DEFAULT_STATS_PATH

    def append(self, record: CallRecord) -> None:
        """Write one record to `ledger.jsonl` and fold it into `stats.json`.

        Raises `LedgerError` for a malformed `record` (programmer error,
        caught before any file is touched). Any `OSError` encountered while
        actually writing either file is logged at `warning` level and
        swallowed — this method then returns normally (R4.6: an unwritable
        ledger logs loud and never breaks the caller).
        """
        _validate(record)
        ts = _now_iso()
        try:
            self._append_jsonl_line(record, ts)
            self._update_stats(record, ts)
        except OSError:
            _logger.warning(
                "ledger write failed for %s under %s; record dropped (fail-open, R4.6)",
                self.ledger_path,
                self.ledger_path.parent,
                exc_info=True,
            )

    def read_stats(self) -> dict:
        """Current persisted rollup, loaded fresh from `stats.json`."""
        return self._load_stats()

    def _append_jsonl_line(self, record: CallRecord, ts: str) -> None:
        line = {
            "schema_version": SCHEMA_VERSION,
            "ts": ts,
            "lane": record.lane,
            "score": record.score,
            "gate_p": record.gate_p,
            "confidence": record.confidence,
            "baseline_model": record.baseline_model,
            "selected_model": record.selected_model,
            "outcome": record.outcome,
            "reason": record.reason,
            "latency_ms": record.latency_ms,
            "input_tokens": record.input_tokens,
            "output_tokens": record.output_tokens,
            "cost_state": record.cost_state,
            "suspect_escalation": record.suspect_escalation,
        }
        self.ledger_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.ledger_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(line, sort_keys=True))
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())

    def _load_stats(self) -> dict:
        try:
            with open(self.stats_path, "r", encoding="utf-8") as f:
                raw = f.read()
        except FileNotFoundError:
            return _default_stats()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            _logger.warning("stats.json at %s is corrupt; rebuilding from defaults", self.stats_path)
            return _default_stats()
        if not isinstance(data, dict) or data.get("schema_version") != SCHEMA_VERSION:
            return _default_stats()
        by_lane_raw = data.get("by_lane")
        by_lane = (
            {lane: _ensure_bucket(bucket) for lane, bucket in by_lane_raw.items()}
            if isinstance(by_lane_raw, dict)
            else {}
        )
        since = data.get("window_30d_since")
        return {
            "schema_version": SCHEMA_VERSION,
            "lifetime": _ensure_bucket(data.get("lifetime")),
            "window_30d": _ensure_bucket(data.get("window_30d")),
            "window_30d_since": since if isinstance(since, str) else None,
            "by_lane": by_lane,
        }

    def _update_stats(self, record: CallRecord, ts: str) -> None:
        stats = self._load_stats()

        _add_record(stats["lifetime"], record)
        lane_bucket = stats["by_lane"].setdefault(record.lane, _empty_bucket())
        _add_record(lane_bucket, record)

        cutoff = _dt.datetime.now(_dt.timezone.utc) - _dt.timedelta(days=_WINDOW_DAYS)
        since_dt = _parse_iso(stats["window_30d_since"])
        if since_dt is not None and since_dt < cutoff:
            # The oldest record folded into window_30d has aged out — rebuild
            # from the ledger tail. The new line was already appended above,
            # so the tail already includes it; no separate add needed.
            bucket, oldest_ts = _rebuild_window_from_tail(self.ledger_path, cutoff)
            stats["window_30d"] = bucket
            stats["window_30d_since"] = oldest_ts
        else:
            _add_record(stats["window_30d"], record)
            if stats["window_30d_since"] is None:
                stats["window_30d_since"] = ts

        self._write_stats_atomic(stats)

    def _write_stats_atomic(self, stats: dict) -> None:
        directory = self.stats_path.parent
        directory.mkdir(parents=True, exist_ok=True)
        fd, tmp_name = tempfile.mkstemp(dir=directory, prefix=".stats-", suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(stats, f, sort_keys=True)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp_name, self.stats_path)
        except OSError:
            with contextlib.suppress(OSError):
                os.unlink(tmp_name)
            raise
