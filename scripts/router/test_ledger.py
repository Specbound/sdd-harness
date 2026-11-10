"""Unit tests for scripts/router/ledger.py.

Run via `scripts/router/ledger.test.sh` (wraps `python3 -m unittest`).

Every test constructs its own `Ledger` pointed at a `tempfile.TemporaryDirectory()`
(mirrors `test_policy.py`'s isolation style) — none of these tests ever touch the
real `~/.sdd-router/` paths. Fixture model ids are the same fictitious `m0`..`m4`
ladder `test_policy.py` uses, weakest to strongest, index == rung.
"""

from __future__ import annotations

import dataclasses
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ledger import CallRecord, Ledger, LedgerError, PendingEscalation

# Wire-format timestamp used by ledger.jsonl lines. Duplicated here rather than
# importing ledger._TS_FORMAT — tests construct the on-disk contract from the
# outside, the same boundary classify.py's stub-server tests exercise over a
# real socket rather than an imported helper.
_TS_FORMAT = "%Y-%m-%dT%H:%M:%SZ"

# Fictitious ladder, weakest (m0) to strongest (m4) — same convention as
# test_policy.py's LADDER; index == rung. Used as the `rung_of` callable
# every escalation-detector test below passes to `append()`/`pending_escalation()`.
_RUNG = {"m0": 0, "m1": 1, "m2": 2, "m3": 3, "m4": 4}


def _rung_of(model_id: str) -> int | None:
    return _RUNG.get(model_id)


def _record(**overrides: object) -> CallRecord:
    base: dict[str, object] = {
        "lane": "code",
        "score": 5,
        "gate_p": 0.9,
        "confidence": 0.9,
        "baseline_model": "m2",
        "selected_model": "m0",
        "outcome": "applied",
        "reason": "policy",
        "latency_ms": 50,
        "input_tokens": 100,
        "output_tokens": 200,
        "cost_state": "known",
    }
    base.update(overrides)
    return CallRecord(**base)  # type: ignore[arg-type]


class _TempLedgerTestCase(unittest.TestCase):
    """Base class wiring up one tempdir-backed Ledger per test."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp_path = Path(self._tmp.name)
        self.ledger_path = self.tmp_path / "ledger.jsonl"
        self.stats_path = self.tmp_path / "stats.json"
        self.ledger = Ledger(ledger_path=self.ledger_path, stats_path=self.stats_path)


# ---------------------------------------------------------------------------
# 1. Existing lines byte-identical after new appends (R7.5).
# ---------------------------------------------------------------------------


class LedgerAppendOnlyByteIdenticalTests(_TempLedgerTestCase):
    # Verifies: specs/model-router/requirements.md#7.5
    def test_existing_line_bytes_unchanged_after_second_append(self) -> None:
        self.ledger.append(_record(selected_model="m0", baseline_model="m2"))
        after_first = self.ledger_path.read_bytes()
        self.assertEqual(after_first.count(b"\n"), 1)  # exactly one line so far

        self.ledger.append(_record(selected_model="m1", baseline_model="m3"))
        after_second = self.ledger_path.read_bytes()

        # Actual byte comparison, not re-parsed-equal: the first line's raw
        # bytes must be an unmodified prefix of the file after the append,
        # and the new line must be appended, never inserted/rewritten.
        self.assertTrue(after_second.startswith(after_first))
        self.assertNotEqual(after_second, after_first)
        self.assertEqual(after_second.count(b"\n"), 2)


# ---------------------------------------------------------------------------
# 2. stats.json replaced atomically — temp file + os.replace (design.md).
# ---------------------------------------------------------------------------


class LedgerStatsAtomicReplaceTests(_TempLedgerTestCase):
    def test_stats_json_fully_parseable_and_no_stray_tempfile_after_every_append(
        self,
    ) -> None:
        for i in range(5):
            self.ledger.append(
                _record(selected_model="m0", baseline_model="m2", input_tokens=10 * i)
            )

            # stats.json is never observed half-written: a reader can always
            # fully parse it immediately after an append returns.
            raw = self.stats_path.read_text(encoding="utf-8")
            data = json.loads(raw)
            self.assertEqual(data["schema_version"], 1)

            # _write_stats_atomic's tempfile.mkstemp(prefix=".stats-",
            # suffix=".tmp") is the mechanism under test: os.replace() leaves
            # no stray temp file behind on the success path.
            stray = list(self.tmp_path.glob(".stats-*.tmp"))
            self.assertEqual(stray, [], f"stray atomic-replace tempfile after append {i}")


# ---------------------------------------------------------------------------
# 3. Unwritable ledger does not raise to the caller (closest ref: R4.6
#    fail-open — the module's own OSError-catch-and-warn contract).
# ---------------------------------------------------------------------------


class LedgerUnwritableFailsOpenTests(unittest.TestCase):
    # Verifies: specs/model-router/requirements.md#4.6
    def test_append_does_not_raise_when_ledger_parent_is_unwritable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            # A file where a directory is expected: Path.mkdir(parents=True,
            # exist_ok=True) still raises OSError when the existing path is a
            # non-directory, independent of filesystem permission bits (which
            # a root-run test suite could otherwise bypass).
            blocker = tmp_path / "blocker"
            blocker.write_text("not a directory", encoding="utf-8")
            ledger = Ledger(
                ledger_path=blocker / "ledger.jsonl",
                stats_path=tmp_path / "stats.json",
            )

            try:
                with self.assertLogs("ledger", level="WARNING"):
                    ledger.append(_record())
            except Exception as exc:  # noqa: BLE001 - this IS the assertion
                self.fail(f"append() raised {exc!r} instead of failing open")


# ---------------------------------------------------------------------------
# 4. Escalation detector fires on model-field change inside the window and
#    never reads text (R1.9).
# ---------------------------------------------------------------------------


class LedgerEscalationDetectorTests(_TempLedgerTestCase):
    # Verifies: specs/model-router/requirements.md#1.9
    def test_higher_baseline_tier_inside_window_sets_suspect_escalation(self) -> None:
        self.ledger.append(
            _record(outcome="applied", baseline_model="m2", selected_model="m0")
        )

        self.ledger.append(
            _record(baseline_model="m3", selected_model="m3"),
            rung_of=_rung_of,
            escalation_window_s=120,
        )

        last_line = self.ledger_path.read_text(encoding="utf-8").splitlines()[-1]
        self.assertTrue(json.loads(last_line)["suspect_escalation"])

    # Verifies: specs/model-router/requirements.md#1.9
    def test_outside_window_does_not_set_escalation(self) -> None:
        import datetime as dt

        old_ts = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(seconds=600)).strftime(
            _TS_FORMAT
        )
        old_line = {
            "schema_version": 1,
            "ts": old_ts,
            "lane": "code",
            "score": 5,
            "gate_p": 0.9,
            "confidence": 0.9,
            "baseline_model": "m2",
            "selected_model": "m0",
            "outcome": "applied",
            "reason": "policy",
            "latency_ms": 50,
            "input_tokens": 100,
            "output_tokens": 200,
            "cost_state": "known",
            "suspect_escalation": False,
        }
        self.ledger_path.write_text(json.dumps(old_line) + "\n", encoding="utf-8")

        self.ledger.append(
            _record(baseline_model="m4", selected_model="m4"),
            rung_of=_rung_of,
            escalation_window_s=120,  # old record is 600s old: outside the window
        )

        last_line = self.ledger_path.read_text(encoding="utf-8").splitlines()[-1]
        self.assertFalse(json.loads(last_line)["suspect_escalation"])

    # Verifies: specs/model-router/requirements.md#1.9
    def test_equal_or_lower_baseline_tier_does_not_set_escalation(self) -> None:
        for new_baseline in ("m2", "m1", "m0"):
            with self.subTest(new_baseline=new_baseline):
                tmp = tempfile.TemporaryDirectory()
                try:
                    tmp_path = Path(tmp.name)
                    ledger = Ledger(
                        ledger_path=tmp_path / "ledger.jsonl",
                        stats_path=tmp_path / "stats.json",
                    )
                    ledger.append(
                        _record(outcome="applied", baseline_model="m2", selected_model="m0")
                    )
                    ledger.append(
                        _record(baseline_model=new_baseline, selected_model=new_baseline),
                        rung_of=_rung_of,
                        escalation_window_s=120,
                    )
                    last_line = (tmp_path / "ledger.jsonl").read_text(
                        encoding="utf-8"
                    ).splitlines()[-1]
                    self.assertFalse(json.loads(last_line)["suspect_escalation"])
                finally:
                    tmp.cleanup()

    # Verifies: specs/model-router/requirements.md#1.9
    def test_no_rung_of_supplied_skips_detection_entirely(self) -> None:
        self.ledger.append(
            _record(outcome="applied", baseline_model="m2", selected_model="m0")
        )

        # A jump from m2 to m4 would trigger detection if it ran at all — but
        # rung_of is omitted, so detection must be skipped outright and the
        # record's own default (False) must survive untouched.
        self.ledger.append(_record(baseline_model="m4", selected_model="m4"))

        last_line = self.ledger_path.read_text(encoding="utf-8").splitlines()[-1]
        self.assertFalse(json.loads(last_line)["suspect_escalation"])

    # Verifies: specs/model-router/requirements.md#1.9
    def test_call_record_has_no_text_or_message_field(self) -> None:
        # Confirmed by construction, not by reading source: the detector
        # cannot read message content because CallRecord has no such field
        # for it to read in the first place.
        field_names = {f.name for f in dataclasses.fields(CallRecord)}
        self.assertFalse(field_names & {"text", "message", "content", "body"})


# ---------------------------------------------------------------------------
# 5. PendingEscalation / Ledger.pending_escalation() (R1.8: escalation climbs
#    one rung above what was actually picked, not above the baseline).
# ---------------------------------------------------------------------------


class LedgerPendingEscalationTests(_TempLedgerTestCase):
    # Verifies: specs/model-router/requirements.md#1.8
    def test_pending_escalation_active_with_previous_selected_model(self) -> None:
        self.ledger.append(
            _record(outcome="applied", baseline_model="m2", selected_model="m0")
        )

        result = self.ledger.pending_escalation("m3", _rung_of)

        self.assertTrue(result.active)
        assert result.previous_model is not None  # Optional[str] narrowing before use
        self.assertEqual(result.previous_model, "m0")

    def test_pending_escalation_inactive_with_no_prior_record(self) -> None:
        result = self.ledger.pending_escalation("m3", _rung_of)

        self.assertIsInstance(result, PendingEscalation)
        self.assertFalse(result.active)
        self.assertIsNone(result.previous_model)


# ---------------------------------------------------------------------------
# 6. A down-route plus an escalation nets below the gross figure (R7.5a/7.5b).
#    This only proves the DATA is captured correctly — the actual gross-minus-
#    delta subtraction is task 10's dashboard rollup, not reproduced here.
# ---------------------------------------------------------------------------


class LedgerNetSavingsDataTests(_TempLedgerTestCase):
    # Verifies: specs/model-router/requirements.md#7.5a
    # Verifies: specs/model-router/requirements.md#7.5b
    def test_escalation_delta_bucket_drives_net_below_gross(self) -> None:
        # Test-local weight proxy only (never imported from any pricing
        # module, no dollars) — fabricated the same way test_policy.py
        # fabricates a ladder, just to give the token counts below a
        # comparable per-model weight so "savings" is a non-zero, orderable
        # figure. Rung-ordered, weaker model cheaper.
        weight = {"m0": 1, "m1": 2, "m2": 4, "m3": 8, "m4": 16}

        # Call 1: real down-route, baseline m2 -> selected m0, no escalation.
        self.ledger.append(
            _record(
                outcome="applied",
                baseline_model="m2",
                selected_model="m0",
                input_tokens=100,
                output_tokens=200,
            )
        )
        # Call 2: escalation (m2 -> m3 ranks higher), applied at the
        # escalated tier — detected by the real detector, not hand-set.
        self.ledger.append(
            _record(
                outcome="applied",
                baseline_model="m3",
                selected_model="m3",
                input_tokens=150,
                output_tokens=300,
            ),
            rung_of=_rung_of,
            escalation_window_s=120,
        )

        stats = self.ledger.read_stats()
        lifetime = stats["lifetime"]

        # Escalation's own extra cost landed in the delta buckets, keyed by
        # its selected_model - never reads text, only these integer fields.
        self.assertEqual(lifetime["delta_input_tokens_by_model"].get("m3"), 150)
        self.assertEqual(lifetime["delta_output_tokens_by_model"].get("m3"), 300)
        # The plain buckets are untouched by the escalation flag, call 1's
        # down-route is the only gross-savings input.
        gross = (
            weight["m2"] * (100 + 200)  # call 1's baseline, priced over its own tokens
            - weight["m0"] * (100 + 200)  # call 1's actually-selected model
        )
        delta_cost = weight["m3"] * (
            lifetime["delta_input_tokens_by_model"]["m3"]
            + lifetime["delta_output_tokens_by_model"]["m3"]
        )
        net = gross - delta_cost

        self.assertGreater(gross, 0)  # the down-route alone is a real saving
        self.assertLess(net, gross)  # the escalation's cost erodes it


# ---------------------------------------------------------------------------
# 7. Outcome enum guard (R11.2: exactly three outcome values) — malformed
#    record raises LedgerError before any file is touched.
# ---------------------------------------------------------------------------


class LedgerOutcomeValidationTests(_TempLedgerTestCase):
    # Verifies: specs/model-router/requirements.md#11.2
    def test_invalid_outcome_raises_before_touching_any_file(self) -> None:
        with self.assertRaises(LedgerError):
            self.ledger.append(_record(outcome="bogus"))

        self.assertFalse(self.ledger_path.exists())
        self.assertFalse(self.stats_path.exists())


if __name__ == "__main__":
    unittest.main()
