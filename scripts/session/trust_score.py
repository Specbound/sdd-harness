#!/usr/bin/env python3
"""
Trust Score helper for the SDD harness.

Single-user cumulative score over a rolling window. Reads/writes a JSONL
history and rewrites the "Harness Trust Score" line at the top of
`.claude/memory/hot-memory.md`. The score is observability only — it never
gates harness behavior (see docs/SDD-USAGE.md).

Usage:
    # Apply today's delta (from session-judge):
    trust_score.py apply --delta -1.0 --summary "..."
    # Print current score + 7-day delta as JSON:
    trust_score.py show
"""

from __future__ import annotations  # PEP 604 (`X | None`) on Python 3.9 hosts

import argparse
import json
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

DEFAULT_START = 20.0
DAILY_CAP = 4.5
HISTORY = Path(".claude/memory/trust-score.jsonl")
HOT_MEMORY = Path(".claude/memory/hot-memory.md")
OBS_FILE = Path(".claude/memory/observations.md")
METRICS_FILE = Path(".claude/memory/metrics.jsonl")
SCORE_HEADER_PREFIX = "## Harness Trust Score:"


def load_history() -> list[dict]:
    if not HISTORY.is_file():
        return []
    records: list[dict] = []
    for line in HISTORY.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return records


def current_score(history: list[dict]) -> float:
    return history[-1]["score"] if history else DEFAULT_START


def seven_day_delta(history: list[dict]) -> float | None:
    if not history:
        return None
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    older = [r for r in history if datetime.fromisoformat(r["ts"]) < cutoff]
    if not older:
        return None
    return history[-1]["score"] - older[-1]["score"]


def clamp_delta(delta: float) -> float:
    return max(-DAILY_CAP, min(DAILY_CAP, delta))


def clamp_score(score: float) -> float:
    return max(0.0, min(100.0, score))


def arrow(n: float | None) -> str:
    if n is None:
        return "—"
    if n > 0.05:
        return f"▲ +{n:.1f}"
    if n < -0.05:
        return f"▼ {n:.1f}"
    return f"▬ {n:+.1f}"


def format_header(score: float, today_delta: float, seven: float | None) -> str:
    return (
        f"{SCORE_HEADER_PREFIX} {score:.1f}% "
        f"({arrow(today_delta)} today, 7d: {arrow(seven)})"
    )


def rewrite_hot_memory_header(new_line: str) -> bool:
    if not HOT_MEMORY.is_file():
        print(
            f"WARN: {HOT_MEMORY} not found — skipping header rewrite.",
            file=sys.stderr,
        )
        return False
    lines = HOT_MEMORY.read_text(encoding="utf-8").splitlines()
    replaced = False
    for i, line in enumerate(lines):
        if line.startswith(SCORE_HEADER_PREFIX):
            lines[i] = new_line
            replaced = True
            break
    if not replaced:
        # Insert after the first `# ` heading or at the top.
        insert_at = next(
            (i + 1 for i, line in enumerate(lines) if line.startswith("# ")),
            0,
        )
        lines.insert(insert_at, new_line)
        lines.insert(insert_at + 1, "")
    HOT_MEMORY.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return True


def cmd_apply(delta: float, summary: str) -> int:
    history = load_history()
    base = current_score(history)
    capped = clamp_delta(delta)
    new_score = clamp_score(base + capped)
    ts = datetime.now(timezone.utc).isoformat(timespec="seconds")

    # Idempotent same-day guard: if today already has a record, do not double-apply.
    today = date.today().isoformat()
    if history and history[-1]["ts"].startswith(today):
        print(
            json.dumps({
                "status": "skipped",
                "reason": "already applied today",
                "score": base,
            })
        )
        return 0

    record = {
        "ts": ts,
        "delta_raw": delta,
        "delta_applied": capped,
        "score": new_score,
        "summary": summary,
    }
    HISTORY.parent.mkdir(parents=True, exist_ok=True)
    with HISTORY.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")

    history.append(record)
    seven = seven_day_delta(history)
    header = format_header(new_score, capped, seven)
    rewrite_hot_memory_header(header)

    print(json.dumps({
        "status": "applied",
        "score": new_score,
        "delta_applied": capped,
        "delta_raw": delta,
        "seven_day_delta": seven,
        "header": header,
    }))
    return 0


def _tally_tags(tags: str, counts: dict) -> None:
    """Count tag occurrences. Scores are NOT read from here — see _tally_metrics_since."""
    if "session-charge" in tags:
        counts["session_charges"] += 1
    if "memory-gap" in tags:
        counts["memory_gaps"] += 1
    if "loop-debt" in tags:
        counts["loop_debts"] += 1


def _split_observation(line: str) -> tuple[str, str] | None:
    """Split `- YYYY-MM-DD [tag,tag]: text` into (date, tags) by structure.

    Returns None for any line that is not an observation entry.
    """
    if not line.startswith("- ") or "[" not in line or "]:" not in line:
        return None
    date_str, sep, remainder = line[2:].partition(" [")
    if not sep:
        return None
    tags, sep, _ = remainder.partition("]:")
    if not sep:
        return None
    return date_str, tags


def _tally_metrics_since(since: date, counts: dict) -> None:
    """Read session-quality and keep-rate from metrics.jsonl, never from prose.

    These used to be pattern-matched out of the observation text, where
    `(\\d+)%` read "84.5%" as 5 and silently mis-scored the trust battery.
    Idle-routine windows carry no judgement and are skipped.
    """
    if not METRICS_FILE.is_file():
        return
    for line in METRICS_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError as e:
            print(f"WARN: {METRICS_FILE}: {e}", file=sys.stderr)
            continue
        try:
            if date.fromisoformat(rec["date"]) < since:
                continue
        except (KeyError, ValueError):
            continue
        if rec.get("idle"):
            continue
        value = rec.get("value")
        if rec.get("metric") == "session-quality" and isinstance(value, (int, float)):
            if value >= 4:
                counts["sq_high"] += 1
            elif value <= 2:
                counts["sq_low"] += 1
        elif rec.get("metric") == "keep-rate" and isinstance(value, (int, float)) and value >= 80:
            counts["kr_high"] += 1


def _parse_observations_since(since: date) -> dict:
    counts = {"session_charges": 0, "memory_gaps": 0,
              "sq_high": 0, "sq_low": 0, "kr_high": 0, "loop_debts": 0}
    if OBS_FILE.is_file():
        for line in OBS_FILE.read_text(encoding="utf-8").splitlines():
            parsed = _split_observation(line)
            if parsed is None:
                continue
            date_str, tags = parsed
            try:
                entry_date = date.fromisoformat(date_str)
            except ValueError:
                continue
            if entry_date >= since:
                _tally_tags(tags, counts)
    _tally_metrics_since(since, counts)
    return counts


def cmd_auto_score() -> int:
    """Score deterministically from observation tags; no LLM Judge needed."""
    history = load_history()
    today = date.today()

    if history and history[-1]["ts"].startswith(today.isoformat()):
        print(json.dumps({"status": "skipped", "reason": "already applied today",
                          "score": history[-1]["score"]}))
        return 0

    if history:
        since = date.fromisoformat(history[-1]["ts"][:10]) + timedelta(days=1)
    else:
        since = today

    c = _parse_observations_since(since)
    charges = min(c["session_charges"], 3)
    gaps = min(c["memory_gaps"], 3)
    sq_hi = min(c["sq_high"], 1)
    sq_lo = min(c["sq_low"], 1)
    kr_hi = min(c["kr_high"], 1)
    loop_debts = min(c.get("loop_debts", 0), 2)

    delta = float(charges + sq_hi + kr_hi - gaps * 2 - sq_lo - loop_debts)

    parts = []
    if charges:
        parts.append(f"{charges} approval(s)")
    if sq_hi:
        parts.append("session-quality≥4/5")
    if kr_hi:
        parts.append("keep-rate≥80%")
    if gaps:
        parts.append(f"{gaps} re-explanation(s)")
    if sq_lo:
        parts.append("session-quality≤2/5")
    if loop_debts:
        parts.append(f"{loop_debts} loop-debt(s)")
    summary = "auto-score: " + (", ".join(parts) if parts else "no signals detected")

    return cmd_apply(delta, summary)


def cmd_show() -> int:
    history = load_history()
    score = current_score(history)
    seven = seven_day_delta(history)
    last_delta = history[-1]["delta_applied"] if history else 0.0
    print(json.dumps({
        "score": score,
        "last_delta_applied": last_delta,
        "seven_day_delta": seven,
        "header": format_header(score, last_delta, seven),
        "records": len(history),
    }, indent=2))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_apply = sub.add_parser("apply", help="Apply a daily delta")
    p_apply.add_argument("--delta", type=float, required=True)
    p_apply.add_argument("--summary", type=str, default="")

    sub.add_parser("show", help="Show current score")
    sub.add_parser("auto-score", help="Score deterministically from observations.md tags")

    args = ap.parse_args()
    if args.cmd == "apply":
        return cmd_apply(args.delta, args.summary)
    if args.cmd == "show":
        return cmd_show()
    if args.cmd == "auto-score":
        return cmd_auto_score()
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
