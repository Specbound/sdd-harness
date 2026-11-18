"""Unit tests for scripts/router/policy.py.

Run via `scripts/router/policy.test.sh` (wraps `python3 -m unittest`).
`select()` is pure and Protocol-based (see `policy.DecisionLike`), so these
tests use a minimal fake `Catalog` around a real `config.FamilyList` — the
newest-per-family list is a plain dataclass with no I/O, and using the real
one means `slot_of` resolves families (older generations, dated aliases)
exactly as production does instead of through a second, hand-rolled parser.

Model ids below are fixtures only; `policy.py` itself names none (R5.1).
The fake catalogue deliberately has no `rung_of`/`model_at_rung`: if
`select()` ever touched the rung ladder again it would raise here.
"""

from __future__ import annotations

import dataclasses
import inspect
import sys
import unittest
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from config import FamilyList
from policy import REASONS, Escalation, Selection, select

HAIKU = "claude-haiku-5-5"
SONNET = "claude-sonnet-5-5"
OPUS = "claude-opus-5-5"
FABLE = "claude-fable-5-2"

# Inbound ids that are *not* list entries but resolve to a family's slot.
OLD_OPUS = "claude-opus-4-6"
DATED_HAIKU = "claude-haiku-5-5-20260101"

SLOTS = [HAIKU, SONNET, OPUS, FABLE]  # weakest -> strongest, index == slot
FAMILIES = ["haiku", "sonnet", "opus", "fable"]


# ---------------------------------------------------------------------------
# Test doubles
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class FakeDecision:
    """Mirrors `policy.DecisionLike`. Deliberately carries no `text`/`message`
    field: if `select()` ever read message content, it would raise here.
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
    """Mirrors the subset of `config.Catalog` that `select()` calls."""

    families: FamilyList
    policy: FakePolicy
    disabled: frozenset = field(default_factory=frozenset)
    windows: dict = field(default_factory=dict)

    def slot_of(self, model_id: str) -> int | None:
        return self.families.slot_of(model_id)

    def model_at_slot(self, slot: int) -> str | None:
        return self.families.model_at(slot)

    def is_enabled(self, model_id: str) -> bool:
        return model_id not in self.disabled

    def context_window(self, model_id: str) -> int:
        return self.windows.get(model_id, 10_000_000)


def _thresholds(**overrides) -> dict:
    base = {
        "safe_default_step": None,
        "confidence_floor": None,
        "privacy_threshold": None,
        "long_context_tokens": None,
    }
    base.update(overrides)
    return base


def make_catalog(
    slots=SLOTS,
    families=FAMILIES,
    thresholds=None,
    lanes=None,
    local=None,
    max_tiers_above_baseline=0,
    disabled=(),
    windows=None,
) -> FakeCatalog:
    return FakeCatalog(
        families=FamilyList(slots=list(slots), families=list(families)),
        policy=FakePolicy(
            thresholds=thresholds if thresholds is not None else _thresholds(),
            lanes=lanes or {},
            local=local or {},
            max_tiers_above_baseline=max_tiers_above_baseline,
        ),
        disabled=frozenset(disabled),
        windows=windows or {},
    )


def code_lane(step: int) -> dict:
    """One `code` bucket admitting every score, targeting `step`."""
    return {"code": [{"max": 10, "step": step}]}


def decision(lane="code", score=0, gate_p=0.0, confidence=1.0) -> FakeDecision:
    return FakeDecision(lane=lane, score=score, gate_p=gate_p, confidence=confidence)


TOKENS = 100  # small request; irrelevant to the long-context walk by default


def first_ask(catalog, inbound, token_estimate=TOKENS, d=None) -> Selection:
    return select(d or decision(), catalog, baseline=inbound, token_estimate=token_estimate)


# ---------------------------------------------------------------------------
# Selection contract
# ---------------------------------------------------------------------------


class SelectionContractTests(unittest.TestCase):
    """`select()` returns a frozen `Selection(model, reason)` (Key Decision 5)."""

    def test_select_returns_a_selection(self):
        result = first_ask(make_catalog(lanes=code_lane(-1)), OPUS)
        self.assertIsInstance(result, Selection)
        self.assertEqual(result, Selection(model=SONNET, reason="policy"))

    def test_selection_is_frozen(self):
        result = Selection(model=OPUS, reason="policy")
        with self.assertRaises(dataclasses.FrozenInstanceError):
            result.model = HAIKU  # type: ignore[misc]

    def test_unknown_reason_is_rejected_at_construction(self):
        with self.assertRaises(ValueError):
            Selection(model=OPUS, reason="guess")

    def test_reason_vocabulary_is_exactly_the_documented_set(self):
        self.assertEqual(
            REASONS,
            frozenset(
                {
                    "policy",
                    "low_confidence",
                    "long_context",
                    "privacy_gate",
                    "escalation",
                    "same_slot",
                    "no_slot",
                }
            ),
        )


# ---------------------------------------------------------------------------
# Lane x step lookup and the [0, inbound_slot] clamp
# ---------------------------------------------------------------------------


class StepLookupTests(unittest.TestCase):
    """R5.12 — lane buckets are steps relative to the inbound family's slot."""

    # Verifies: specs/model-router/requirements.md#5.12
    def test_opus_inbound_step_minus_one_selects_sonnet(self):
        result = first_ask(make_catalog(lanes=code_lane(-1)), OPUS)
        self.assertEqual(result, Selection(SONNET, "policy"))

    # Verifies: specs/model-router/requirements.md#5.12
    def test_sonnet_inbound_step_minus_one_selects_haiku(self):
        result = first_ask(make_catalog(lanes=code_lane(-1)), SONNET)
        self.assertEqual(result, Selection(HAIKU, "policy"))

    # Verifies: specs/model-router/requirements.md#5.12
    def test_step_minus_five_clamps_to_the_weakest_slot(self):
        result = first_ask(make_catalog(lanes=code_lane(-5)), OPUS)
        self.assertEqual(result, Selection(HAIKU, "policy"))

    # Verifies: specs/model-router/requirements.md#5.11
    def test_older_generation_inbound_down_routes_to_newest_of_lower_family(self):
        result = first_ask(make_catalog(lanes=code_lane(-1)), OLD_OPUS)
        self.assertEqual(result, Selection(SONNET, "policy"))

    def test_first_bucket_whose_max_admits_the_score_wins(self):
        lanes = {"code": [{"max": 3, "step": -2}, {"max": 6, "step": -1}, {"max": 10, "step": 0}]}
        result = first_ask(make_catalog(lanes=lanes), OPUS, d=decision(score=5))
        self.assertEqual(result, Selection(SONNET, "policy"))

    def test_score_above_every_max_falls_to_the_last_bucket(self):
        lanes = {"code": [{"max": 3, "step": -2}, {"max": 6, "step": -1}]}
        result = first_ask(make_catalog(lanes=lanes), OPUS, d=decision(score=99))
        self.assertEqual(result, Selection(SONNET, "policy"))

    def test_lane_not_declared_returns_inbound_unchanged(self):
        catalog = make_catalog(lanes={"other": [{"max": 10, "step": -2}]})
        result = first_ask(catalog, OPUS)
        self.assertEqual(result, Selection(OPUS, "policy"))

    def test_bucket_without_a_step_returns_inbound_unchanged(self):
        # A pre-amendment `rung =` bucket carries no `step`; it must never be
        # misread as a target (task 14.4 adds the load-time rejection).
        catalog = make_catalog(lanes={"code": [{"max": 10, "rung": 0}]})
        result = first_ask(catalog, OPUS)
        self.assertEqual(result, Selection(OPUS, "policy"))

    def test_disabled_target_falls_back_to_inbound(self):
        catalog = make_catalog(lanes=code_lane(-1), disabled={SONNET})
        result = first_ask(catalog, OPUS)
        self.assertEqual(result, Selection(OPUS, "policy"))


class SameSlotTests(unittest.TestCase):
    """R1.7, R5.13 — the inbound slot forwards the inbound id verbatim."""

    # Verifies: specs/model-router/requirements.md#5.13
    def test_dated_haiku_with_step_zero_is_not_rewritten(self):
        result = first_ask(make_catalog(lanes=code_lane(0)), DATED_HAIKU)
        self.assertEqual(result, Selection(DATED_HAIKU, "same_slot"))

    # Verifies: specs/model-router/requirements.md#5.13
    def test_older_generation_with_step_zero_is_not_upgraded(self):
        result = first_ask(make_catalog(lanes=code_lane(0)), OLD_OPUS)
        self.assertEqual(result, Selection(OLD_OPUS, "same_slot"))

    # Verifies: specs/model-router/requirements.md#5.13
    def test_weakest_inbound_clamped_onto_itself_is_same_slot(self):
        result = first_ask(make_catalog(lanes=code_lane(-1)), DATED_HAIKU)
        self.assertEqual(result, Selection(DATED_HAIKU, "same_slot"))

    # Verifies: specs/model-router/requirements.md#1.7
    def test_positive_step_is_capped_at_the_inbound_slot(self):
        result = first_ask(make_catalog(lanes=code_lane(2)), SONNET)
        self.assertEqual(result, Selection(SONNET, "same_slot"))

    # Verifies: specs/model-router/requirements.md#1.7 (property)
    def test_first_ask_never_exceeds_inbound_slot_and_same_slot_is_verbatim(self):
        """Property: for every inbound id (newest, older, dated) and every
        step in a wide range, a plain first ask lands at or below the inbound
        slot; it returns the inbound id iff the clamped target is the inbound
        slot, and then with reason `same_slot`. Enumerated by hand (project
        convention; no hypothesis dependency)."""
        inbound_ids = SLOTS + [OLD_OPUS, DATED_HAIKU, "claude-sonnet-4-5-20250929"]
        catalog_for = {step: make_catalog(lanes=code_lane(step)) for step in range(-6, 4)}
        for inbound in inbound_ids:
            inbound_slot = FamilyList(SLOTS, FAMILIES).slot_of(inbound)
            assert inbound_slot is not None
            for step, catalog in catalog_for.items():
                label = f"inbound={inbound} step={step}"
                result = first_ask(catalog, inbound)
                expected_slot = max(0, min(inbound_slot + step, inbound_slot))
                if expected_slot == inbound_slot:
                    self.assertEqual(result, Selection(inbound, "same_slot"), label)
                else:
                    self.assertEqual(result, Selection(SLOTS[expected_slot], "policy"), label)


class NoSlotTests(unittest.TestCase):
    """Choices Pass 25 (a) — an inbound family with no slot passes through."""

    # Verifies: specs/model-router/requirements.md#5.13
    def test_unknown_family_inbound_is_returned_unchanged(self):
        result = first_ask(make_catalog(lanes=code_lane(-2)), "claude-nosuch-1-0")
        self.assertEqual(result, Selection("claude-nosuch-1-0", "no_slot"))

    # Verifies: specs/model-router/requirements.md#5.13
    def test_fully_disabled_family_inbound_is_returned_unchanged(self):
        # Opus is wholly disabled, so config.build_family_list gave it no slot.
        catalog = make_catalog(
            slots=[HAIKU, SONNET, FABLE], families=["haiku", "sonnet", "fable"], lanes=code_lane(-1)
        )
        result = first_ask(catalog, OLD_OPUS)
        self.assertEqual(result, Selection(OLD_OPUS, "no_slot"))

    def test_no_slot_short_circuits_even_a_privacy_trip(self):
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.1), local={"local-model": {}}
        )
        result = first_ask(catalog, "unknown-model", d=decision(gate_p=0.99))
        self.assertEqual(result, Selection("unknown-model", "no_slot"))


# ---------------------------------------------------------------------------
# Confidence floor -> safe_default_step
# ---------------------------------------------------------------------------


class ConfidenceFloorTests(unittest.TestCase):
    """R1.4, R5.12 — low confidence selects `safe_default_step`, never a lane."""

    # Verifies: specs/model-router/requirements.md#1.4
    def test_below_floor_uses_safe_default_step(self):
        catalog = make_catalog(
            thresholds=_thresholds(confidence_floor=0.6, safe_default_step=-2),
            lanes=code_lane(0),  # would be same_slot if the floor didn't trip
        )
        result = first_ask(catalog, OPUS, d=decision(confidence=0.2))
        self.assertEqual(result, Selection(HAIKU, "low_confidence"))

    # Verifies: specs/model-router/requirements.md#5.12
    def test_absent_safe_default_step_defaults_to_minus_one(self):
        catalog = make_catalog(thresholds=_thresholds(confidence_floor=0.6), lanes=code_lane(-2))
        result = first_ask(catalog, OPUS, d=decision(confidence=0.2))
        self.assertEqual(result, Selection(SONNET, "low_confidence"))

    # Verifies: specs/model-router/requirements.md#1.4
    def test_exactly_at_floor_does_not_trip(self):
        catalog = make_catalog(
            thresholds=_thresholds(confidence_floor=0.6, safe_default_step=-2),
            lanes=code_lane(-1),
        )
        result = first_ask(catalog, OPUS, d=decision(confidence=0.6))
        self.assertEqual(result, Selection(SONNET, "policy"))

    # Verifies: specs/model-router/requirements.md#5.13
    def test_safe_default_landing_on_inbound_slot_is_same_slot(self):
        catalog = make_catalog(thresholds=_thresholds(confidence_floor=0.6), lanes=code_lane(-1))
        result = first_ask(catalog, DATED_HAIKU, d=decision(confidence=0.2))
        self.assertEqual(result, Selection(DATED_HAIKU, "same_slot"))


# ---------------------------------------------------------------------------
# Long-context walk
# ---------------------------------------------------------------------------


class LongContextWalkTests(unittest.TestCase):
    """R1.5 — walk up one slot at a time until the window fits, never past
    the inbound slot; reason `long_context` only when the walk moved."""

    def _catalog(self, step: int, windows: dict, gate: int | None = 1000) -> FakeCatalog:
        return make_catalog(
            thresholds=_thresholds(long_context_tokens=gate), lanes=code_lane(step), windows=windows
        )

    # Verifies: specs/model-router/requirements.md#1.5
    def test_walks_up_to_the_first_slot_whose_window_fits(self):
        catalog = self._catalog(-2, {HAIKU: 500, SONNET: 1_000_000})
        result = first_ask(catalog, OPUS, token_estimate=5000)
        self.assertEqual(result, Selection(SONNET, "long_context"))

    # Verifies: specs/model-router/requirements.md#1.5
    def test_nothing_below_fits_returns_inbound_id_verbatim(self):
        catalog = self._catalog(-2, {HAIKU: 500, SONNET: 500, OPUS: 500})
        result = first_ask(catalog, OLD_OPUS, token_estimate=5000)
        self.assertEqual(result, Selection(OLD_OPUS, "long_context"))

    # Verifies: specs/model-router/requirements.md#1.5
    def test_candidate_that_already_fits_is_not_walked(self):
        catalog = self._catalog(-2, {HAIKU: 1_000_000})
        result = first_ask(catalog, OPUS, token_estimate=5000)
        self.assertEqual(result, Selection(HAIKU, "policy"))

    # Verifies: specs/model-router/requirements.md#1.5
    def test_request_within_the_gate_is_not_walked(self):
        catalog = self._catalog(-2, {HAIKU: 500})
        result = first_ask(catalog, OPUS, token_estimate=800)
        self.assertEqual(result, Selection(HAIKU, "policy"))

    # Verifies: specs/model-router/requirements.md#1.5
    def test_unconfigured_gate_never_walks(self):
        catalog = self._catalog(-2, {HAIKU: 500}, gate=None)
        result = first_ask(catalog, OPUS, token_estimate=5000)
        self.assertEqual(result, Selection(HAIKU, "policy"))

    # Verifies: specs/model-router/requirements.md#1.5
    def test_target_already_on_inbound_slot_is_same_slot_not_long_context(self):
        catalog = self._catalog(0, {OPUS: 500})
        result = first_ask(catalog, OPUS, token_estimate=5000)
        self.assertEqual(result, Selection(OPUS, "same_slot"))

    # Verifies: specs/model-router/requirements.md#1.5
    def test_low_confidence_candidate_is_walked_too(self):
        catalog = make_catalog(
            thresholds=_thresholds(
                long_context_tokens=1000, confidence_floor=0.6, safe_default_step=-2
            ),
            lanes=code_lane(0),
            windows={HAIKU: 500},
        )
        result = first_ask(catalog, OPUS, token_estimate=5000, d=decision(confidence=0.1))
        self.assertEqual(result, Selection(SONNET, "long_context"))


# ---------------------------------------------------------------------------
# Escalation ladder
# ---------------------------------------------------------------------------


class EscalationTests(unittest.TestCase):
    """R1.8, R1.9 — one slot above the previously selected model's family,
    bounded by inbound slot + `max_tiers_above_baseline`."""

    def _escalate(self, catalog, inbound, previous) -> Selection:
        esc = Escalation(active=True, previous_model=previous)
        return select(decision(), catalog, baseline=inbound, token_estimate=TOKENS, escalation=esc)

    # Verifies: specs/model-router/requirements.md#1.8
    def test_climbs_exactly_one_slot_above_the_previous_model(self):
        result = self._escalate(make_catalog(lanes=code_lane(-2)), OPUS, HAIKU)
        self.assertEqual(result, Selection(SONNET, "escalation"))

    # Verifies: specs/model-router/requirements.md#1.8
    def test_older_generation_previous_model_resolves_by_family(self):
        result = self._escalate(make_catalog(), OPUS, "claude-haiku-4-5-20251001")
        self.assertEqual(result, Selection(SONNET, "escalation"))

    # Verifies: specs/model-router/requirements.md#1.8, specs/model-router/requirements.md#5.13
    def test_reaching_the_inbound_slot_returns_the_inbound_id_verbatim(self):
        result = self._escalate(make_catalog(), OLD_OPUS, SONNET)
        self.assertEqual(result, Selection(OLD_OPUS, "escalation"))

    # Verifies: specs/model-router/requirements.md#1.8
    def test_bound_is_inbound_slot_plus_allowance(self):
        # inbound Sonnet (1) + allowance 1 = ceiling 2. Previous was Opus (2),
        # so previous+1 (Fable, 3) must clamp to Opus.
        catalog = make_catalog(max_tiers_above_baseline=1)
        result = self._escalate(catalog, SONNET, OPUS)
        self.assertEqual(result, Selection(OPUS, "escalation"))

    # Verifies: specs/model-router/requirements.md#1.8
    def test_zero_allowance_never_climbs_above_inbound(self):
        result = self._escalate(make_catalog(max_tiers_above_baseline=0), SONNET, SONNET)
        self.assertEqual(result, Selection(SONNET, "escalation"))

    # Verifies: specs/model-router/requirements.md#1.8
    def test_ceiling_past_the_list_end_stops_at_the_strongest_slot(self):
        result = self._escalate(make_catalog(max_tiers_above_baseline=5), OPUS, FABLE)
        self.assertEqual(result, Selection(FABLE, "escalation"))

    # Verifies: specs/model-router/requirements.md#1.8 (property)
    def test_escalation_slot_matches_the_bounded_oracle(self):
        """Property: for every inbound slot, previous slot, and allowance,
        the escalated slot is min(previous + 1, inbound + allowance, last),
        and the inbound slot itself is always returned verbatim."""
        last = len(SLOTS) - 1
        inbound_ids = {0: DATED_HAIKU, 1: SONNET, 2: OLD_OPUS, 3: FABLE}
        for allowance in range(4):
            catalog = make_catalog(max_tiers_above_baseline=allowance)
            for inbound_slot, inbound in inbound_ids.items():
                for previous_slot, previous in enumerate(SLOTS):
                    label = f"inbound={inbound} prev={previous} allowance={allowance}"
                    result = self._escalate(catalog, inbound, previous)
                    expected = min(previous_slot + 1, inbound_slot + allowance, last)
                    expected_model = inbound if expected == inbound_slot else SLOTS[expected]
                    self.assertEqual(result, Selection(expected_model, "escalation"), label)

    # Verifies: specs/model-router/requirements.md#1.9
    def test_inactive_by_default_is_a_plain_first_ask(self):
        result = first_ask(make_catalog(lanes=code_lane(-2)), OPUS)
        self.assertEqual(result, Selection(HAIKU, "policy"))

    # Verifies: specs/model-router/requirements.md#1.9
    def test_previous_model_with_no_slot_falls_through_to_lane_lookup(self):
        result = self._escalate(make_catalog(lanes=code_lane(-1)), OPUS, "retired-model")
        self.assertEqual(result, Selection(SONNET, "policy"))


# ---------------------------------------------------------------------------
# Privacy gate
# ---------------------------------------------------------------------------


class PrivacyGateTests(unittest.TestCase):
    """R6.1, R6.2 — privacy gate trip routes local, or never down-routes."""

    # Verifies: specs/model-router/requirements.md#6.1
    def test_trip_selects_the_configured_local_model(self):
        catalog = make_catalog(thresholds=_thresholds(privacy_threshold=0.5), local={"local-model": {}})
        result = first_ask(catalog, OPUS, d=decision(gate_p=0.9))
        self.assertEqual(result, Selection("local-model", "privacy_gate"))

    # Verifies: specs/model-router/requirements.md#6.1
    def test_trip_with_disabled_local_model_returns_inbound(self):
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.5),
            local={"local-model": {}},
            disabled={"local-model"},
        )
        result = first_ask(catalog, OPUS, d=decision(gate_p=0.9))
        self.assertEqual(result, Selection(OPUS, "privacy_gate"))

    # Verifies: specs/model-router/requirements.md#6.2
    def test_trip_without_local_model_returns_inbound_COSTLY_BUG_CASE(self):
        """A gate trip with no local model must land on the inbound model —
        never a cheaper remote (leaks sensitive content), never upgraded."""
        catalog = make_catalog(thresholds=_thresholds(privacy_threshold=0.5), lanes=code_lane(-2))
        result = first_ask(catalog, OLD_OPUS, d=decision(gate_p=0.9))
        self.assertEqual(result, Selection(OLD_OPUS, "privacy_gate"))

    # Verifies: specs/model-router/requirements.md#6.1
    def test_exactly_at_threshold_does_not_trip(self):
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.5),
            lanes=code_lane(-1),
            local={"local-model": {}},
        )
        result = first_ask(catalog, OPUS, d=decision(gate_p=0.5))
        self.assertEqual(result, Selection(SONNET, "policy"))

    # Verifies: specs/model-router/requirements.md#6.1
    def test_never_trips_when_threshold_unconfigured(self):
        catalog = make_catalog(lanes=code_lane(-1), local={"local-model": {}})
        result = first_ask(catalog, OPUS, d=decision(gate_p=0.99))
        self.assertEqual(result, Selection(SONNET, "policy"))

    # Verifies: specs/model-router/requirements.md#6.1
    def test_privacy_beats_confidence_floor(self):
        catalog = make_catalog(
            thresholds=_thresholds(privacy_threshold=0.5, confidence_floor=0.9),
            local={"local-model": {}},
        )
        result = first_ask(catalog, OPUS, d=decision(gate_p=0.9, confidence=0.1))
        self.assertEqual(result, Selection("local-model", "privacy_gate"))


# ---------------------------------------------------------------------------
# Reason coverage and hygiene
# ---------------------------------------------------------------------------


class ReasonCoverageTests(unittest.TestCase):
    """Each reason is emitted by its own branch, and every reason is reachable."""

    def test_every_reason_is_emitted_by_exactly_its_branch(self):
        esc = Escalation(active=True, previous_model=HAIKU)
        cases = {
            "policy": first_ask(make_catalog(lanes=code_lane(-1)), OPUS),
            "same_slot": first_ask(make_catalog(lanes=code_lane(0)), OPUS),
            "no_slot": first_ask(make_catalog(lanes=code_lane(-1)), "claude-nosuch-1-0"),
            "low_confidence": first_ask(
                make_catalog(thresholds=_thresholds(confidence_floor=0.5)),
                OPUS,
                d=decision(confidence=0.1),
            ),
            "long_context": first_ask(
                make_catalog(
                    thresholds=_thresholds(long_context_tokens=10),
                    lanes=code_lane(-1),
                    windows={SONNET: 20},
                ),
                OPUS,
                token_estimate=50,
            ),
            "privacy_gate": first_ask(
                make_catalog(thresholds=_thresholds(privacy_threshold=0.5)),
                OPUS,
                d=decision(gate_p=0.9),
            ),
            "escalation": select(
                decision(), make_catalog(), baseline=OPUS, token_estimate=TOKENS, escalation=esc
            ),
        }
        for reason, result in cases.items():
            self.assertEqual(result.reason, reason, reason)
        self.assertEqual(set(cases), set(REASONS))


class SourceHygieneTests(unittest.TestCase):
    """Task 14.2 removes the absolute-rung path and the `long_context_model` key."""

    def test_policy_source_has_no_rung_or_long_context_model_path(self):
        source = (Path(__file__).resolve().parent / "policy.py").read_text(encoding="utf-8")
        for banned in ("_absolute_rung", "long_context_model", "rung_of", "model_at_rung"):
            self.assertNotIn(banned, source, banned)


class NoMessageTextReadTests(unittest.TestCase):
    """No code path reads message text (R1.9)."""

    # Verifies: specs/model-router/requirements.md#1.9
    def test_select_signature_carries_no_text_or_message_parameter(self):
        for name in inspect.signature(select).parameters:
            self.assertNotIn("text", name.lower())
            self.assertNotIn("message", name.lower())


if __name__ == "__main__":
    unittest.main()
