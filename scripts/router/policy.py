"""scripts/router/policy.py — pure decision-to-model mapping.

`select(decision, catalog, baseline, token_estimate, escalation) -> Selection`
is the router's one cost-vs-correctness decision. It has **no I/O, no clock, no
config reads** — every input arrives as an argument, so the full branch table
of the decision flowchart (`design.md` "Decision → model policy") is
unit-testable without a server, a classifier, or a network (R1.3).

Targets are **steps on the newest-per-family list** (design.md Key Decision 5,
R5.11–R5.13), never model ids or absolute rungs. `baseline` is the inbound
model; its *family* fixes the inbound slot, so an older generation or a dated
alias sits in the same slot as its family's newest generation. A first ask
resolves `target_slot = clamp(inbound_slot + step, 0, inbound_slot)`; landing on
the inbound slot forwards the inbound id verbatim — never upgraded, not even to
a newer generation of the same family.

Precedence is fixed and implemented in exactly this order (design.md "Policy /
policy.py"):

    escalation ladder -> privacy gate -> confidence floor -> lane x step lookup
    -> long-context walk -> tier cap -> enabled/valid check -> baseline

The tier cap is the clamp's upper bound (the inbound slot), applied before the
walk so the walk can never climb past it. Escalation and privacy picks bypass
the walk, exactly as the flowchart shows (`D`, `E` skip `I`).

Nothing here names a model id, a price, or an endpoint literal — every model
identity comes from `catalog` (the loaded `Catalog` from `config.py`), and
every threshold comes from `catalog.policy` (the loaded `RouterConfig`).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

# Why a `Selection` picked its model. `no_slot` is the one addition to design.md
# Key Decision 5's list: an inbound model whose family has no slot (unknown, or
# every generation disabled) has no step arithmetic to apply, so it passes
# through unchanged (choices.md Pass 25, option a). Labelling that `same_slot`
# would claim a slot comparison that never happened.
REASONS = frozenset(
    {"policy", "low_confidence", "long_context", "privacy_gate", "escalation", "same_slot", "no_slot"}
)

# Step used when the confidence floor trips and `safe_default_step` is unset
# (design.md Key Decision 5: "`safe_default_step` (default `-1`)").
_DEFAULT_SAFE_STEP = -1


@dataclass(frozen=True)
class Selection:
    """The model to call and why.

    `reason` is one of `REASONS`:

    - `policy` — the lane's step picked a lower slot (or the lane had no
      usable bucket, so the inbound id stands).
    - `low_confidence` — the confidence floor tripped; `safe_default_step` picked.
    - `long_context` — the walk moved the candidate up to fit the window.
    - `privacy_gate` — the gate tripped (local model, or the inbound id).
    - `escalation` — one slot above the previously selected model.
    - `same_slot` — the target is the inbound slot; inbound id forwarded verbatim.
    - `no_slot` — the inbound family has no slot; inbound id forwarded verbatim.
    """

    model: str
    reason: str

    def __post_init__(self) -> None:
        if self.reason not in REASONS:
            raise ValueError(f"unknown selection reason {self.reason!r}; expected one of {sorted(REASONS)}")


class DecisionLike(Protocol):
    """Shape `select()` expects from `decision`. Not imported from `classify.py`
    — Rule of Three: two independent readers of one contract is not a reason to
    couple this module to that one.
    """

    @property
    def lane(self) -> str: ...
    @property
    def score(self) -> int: ...
    @property
    def gate_p(self) -> float | None: ...
    @property
    def confidence(self) -> float | None: ...


@dataclass(frozen=True)
class Escalation:
    """Cross-request escalation signal, already resolved by the caller.

    `select()` reads no clock, so the window check (`escalation_window_s`)
    must already have happened before this reaches here — `active=False` is
    the safe default and collapses this request to a plain first ask (R1.7).
    When `active=True`, `previous_model` is the model actually *selected* on
    the prior applied down-route; escalation climbs one slot above its family
    (R1.8), not above the current lane/confidence candidate.
    """

    active: bool = False
    previous_model: str | None = None


# Default `escalation` for callers that have no cross-request state at all.
# A frozen dataclass instance is a safe module-level singleton default — ruff
# B008 objects to calling `Escalation()` in the signature, not to reusing one
# already-built immutable instance.
_NO_ESCALATION = Escalation()


class _NoLocalMarker:
    """Dedicated sentinel type (not bare `object()`) so `_privacy_pick`'s
    three-state return — "didn't trip" (`None`), "tripped, no local model"
    (this marker), "tripped, routed" (`str`) — stays checkable.
    """


_NO_LOCAL = _NoLocalMarker()


def _escalation_slot(escalation: Escalation, catalog, ceiling_slot: int) -> int | None:
    """One slot above the previously selected model's family, bounded by
    `ceiling_slot` and by the end of the list.

    None when escalation isn't active or the previous model's family has no
    slot (treated as "no escalation data" — falls through to the next stage).
    """
    if not escalation.active or escalation.previous_model is None:
        return None
    previous_slot = catalog.slot_of(escalation.previous_model)
    if previous_slot is None:
        return None
    slot = min(previous_slot + 1, ceiling_slot)
    while slot > 0 and catalog.model_at_slot(slot) is None:
        slot -= 1  # ceiling past the strongest slot: stop at the strongest
    return slot


def _privacy_pick(decision: DecisionLike, catalog) -> str | _NoLocalMarker | None:
    """Local model id when the gate trips, else None when it doesn't trip.

    A trip with no local model configured returns `_NO_LOCAL` so the caller
    can tell "gate didn't trip" (None) from "gate tripped, route to the
    inbound model" (R6.2) without guessing from a model id.
    """
    threshold = catalog.policy.thresholds.get("privacy_threshold")
    if threshold is None or decision.gate_p is None or decision.gate_p <= threshold:
        return None
    local_models = catalog.policy.local or {}
    if local_models:
        # Slice 1 simplification: one configured local model is the common case;
        # per-lane local selection is slice 2's concern (task 13).
        return next(iter(local_models))
    return _NO_LOCAL


def _confidence_floor_tripped(decision: DecisionLike, policy) -> bool:
    floor = policy.thresholds.get("confidence_floor")
    return floor is not None and decision.confidence is not None and decision.confidence < floor


def _safe_default_step(policy) -> int:
    step = policy.thresholds.get("safe_default_step")
    return _DEFAULT_SAFE_STEP if step is None else step


def _lane_step(decision: DecisionLike, policy) -> int | None:
    """`[policy.lanes.<lane>].score_buckets` lookup: first bucket whose `max`
    admits `decision.score`, else the last declared bucket. None when the lane
    is undeclared or the bucket carries no `step` (e.g. a legacy `rung` bucket).
    """
    buckets = policy.lanes.get(decision.lane)
    if not buckets:
        return None
    for bucket in buckets:
        if decision.score <= bucket.get("max", 0):
            return bucket.get("step")
    return buckets[-1].get("step")


def _long_context_walk(slot: int, inbound_slot: int, catalog, policy, token_estimate: int) -> int:
    """Step up one slot at a time until the candidate's window holds the
    request (R1.5), never past `inbound_slot`. Only runs when the request
    exceeds `long_context_tokens`; returns `slot` unchanged otherwise.
    """
    gate = policy.thresholds.get("long_context_tokens")
    if gate is None or token_estimate <= gate:
        return slot
    while slot < inbound_slot:
        model_id = catalog.model_at_slot(slot)
        if model_id is not None and catalog.context_window(model_id) >= token_estimate:
            break
        slot += 1
    return slot


def _resolve_slot(catalog, slot: int, inbound_slot: int, baseline: str, reason: str) -> Selection:
    """The inbound slot forwards `baseline` verbatim (R5.13); any other slot
    resolves to its newest-generation id, or `baseline` if that id is missing
    or disabled (the flowchart's enabled/valid check — never raises).
    """
    if slot == inbound_slot:
        return Selection(baseline, reason)
    model_id = catalog.model_at_slot(slot)
    if model_id is None or not catalog.is_enabled(model_id):
        return Selection(baseline, reason)
    return Selection(model_id, reason)


def select(
    decision: DecisionLike,
    catalog,
    baseline: str,
    token_estimate: int,
    escalation: Escalation = _NO_ESCALATION,
) -> Selection:
    """Pick the model to actually call for this request, and say why.

    `decision` is read with plain attribute access — a malformed decision
    raising `AttributeError`/`TypeError` here is intentional (R4.1 names
    "malformed decision" as one of the fail-open trigger classes the caller's
    broad `except` is meant to catch, not something this function should mask).
    """
    inbound_slot = catalog.slot_of(baseline)
    if inbound_slot is None:
        return Selection(baseline, "no_slot")

    policy = catalog.policy

    escalated_slot = _escalation_slot(
        escalation, catalog, inbound_slot + policy.max_tiers_above_baseline
    )
    if escalated_slot is not None:
        return _resolve_slot(catalog, escalated_slot, inbound_slot, baseline, "escalation")

    local_pick = _privacy_pick(decision, catalog)
    if isinstance(local_pick, _NoLocalMarker):
        return Selection(baseline, "privacy_gate")  # R6.2: never down-route
    if local_pick is not None:
        model_id = local_pick if catalog.is_enabled(local_pick) else baseline
        return Selection(model_id, "privacy_gate")

    if _confidence_floor_tripped(decision, policy):
        step, reason = _safe_default_step(policy), "low_confidence"
    else:
        step, reason = _lane_step(decision, policy), "policy"
        if step is None:
            return Selection(baseline, "policy")

    target_slot = max(0, min(inbound_slot + step, inbound_slot))
    if target_slot == inbound_slot:
        return Selection(baseline, "same_slot")

    walked_slot = _long_context_walk(target_slot, inbound_slot, catalog, policy, token_estimate)
    if walked_slot != target_slot:
        reason = "long_context"
    return _resolve_slot(catalog, walked_slot, inbound_slot, baseline, reason)
