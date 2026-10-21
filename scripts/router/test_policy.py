"""Unit tests for scripts/router/policy.py.

Run via `scripts/router/policy.test.sh` (wraps `python3 -m unittest`).
`select()` is pure and Protocol-based (see `policy.DecisionLike`), so these
tests build minimal fake `Catalog`/`RouterConfig`/`Decision` doubles instead
of importing `config.py` — no real discovery, no real TOML, no model
identifier or price literal anywhere in this file (mirrors `config.py`'s own
R5.1 contract, applied here to the policy layer's inputs).

Fixture ladder is always `["m0", "m1", "m2", "m3", "m4"]`, weakest (m0) to
strongest (m4) — fictitious ids throughout, same convention as
`test_config.py`.
"""

from __future__ import annotations

import inspect
import sys
import unittest
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from policy import Escalation, select

LADDER = ["m0", "m1", "m2", "m3", "m4"]  # weakest -> strongest, index == rung


# ---------------------------------------------------------------------------
# Test doubles — mirror config.py's real shapes without importing config.py.
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class FakeDecision:
    """Mirrors `policy.DecisionLike`. Deliberately carries no `text`/`message`
    field at all: if `select()` ever read message content, accessing it on
    this double would raise `AttributeError`, not silently succeed.
    """

    lane: str
    score: int
    gate_p: float | None
    confidence: float | None


@dataclass
class FakePolicy:
    """Mirrors the subset of `config.RouterConfig` that `select()` reads."""

    thresholds: dict
    lanes: dict = field(default_factory=dict)
    local: dict = field(default_factory=dict)
    max_tiers_above_baseline: int = 0


@dataclass
class FakeCatalog:
    """Mirrors the subset of `config.Catalog`/`config.Ladder` that
    `select()` calls. `ladder` is a plain list, so `model_at_rung`/`rung_of`
    get Python's own negative-index semantics for free — the same contract
    `config.Ladder.model_at` documents.
    """

    ladder: list
    policy: FakePolicy
    disabled: frozenset = field(default_factory=frozenset)
    windows: dict = field(default_factory=dict)

    def rung_of(self, model_id: str) -> int | None:
        try:
            return self.ladder.index(model_id)
        except ValueError:
            return None

    def model_at_rung(self, rung: int) -> str | None:
        try:
            return self.ladder[rung]
        except IndexError:
            return None

    def is_enabled(self, model_id: str) -> bool:
        return model_id not in self.disabled

    def context_window(self, model_id: str) -> int:
        return self.windows.get(model_id, 10_000_000)


def _thresholds(**overrides) -> dict:
    base = {
        "safe_default": None,
        "confidence_floor": None,
        "privacy_threshold": None,
        "long_context_tokens": None,
        "long_context_model": None,
    }
    base.update(overrides)
    return base


def make_catalog(
    ladder=LADDER,
    thresholds=None,
    lanes=None,
    local=None,
    max_tiers_above_baseline=0,
    disabled=(),
    windows=None,
) -> FakeCatalog:
    return FakeCatalog(
        ladder=list(ladder),
        policy=FakePolicy(
            thresholds=thresholds if thresholds is not None else _thresholds(),
            lanes=lanes or {},
            local=local or {},
            max_tiers_above_baseline=max_tiers_above_baseline,
        ),
        disabled=frozenset(disabled),
        windows=windows or {},
    )


def decision(lane="code", score=0, gate_p=0.0, confidence=1.0) -> FakeDecision:
    return FakeDecision(lane=lane, score=score, gate_p=gate_p, confidence=confidence)


TOKENS = 100  # small request; irrelevant to the context-window guard by default


class EscalationLadderTests(unittest.TestCase):
    """R1.8, R1.9 — escalation climbs one rung, bounded, from model fields only."""

    # Verifies: specs/model-router/requirements.md#1.8
    def test_escalation_climbs_exactly_one_rung_above_previous_model(self):
        catalog = make_catalog(max_tiers_above_baseline=3)
        esc = Escalation(active=True, previous_model="m1")
        result = select(decision(), catalog, baseline="m1", token_estimate=TOKENS, escalation=esc)
        self.assertEqual(result, "m2")

    # Verifies: specs/model-router/requirements.md#1.8
    def test_escalation_bound_never_exceeded(self):
        # ceiling = baseline_rung(1) + max_tiers_above_baseline(1) = 2. The
        # previous model is already at rung 3, so previous+1 (4) must be
        # clamped down to the ceiling (2), never left to overflow upward.
        catalog = make_catalog(max_tiers_above_baseline=1)
        esc = Escalation(active=True, previous_model="m3")
        result = select(decision(), catalog, baseline="m1", token_estimate=TOKENS, escalation=esc)
        self.assertEqual(result, "m2")

    # Verifies: specs/model-router/requirements.md#1.8
    def test_escalation_at_exact_ceiling_is_allowed_not_just_below_it(self):
        catalog = make_catalog(max_tiers_above_baseline=2)
        esc = Escalation(active=True, previous_model="m2")  # ceiling = 0+2=2; prev+1=3 -> capped
        result = select(decision(), catalog, baseline="m0", token_estimate=TOKENS, escalation=esc)
        self.assertEqual(result, "m2")

    # Verifies: specs/model-router/requirements.md#1.9
    def test_escalation_inactive_by_default_falls_through_to_plain_first_ask(self):
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": 0}]})
        # No escalation argument at all — the default must collapse to a
        # plain first ask, never silently escalating.
        result = select(decision(score=0), catalog, baseline="m2", token_estimate=TOKENS)
        self.assertEqual(result, "m0")

    # Verifies: specs/model-router/requirements.md#1.9
    def test_escalation_with_previous_model_no_longer_in_catalog_falls_through(self):
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": 1}]})
        esc = Escalation(active=True, previous_model="retired-model")
        result = select(decision(score=0), catalog, baseline="m2", token_estimate=TOKENS, escalation=esc)
        # Falls through to the lane lookup rather than failing or escalating
        # on data it can't resolve.
        self.assertEqual(result, "m1")


class GateBeatsConfidenceFloorPrecedenceTests(unittest.TestCase):
    """Precedence proof: privacy gate trip is resolved before the confidence
    floor is ever consulted (module docstring's fixed precedence order)."""

    # Verifies: specs/model-router/requirements.md#6.1
    def test_privacy_gate_trip_beats_confidence_floor_when_both_conditions_hold(self):
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.5, confidence_floor=0.9, safe_default="m0"),
            local={"local-model": {}},
        )
        # confidence (0.1) is well below the floor (0.9) AND gate_p (0.9) is
        # above the privacy threshold (0.5) — if confidence floor won, this
        # would select "m0" (safe_default); privacy must win instead.
        d = decision(gate_p=0.9, confidence=0.1)
        result = select(d, catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "local-model")


class PrivacyGateTests(unittest.TestCase):
    """R6.1, R6.2 — privacy gate trip routes local, or never down-routes."""

    # Verifies: specs/model-router/requirements.md#6.1
    def test_privacy_gate_trip_selects_the_configured_local_model(self):
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.5), local={"local-model": {}}
        )
        result = select(decision(gate_p=0.9), catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "local-model")

    # Verifies: specs/model-router/requirements.md#6.1
    def test_privacy_gate_trip_with_disabled_local_model_falls_back_to_baseline(self):
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.5),
            local={"local-model": {}},
            disabled={"local-model"},
        )
        result = select(decision(gate_p=0.9), catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "m3")

    # Verifies: specs/model-router/requirements.md#6.2
    def test_privacy_gate_trip_without_local_model_returns_baseline_COSTLY_BUG_CASE(self):
        """The costliest possible bug (per task 2.2's own text): a gate trip
        with no local model configured must land on the Baseline Model —
        never a cheaper remote (which would leak sensitive content to a
        remote model) and never an upgraded one either (R6.2). `baseline`
        here is deliberately mid-ladder so a wrong answer in *either*
        direction (down to "m0" via the lane bucket, or up via any stray
        escalation/cap logic) would be caught, not just a down-route.
        """
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.5),
            lanes={"code": [{"max": 10, "rung": 0}]},  # would pick "m0" if gate didn't trip
            local={},  # no local model configured at all
        )
        result = select(decision(gate_p=0.9, score=0), catalog, baseline="m2", token_estimate=TOKENS)
        self.assertEqual(result, "m2")

    # Verifies: specs/model-router/requirements.md#6.1
    def test_privacy_gate_not_tripped_exactly_at_threshold_boundary(self):
        # gate_p == threshold is "<=", not ">" — must NOT trip.
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.5),
            lanes={"code": [{"max": 10, "rung": 1}]},
            local={"local-model": {}},
        )
        result = select(decision(gate_p=0.5, score=0), catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "m1")

    # Verifies: specs/model-router/requirements.md#6.1
    def test_privacy_gate_never_trips_when_threshold_unconfigured(self):
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=None),
            lanes={"code": [{"max": 10, "rung": 1}]},
            local={"local-model": {}},
        )
        result = select(decision(gate_p=0.99, score=0), catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "m1")


class ConfidenceFloorTests(unittest.TestCase):
    """R1.4 — low confidence selects the safe default, never a guessed lane."""

    # Verifies: specs/model-router/requirements.md#1.4
    def test_confidence_below_floor_selects_safe_default(self):
        catalog = make_catalog(
            thresholds=_thresholds(confidence_floor=0.6, safe_default="m1"),
            lanes={"code": [{"max": 10, "rung": 4}]},  # would pick "m4" if floor didn't trip
        )
        result = select(decision(confidence=0.2, score=0), catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "m1")

    # Verifies: specs/model-router/requirements.md#1.4
    def test_confidence_exactly_at_floor_boundary_does_not_trip(self):
        catalog = make_catalog(
            thresholds=_thresholds(confidence_floor=0.6, safe_default="m1"),
            lanes={"code": [{"max": 10, "rung": 2}]},
        )
        result = select(decision(confidence=0.6, score=0), catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "m2")

    # Verifies: specs/model-router/requirements.md#1.4
    def test_confidence_floor_unconfigured_skips_straight_to_lane_lookup(self):
        catalog = make_catalog(
            thresholds=_thresholds(confidence_floor=None),
            lanes={"code": [{"max": 10, "rung": 2}]},
        )
        result = select(decision(confidence=0.0, score=0), catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "m2")


class LaneRungLookupTests(unittest.TestCase):
    """Lane x score-bucket candidate selection (design.md flowchart node H)."""

    def test_score_within_bucket_max_selects_that_bucket_rung(self):
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": 1}, {"max": 100, "rung": 3}]})
        result = select(decision(score=5), catalog, baseline="m4", token_estimate=TOKENS)
        self.assertEqual(result, "m1")

    def test_score_above_every_declared_max_falls_to_strongest_declared_bucket(self):
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": 1}, {"max": 100, "rung": 3}]})
        result = select(decision(score=999), catalog, baseline="m4", token_estimate=TOKENS)
        self.assertEqual(result, "m3")

    def test_lane_not_declared_in_policy_returns_baseline(self):
        catalog = make_catalog(lanes={"other-lane": [{"max": 10, "rung": 1}]})
        result = select(decision(lane="code", score=5), catalog, baseline="m2", token_estimate=TOKENS)
        self.assertEqual(result, "m2")


class NegativeRungRegressionTests(unittest.TestCase):
    """R1.7 — the single most important suite in this file.

    Before the fix in `52327dc`, `_finalize_rung` capped a candidate with
    `min(rung, cap_rung)`. That is correct for a non-negative rung, but
    `[policy.lanes.<lane>]` buckets may declare a Python-list-style negative
    rung (`rung = -1` for "strongest" — `templates/router.toml.template`'s
    `[policy.lanes.code]` ships exactly this). `min(-1, cap_rung)` is always
    `-1` for any `cap_rung >= 0`, so the tier cap silently never applied and
    a first ask could be routed to the single strongest model in the
    catalog regardless of the inbound model's tier — the costliest possible
    first-ask bug this policy exists to prevent. `_absolute_rung` fixes this
    by resolving the negative index to its absolute position before the cap
    is applied.
    """

    # Verifies: specs/model-router/requirements.md#1.7
    def test_negative_rung_bucket_still_capped_to_baseline_on_first_ask(self):
        # Baseline sits at the weakest rung; the lane bucket declares the
        # Python-list "strongest" shorthand. Pre-fix, this returned "m4"
        # (the strongest model in the whole catalog). It must return "m0".
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": -1}]})
        result = select(decision(score=0), catalog, baseline="m0", token_estimate=TOKENS)
        self.assertEqual(result, "m0")

    # Verifies: specs/model-router/requirements.md#1.7
    def test_negative_rung_bucket_resolves_correctly_when_within_cap(self):
        # Baseline is already the strongest model, so the negative-rung
        # bucket's resolved target (also strongest) is not above the cap —
        # confirms `_absolute_rung` isn't just defensively collapsing to
        # baseline in every case, it resolves the real target correctly.
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": -1}]})
        result = select(decision(score=0), catalog, baseline="m4", token_estimate=TOKENS)
        self.assertEqual(result, "m4")

    # Verifies: specs/model-router/requirements.md#1.7
    def test_positive_rung_above_baseline_is_also_capped(self):
        # General R1.7 tier cap, independent of the negative-index bug:
        # a plain positive rung above the baseline's rung must be capped too.
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": 3}]})
        result = select(decision(score=0), catalog, baseline="m1", token_estimate=TOKENS)
        self.assertEqual(result, "m1")

    # Verifies: specs/model-router/requirements.md#1.7 (property)
    def test_first_ask_rung_never_exceeds_baseline_rung_across_the_whole_ladder(self):
        """Property: for every baseline rung and every declared lane-bucket
        rung (positive or Python-list-negative) on a plain first ask, the
        resolved model's rung is never strictly above the baseline's rung.
        No escalation, no privacy trip, no confidence floor, no context
        guard, and no disabled models are in play — isolating the tier cap
        itself. Enumerated by hand (project convention; no hypothesis
        dependency — see test_config.py's own property tests)."""
        for baseline_rung, baseline_model in enumerate(LADDER):
            for bucket_rung in list(range(len(LADDER))) + [-1, -2, -len(LADDER)]:
                catalog = make_catalog(lanes={"code": [{"max": 10, "rung": bucket_rung}]})
                result = select(
                    decision(score=0), catalog, baseline=baseline_model, token_estimate=TOKENS
                )
                result_rung = catalog.rung_of(result)
                self.assertIsNotNone(
                    result_rung, f"baseline={baseline_model} bucket_rung={bucket_rung}"
                )
                assert result_rung is not None  # narrow for the type checker
                self.assertLessEqual(
                    result_rung,
                    baseline_rung,
                    f"baseline={baseline_model} bucket_rung={bucket_rung} -> {result}",
                )


class ContextWindowGuardTests(unittest.TestCase):
    """R1.5 — long-context requests upgrade to a model whose window admits
    them, but the tier cap (design.md's fixed precedence order: guard runs
    *before* the cap) still applies to whatever the guard picks."""

    # Verifies: specs/model-router/requirements.md#1.5
    def test_upgrades_to_long_context_model_when_candidate_window_too_small(self):
        catalog = make_catalog(
            thresholds=_thresholds(long_context_tokens=1000, long_context_model="m3"),
            lanes={"code": [{"max": 10, "rung": 1}]},
            windows={"m1": 500, "m3": 1_000_000},
        )
        result = select(decision(score=0), catalog, baseline="m4", token_estimate=5000)
        self.assertEqual(result, "m3")

    # Verifies: specs/model-router/requirements.md#1.5
    def test_leaves_candidate_untouched_when_its_window_already_admits_the_request(self):
        catalog = make_catalog(
            thresholds=_thresholds(long_context_tokens=1000, long_context_model="m3"),
            lanes={"code": [{"max": 10, "rung": 1}]},
            windows={"m1": 1_000_000, "m3": 1_000_000},
        )
        result = select(decision(score=0), catalog, baseline="m4", token_estimate=5000)
        self.assertEqual(result, "m1")

    # Verifies: specs/model-router/requirements.md#1.5
    def test_guard_inactive_when_token_estimate_is_within_the_configured_gate(self):
        catalog = make_catalog(
            thresholds=_thresholds(long_context_tokens=1000, long_context_model="m3"),
            lanes={"code": [{"max": 10, "rung": 1}]},
            windows={"m1": 500, "m3": 1_000_000},
        )
        result = select(decision(score=0), catalog, baseline="m4", token_estimate=500)
        self.assertEqual(result, "m1")

    # Verifies: specs/model-router/requirements.md#1.5
    def test_guard_leaves_rung_unchanged_when_no_long_context_model_configured(self):
        catalog = make_catalog(
            thresholds=_thresholds(long_context_tokens=1000, long_context_model=None),
            lanes={"code": [{"max": 10, "rung": 1}]},
            windows={"m1": 500},
        )
        result = select(decision(score=0), catalog, baseline="m4", token_estimate=5000)
        self.assertEqual(result, "m1")

    # Verifies: specs/model-router/requirements.md#1.5
    def test_tier_cap_applies_after_the_context_window_upgrade_per_fixed_precedence(self):
        # Documented precedence (module docstring / design.md): the guard
        # runs before the tier cap, so an upgrade that would land above the
        # baseline's own rung is still pulled back down to baseline — the
        # inbound model's tier is never exceeded even to satisfy a context
        # need. This is the fixed-order behavior, not a defect.
        catalog = make_catalog(
            thresholds=_thresholds(long_context_tokens=1000, long_context_model="m4"),
            lanes={"code": [{"max": 10, "rung": 0}]},
            windows={"m0": 500, "m4": 1_000_000},
        )
        result = select(decision(score=0), catalog, baseline="m0", token_estimate=5000)
        self.assertEqual(result, "m0")


class TierCapAndEnabledChecksTests(unittest.TestCase):
    """Flowchart terminal states L -> M/N: enabled/valid check, falling back
    to baseline on any miss."""

    def test_disabled_candidate_falls_back_to_baseline(self):
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": 1}]}, disabled={"m1"})
        result = select(decision(score=0), catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "m3")

    def test_enabled_candidate_within_cap_is_applied(self):
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": 1}]})
        result = select(decision(score=0), catalog, baseline="m3", token_estimate=TOKENS)
        self.assertEqual(result, "m1")


class BaselinePassThroughTests(unittest.TestCase):
    """R3.6 — a baseline absent from the catalog passes through unchanged,
    short-circuiting every later stage (escalation, privacy, confidence)."""

    # Verifies: specs/model-router/requirements.md#3.6
    def test_unknown_baseline_passes_through_even_when_privacy_gate_would_trip(self):
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.1), local={"local-model": {}}
        )
        result = select(decision(gate_p=0.99), catalog, baseline="unknown-model", token_estimate=TOKENS)
        self.assertEqual(result, "unknown-model")


class NoMessageTextReadTests(unittest.TestCase):
    """No code path reads message text (task 2.2's own branch-table item)."""

    # Verifies: specs/model-router/requirements.md#1.9
    def test_select_signature_carries_no_text_or_message_parameter(self):
        for name in inspect.signature(select).parameters:
            self.assertNotIn("text", name.lower())
            self.assertNotIn("message", name.lower())

    # Verifies: specs/model-router/requirements.md#1.9
    def test_decision_double_with_no_text_attribute_routes_through_every_stage(self):
        # FakeDecision has exactly four fields: lane, score, gate_p,
        # confidence — no "text"/"message" attribute exists on it at all.
        # If select() (or any helper it calls) ever attempted to read one,
        # this would raise AttributeError instead of silently passing.
        escalation_catalog = make_catalog(max_tiers_above_baseline=1)
        privacy_catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.1), local={"local-model": {}}
        )
        confidence_catalog = make_catalog(
            thresholds=_thresholds(confidence_floor=0.9, safe_default="m0")
        )
        lane_catalog = make_catalog(lanes={"code": [{"max": 10, "rung": 1}]})

        d = decision()
        select(d, escalation_catalog, baseline="m1", token_estimate=TOKENS,
               escalation=Escalation(active=True, previous_model="m1"))
        select(d, privacy_catalog, baseline="m3", token_estimate=TOKENS)
        select(decision(confidence=0.0), confidence_catalog, baseline="m3", token_estimate=TOKENS)
        select(decision(), lane_catalog, baseline="m4", token_estimate=TOKENS)
        # Reaching here without AttributeError is the assertion.


if __name__ == "__main__":
    unittest.main()
