"""scripts/router/policy.py — pure decision-to-model mapping.

`select(decision, catalog, baseline, token_estimate, escalation) -> str` is the
router's one cost-vs-correctness decision. It has **no I/O, no clock, no config
reads** — every input arrives as an argument, so the full branch table of the
decision flowchart (`design.md` "Decision → model policy") is unit-testable
without a server, a classifier, or a network (R1.3).

Precedence is fixed and implemented in exactly this order (design.md "Policy /
policy.py"):

    escalation ladder -> privacy gate -> confidence floor -> lane x rung lookup
    -> context-window guard -> tier cap -> enabled/valid check -> baseline

The first of {escalation, privacy, confidence floor, lane lookup} that applies
picks the candidate; everything after that is a universal clamp/validation
pass applied to whatever was picked (mirrors the flowchart's `D & E & J & K
--> L` convergence onto one enabled/valid check before the final answer).

Two of those stages are *not* rung-based and bypass the context-window guard
and tier cap entirely, exactly as the flowchart shows (`D`, `E` skip `I`):

- **Escalation** and **privacy** picks are resolved directly (escalation still
  gets its own bound — baseline rung + `max_tiers_above_baseline` — computed
  as part of the escalation ladder itself, not through the first-ask tier cap).
- A **privacy-gate trip with no local model configured** returns the Baseline
  Model outright (R6.2) — never a cheaper remote, and never upgraded either.

Nothing here names a model id, a price, or an endpoint literal — every model
identity comes from `catalog` (the loaded `Catalog` from `config.py`), and
every threshold comes from `catalog.policy` (the loaded `RouterConfig`).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


class DecisionLike(Protocol):
    """Shape `select()` expects from `decision`. Not imported from `classify.py`
    (which doesn't exist yet) — Rule of Three: two independent readers of one
    contract is not a reason to couple this module to that one.
    """

    lane: str
    score: int
    gate_p: float
    confidence: float


@dataclass(frozen=True)
class Escalation:
    """Cross-request escalation signal, already resolved by the caller.

    `select()` reads no clock, so the window check (`escalation_window_s`)
    must already have happened before this reaches here — `active=False` is
    the safe default and collapses this request to a plain first ask (R1.7).
    When `active=True`, `previous_model` is the model actually *selected* on
    the prior applied down-route; escalation climbs one rung above it (R1.8),
    not above the current lane/confidence candidate.
    """

    active: bool = False
    previous_model: str | None = None


# Default `escalation` for callers that have no cross-request state at all
# (e.g. design.md's `handle()` example, which omits the argument entirely).
# A frozen dataclass instance is a safe module-level singleton default — ruff
# B008 objects to calling `Escalation()` directly in the signature, not to
# reusing one already-built immutable instance.
_NO_ESCALATION = Escalation()


def _escalation_rung(escalation: Escalation, catalog, ceiling_rung: int) -> int | None:
    """One rung above the previously selected model, bounded by `ceiling_rung`.

    Returns None when escalation isn't active, or the previous model has
    since fallen out of the catalog (treated as "no escalation data", not a
    failure — falls through to the next precedence stage).
    """
    if not escalation.active or escalation.previous_model is None:
        return None
    previous_rung = catalog.rung_of(escalation.previous_model)
    if previous_rung is None:
        return None
    return min(previous_rung + 1, ceiling_rung)


def _privacy_pick(decision: DecisionLike, catalog) -> str | _NoLocalMarker | None:
    """Local model id when the gate trips, else None when it doesn't trip.

    A trip with no local model configured returns the Baseline Model marker
    (`_NO_LOCAL`) so the caller can distinguish "gate didn't trip" (None) from
    "gate tripped, route to baseline" (R6.2) without guessing from a model id.
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


class _NoLocalMarker:
    """Dedicated sentinel type (not bare `object()`) so `_privacy_pick`'s
    three-state return — "didn't trip" (`None`), "tripped, no local model"
    (this marker), "tripped, routed" (`str`) — stays checkable instead of
    widening to `object` everywhere `local_pick` is read.
    """


# Sentinel distinguishing "privacy gate tripped, no local model" from "gate
# didn't trip at all" — see `_privacy_pick`.
_NO_LOCAL = _NoLocalMarker()


def _confidence_floor_tripped(decision: DecisionLike, policy) -> bool:
    floor = policy.thresholds.get("confidence_floor")
    return floor is not None and decision.confidence is not None and decision.confidence < floor


def _lane_rung(decision: DecisionLike, policy) -> int | None:
    """`[policy.lanes.<lane>].score_buckets` lookup: first bucket whose `max`
    admits `decision.score`, else the last (strongest) declared bucket.
    """
    buckets = policy.lanes.get(decision.lane)
    if not buckets:
        return None
    for bucket in buckets:
        if decision.score <= bucket.get("max", 0):
            return bucket.get("rung")
    return buckets[-1].get("rung")


def _absolute_rung(catalog, rung: int) -> int | None:
    """Resolve a possibly-negative, Python-list-style rung to its absolute,
    non-negative index before it can reach `_finalize_rung`'s tier cap.

    `[policy.lanes.<lane>]` buckets may declare `rung = -1` for "strongest"
    (per `Ladder`'s docstring, `model_at`/`model_at_rung` accept negative
    indices) but `min(rung, cap_rung)` only clamps a non-negative `rung` —
    `min(-1, cap_rung)` is always `-1` for any `cap_rung >= 0`, silently
    bypassing the tier cap and violating R1.7. Round-trips through
    `model_at_rung` -> `rung_of` (the same pattern `_escalation_rung` uses)
    to get the absolute index; `None` when the rung can't be resolved at all.
    """
    if rung >= 0:
        return rung
    model_id = catalog.model_at_rung(rung)
    return catalog.rung_of(model_id) if model_id is not None else None


def _context_window_guard(rung: int, catalog, policy, token_estimate: int) -> int:
    """Upgrade to `thresholds.long_context_model` when the request both (a)
    exceeds the configured `long_context_tokens` gate and (b) the candidate's
    own declared window can't hold it (R1.5). Leaves `rung` untouched when
    either condition doesn't hold, or when no fallback model is configured.
    """
    gate = policy.thresholds.get("long_context_tokens")
    if gate is None or token_estimate <= gate:
        return rung
    model_id = catalog.model_at_rung(rung)
    window = catalog.context_window(model_id) if model_id is not None else 0
    if window >= token_estimate:
        return rung
    long_context_model = policy.thresholds.get("long_context_model")
    if not long_context_model:
        return rung
    lc_rung = catalog.rung_of(long_context_model)
    return rung if lc_rung is None else lc_rung


def _finalize_rung(catalog, rung: int, cap_rung: int, baseline: str) -> str:
    """Tier cap + enabled/valid check (flowchart's `L` -> `M`/`N`) for a
    rung-based candidate. Falls back to `baseline` on any miss — never raises.
    """
    rung = min(rung, cap_rung)
    model_id = catalog.model_at_rung(rung)
    if model_id is None or not catalog.is_enabled(model_id):
        return baseline
    return model_id


def _finalize_model(catalog, model_id: str, baseline: str) -> str:
    """Enabled/valid check for a non-rung candidate (privacy/local pick)."""
    if not catalog.is_enabled(model_id):
        return baseline
    return model_id


def select(
    decision: DecisionLike,
    catalog,
    baseline: str,
    token_estimate: int,
    escalation: Escalation = _NO_ESCALATION,
) -> str:
    """Pick the model to actually call for this request, or `baseline` (R4.*).

    `decision` is read with plain attribute access — a malformed decision
    raising `AttributeError`/`TypeError` here is intentional (R4.1 names
    "malformed decision" as one of the fail-open trigger classes the caller's
    broad `except` is meant to catch, not something this function should mask).
    """
    baseline_rung = catalog.rung_of(baseline)
    if baseline_rung is None:
        # R3.6: a model absent from the catalog passes through unchanged.
        return baseline

    policy = catalog.policy
    ceiling_rung = baseline_rung + policy.max_tiers_above_baseline

    escalated_rung = _escalation_rung(escalation, catalog, ceiling_rung)
    if escalated_rung is not None:
        return _finalize_rung(catalog, escalated_rung, ceiling_rung, baseline)

    local_pick = _privacy_pick(decision, catalog)
    if isinstance(local_pick, _NoLocalMarker):
        return baseline  # R6.2: gate tripped, no local model — never down-route
    if local_pick is not None:
        return _finalize_model(catalog, local_pick, baseline)

    if _confidence_floor_tripped(decision, policy):
        rung = catalog.rung_of(policy.thresholds.get("safe_default"))
    else:
        rung = _lane_rung(decision, policy)

    if rung is None:
        return baseline

    rung = _absolute_rung(catalog, rung)
    if rung is None:
        return baseline

    rung = _context_window_guard(rung, catalog, policy, token_estimate)
    return _finalize_rung(catalog, rung, baseline_rung, baseline)
