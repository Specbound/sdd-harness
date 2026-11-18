"""scripts/router/config.py — discovered model catalog, generation ladder, policy.

Discovers the Claude model surface the same way `scripts/utils/herder.py:203`
`discover_models()` already does for agent spawning: read
`.dashboard/models-pricing-history.json`, filter by provider prefix, derive
everything else from the ids present. This module does **not** import
`herder.py` — two independent readers of one file is a coincidence, not a
pattern (`CLAUDE.md`'s Rule of Three forbids extracting shared code until a
third caller exists). The file itself is the contract between them.

Tier rungs are **not** a hand-written per-model list. A model's rung is
`(family_rank, generation_tuple)`, where `family_rank` comes from the small,
rarely-touched `[tier_families]` order declared in `router.toml`, and
`generation_tuple` is parsed straight out of the model id (no `re` — this repo
bans it; `str.split("-")` and `str.isdigit()` are enough). Price only orders
models across *undeclared* families and breaks ties when two ids land on the
exact same `(family_rank, generation_tuple)` key — which is also precisely the
dated-alias case: an undated id and its `-YYYYMMDD`-suffixed twin parse to the
same key and collapse onto one rung, with the undated id kept canonical.

Nothing in this file names a model id, a price, or an endpoint literal (R5.1,
R9.4) — every one of those comes from the discovered catalogue or from
`router.toml`, both read at call time.
"""

from __future__ import annotations

import datetime as _dt
import json
from dataclasses import dataclass, field
from pathlib import Path

import tomllib

# Provider prefix used by `.dashboard/models-pricing-history.json`'s model keys
# (e.g. "anthropic/<model id>"). A provider name, not a model identifier or
# a price (R5.1) — the same literal herder.py's PROVIDER_FOR_KIND maps the
# "claude" agent kind to. The router only ever targets the Claude CLI, so one
# constant is enough; a second caller needing a different provider is what
# would turn this into a parameter.
_PROVIDER = "anthropic"

# Anthropic's release-date-suffix convention: exactly 8 digits as the final
# "-"-separated token (e.g. "-20251101"). Stripped before generation parsing so
# a dated alias collapses onto the same rung as its undated sibling (R5.9).
_DATE_SUFFIX_LEN = 8

# The router never fetches pricing itself; it reads whatever cadence
# `dashboard.py`'s load_or_refresh_pricing_history() last wrote (a 14-day
# cadence). A snapshot older than double that cadence is reported stale rather
# than trusted forever (R5.5). This is a cadence constant, not a price or a
# model identifier.
_STALE_AFTER_DAYS = 28


class CatalogError(Exception):
    """Raised only for programmer errors. A bad catalogue degrades; it never raises."""


@dataclass(frozen=True)
class ModelEntry:
    """One discovered model id, as parsed for ladder ranking."""

    model_id: str
    prices: dict
    family: str
    generation: tuple
    family_known: bool


@dataclass(frozen=True)
class Ladder:
    """The discovered model surface ordered weakest (index 0) to strongest (-1).

    Exposes rung lookup both ways: `model_at(rung)` resolves a (possibly
    negative, Python-list-style) rung index to its canonical model id, and
    `rung_of` is a dict resolving any discovered id — canonical or a dated
    alias — to its non-negative rung index.
    """

    groups: list = field(default_factory=list)  # list[list[ModelEntry]], one per rung
    canonical: list = field(default_factory=list)  # list[str], canonical id per rung
    rung_of: dict = field(default_factory=dict)  # any discovered id -> rung index

    def __len__(self) -> int:
        return len(self.canonical)

    def model_at(self, rung: int) -> str | None:
        """Canonical model id at `rung`. Accepts negative indices like a Python list."""
        if not self.canonical:
            return None
        try:
            return self.canonical[rung]
        except IndexError:
            return None

    def entries_at(self, rung: int) -> list:
        """Every discovered `ModelEntry` collapsed onto `rung` (canonical + aliases)."""
        if not self.groups:
            return []
        try:
            return self.groups[rung]
        except IndexError:
            return []


def _harness_root() -> Path:
    """Directory owning both `projects.txt` and `install.sh`. Discovered, not named.

    A standalone copy of `herder.py`'s `harness_root()`, not an import of it —
    see the module docstring's Rule-of-Three note.
    """
    for parent in Path(__file__).resolve().parents:
        if (parent / "projects.txt").is_file() and (parent / "install.sh").is_file():
            return parent
    raise CatalogError(f"cannot locate harness root from {__file__}")


def _staleness_cause(fetched_at: str | None) -> str | None:
    """None when fresh enough (or unjudgeable); else the stated cause (R5.5)."""
    if not fetched_at:
        return None
    try:
        fetched = _dt.datetime.fromisoformat(fetched_at.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None
    if fetched.tzinfo is None:
        fetched = fetched.replace(tzinfo=_dt.timezone.utc)
    age = _dt.datetime.now(_dt.timezone.utc) - fetched
    if age > _dt.timedelta(days=_STALE_AFTER_DAYS):
        return f"pricing catalogue stale: fetched {fetched_at}, older than {_STALE_AFTER_DAYS}d"
    return None


def discover_models(catalogue_path: Path | None = None) -> dict:
    """Mirror `herder.py:203` discover_models()'s `{"models", "discovered", "source"}` shape.

    Returns `models` as `{model_id: prices_dict}` for every entry whose key in
    the latest snapshot starts with the provider prefix. On any failure —
    missing file, no snapshots, unreadable JSON, a stale fetch — `discovered`
    is `False` and `source` states the cause, exactly the failure vocabulary
    `herder.py` already uses, reused rather than re-invented (R5.5).
    """
    path = catalogue_path or (_harness_root() / ".dashboard" / "models-pricing-history.json")
    result = {"models": {}, "discovered": False, "source": f"catalogue not found: {path}"}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        snapshots = data.get("snapshots") or []
        if not snapshots:
            result["source"] = f"{path.name}: no snapshots recorded"
            return result

        latest = snapshots[-1] or {}
        fetched_at = latest.get("fetched_at")
        stale_cause = _staleness_cause(fetched_at)
        if stale_cause:
            result["source"] = stale_cause
            return result

        models = latest.get("models") or {}
        prefix = _PROVIDER + "/"
        entries = {
            key[len(prefix):]: price
            for key, price in models.items()
            if key.startswith(prefix)
        }
        if not entries:
            result["source"] = f"{path.name}: no {_PROVIDER} entries in latest snapshot"
            return result

        result = {
            "models": entries,
            "discovered": True,
            "source": f"{path.name} ({_PROVIDER}, fetched {fetched_at or '?'})",
        }
    except (OSError, ValueError, AttributeError, IndexError) as exc:
        result["source"] = f"pricing catalogue unreadable: {exc}"
    return result


def _valid_price_entry(prices) -> bool:
    """A discovered entry is valid when it carries numeric input/output prices."""
    if not isinstance(prices, dict):
        return False
    input_price, output_price = prices.get("input"), prices.get("output")
    if input_price is None or output_price is None:
        return False
    try:
        float(input_price)
        float(output_price)
    except (TypeError, ValueError):
        return False
    return True


def validate_models(models: dict) -> tuple:
    """Split discovered entries into valid and rejected (R5.8) — reject only what's bad."""
    valid, rejected = {}, {}
    for model_id, prices in models.items():
        if _valid_price_entry(prices):
            valid[model_id] = prices
        else:
            rejected[model_id] = "missing or non-numeric input/output price"
    return valid, rejected


def _has_date_suffix(model_id: str) -> bool:
    tail = model_id.split("-")[-1]
    return len(tail) == _DATE_SUFFIX_LEN and tail.isdigit()


def _parse_family_generation(model_id: str) -> tuple:
    """Split a discovered id into `(family, generation_tuple)`.

    No `re` import (R8.6) — `str.split("-")` and `str.isdigit()` are enough.
    Drops a leading "claude" token (not part of the family name) and a
    trailing release-date suffix before reading the family and the numeric
    generation segments that remain. For a hypothetical family "f": "f-5-5"
    -> `("f", (5, 5))`; "f-5" -> `("f", (5,))`; "f-4-5-20251101" (dated alias)
    -> `("f", (4, 5))`, the same key as the undated "f-4-5".
    """
    tokens = model_id.split("-")
    if tokens and tokens[0] == "claude":
        tokens = tokens[1:]
    if tokens and _has_date_suffix(model_id):
        tokens = tokens[:-1]
    if not tokens:
        return "", ()
    family, rest = tokens[0], tokens[1:]
    generation = tuple(int(tok) for tok in rest if tok.isdigit())
    return family, generation


def build_ladder(models: dict, tier_families: list) -> Ladder:
    """Group valid, discovered entries into rungs ordered weakest(0) -> strongest(-1).

    Sort key is `(family_rank, generation_key, price)`. `family_rank` comes
    from the declared `[tier_families]` order; a family absent from that list
    shares one undifferentiated rank after every listed family, and loses its
    own generation signal too (`generation_key` forced to `()`), so price is
    what orders it against other undeclared families — exactly "price alone
    ... across different families" (R5.3). For a *declared* family, price only
    breaks a tie once `(family_rank, generation_key)` already matches exactly,
    which is also exactly the dated-alias case (R5.9) — an undated id and its
    `-YYYYMMDD`-suffixed twin parse to the same key and collapse onto one
    rung, with the undated id preferred as canonical.
    """
    known_rank = {name: idx for idx, name in enumerate(tier_families)}
    unknown_rank = len(tier_families)

    parsed = []
    for model_id, prices in models.items():
        family, generation = _parse_family_generation(model_id)
        family_known = family in known_rank
        rank = known_rank.get(family, unknown_rank)
        gen_key = generation if family_known else ()
        price = float(prices.get("input", 0.0))
        parsed.append((rank, gen_key, price, model_id, prices, family, generation, family_known))

    parsed.sort(key=lambda row: (row[0], row[1], row[2]))

    groups: list = []
    canonical: list = []
    rung_of: dict = {}
    group_index: dict = {}
    for row in parsed:
        key = (row[0], row[1])
        if key not in group_index:
            group_index[key] = len(groups)
            groups.append([])
        groups[group_index[key]].append(row)

    for rung_idx, group in enumerate(groups):
        for row in group:
            rung_of[row[3]] = rung_idx
        undated = [row for row in group if not _has_date_suffix(row[3])]
        pool = undated or group
        pool_sorted = sorted(pool, key=lambda row: (row[2], row[3]))
        canonical.append(pool_sorted[0][3])
        groups[rung_idx] = [
            ModelEntry(
                model_id=row[3],
                prices=row[4],
                family=row[5],
                generation=row[6],
                family_known=row[7],
            )
            for row in group
        ]

    return Ladder(groups=groups, canonical=canonical, rung_of=rung_of)


@dataclass(frozen=True)
class FamilyList:
    """The newest-per-family list (R5.11, Key Decision 5): one slot per family.

    `slots[i]` is the canonical id of family `families[i]`'s highest enabled
    generation, weakest family (0) first. Policy targets index this list,
    never the full rung ladder, so an older generation is never a target.
    """

    slots: list = field(default_factory=list)  # list[str], canonical id per slot
    families: list = field(default_factory=list)  # list[str], family per slot

    def __len__(self) -> int:
        return len(self.slots)

    def slot_of(self, model_id: str) -> int | None:
        """Slot of `model_id`'s *family* — any generation, dated or not, discovered or not."""
        family, _ = _parse_family_generation(model_id)
        try:
            return self.families.index(family)
        except ValueError:
            return None

    def model_at(self, slot: int) -> str | None:
        """Canonical id at `slot`. Non-negative only: policy clamps, it never wraps."""
        if 0 <= slot < len(self.slots):
            return self.slots[slot]
        return None


def build_family_list(ladder: Ladder, tier_families: list, is_enabled) -> FamilyList:
    """Pick each family's newest enabled generation and order the families.

    Groups the ladder's entries by `(family, generation)` itself rather than by
    rung, because the ladder pools every undeclared family onto one shared rung.
    Each group's canonical id follows the ladder's rule (undated first, then
    cheapest, then id). A generation counts as enabled when its canonical id
    is — `is_enabled(model_id) -> bool`. Declared families keep
    `[tier_families]` order; undeclared ones follow, ordered by the input price
    of their chosen id (R5.3), family name breaking an exact price tie.
    """
    by_generation: dict = {}
    for group in ladder.groups:
        for entry in group:
            by_generation.setdefault((entry.family, entry.generation), []).append(entry)

    newest: dict = {}  # family -> (generation, canonical id, input price)
    for (family, generation), entries in by_generation.items():
        undated = [e for e in entries if not _has_date_suffix(e.model_id)]
        pool = undated or entries
        chosen = min(pool, key=lambda e: (float(e.prices.get("input", 0.0)), e.model_id))
        if not is_enabled(chosen.model_id):
            continue
        if family not in newest or generation > newest[family][0]:
            newest[family] = (generation, chosen.model_id, float(chosen.prices.get("input", 0.0)))

    # dict.fromkeys dedupes a repeated `[tier_families]` name, keeping its
    # first position — a duplicate must never give one family two slots.
    declared = [name for name in dict.fromkeys(tier_families) if name in newest]
    undeclared = sorted(
        (name for name in newest if name not in declared),
        key=lambda name: (newest[name][2], name),
    )
    ordered = declared + undeclared
    return FamilyList(slots=[newest[name][1] for name in ordered], families=ordered)


def _validate_override(entry) -> str | None:
    """Rejection reason for one `[overrides.<id>]` table, or None when well-formed."""
    if not isinstance(entry, dict):
        return "override entry must be a table"
    if "enabled" in entry and not isinstance(entry["enabled"], bool):
        return "enabled must be true or false"
    return None


def _dedupe_tier_families(order: list) -> tuple:
    """Split `[tier_families].order` into `(kept, rejected)` (R5.8).

    A family named twice is an invalid entry: the first occurrence is kept and
    each repeat is rejected with a stated cause. Doing this once at load means
    `build_ladder` and `build_family_list` always see the same order, instead
    of each resolving the repeat its own way (last vs first position).
    """
    kept, rejected = [], {}
    for name in order:
        if name in kept:
            rejected[name] = (
                f"duplicate family in [tier_families].order; first position "
                f"({kept.index(name)}) kept"
            )
        else:
            kept.append(name)
    return kept, rejected


# Keys a pre-step `router.toml` carried (design.md Key Decision 5). Present ->
# recorded as deprecated with a cause and otherwise ignored; never an error.
_DEPRECATED_POLICY_KEYS = {
    "safe_default": "replaced by safe_default_step (a step, never a model id); key ignored",
    "long_context_model": (
        "replaced by the long-context walk gated by long_context_tokens; key ignored"
    ),
}


def _is_int(value) -> bool:
    # bool is an int subclass; `max = true` is a typo, not a score bound.
    return isinstance(value, int) and not isinstance(value, bool)


def _lane_shape_fault(lane_tbl) -> str | None:
    """Why one `[policy.lanes.<name>]` entry is structurally unusable, or None.

    Catches the shapes that used to crash load (`code = 5` → `.get` on an int)
    or silently misparse (a string `score_buckets` iterated per character).
    `rung`-vs-`step` is judged separately by the caller.
    """
    if not isinstance(lane_tbl, dict):
        return f"lane must be a table, got {type(lane_tbl).__name__}"
    buckets = lane_tbl.get("score_buckets")
    if buckets is None:
        return None
    if not isinstance(buckets, list):
        return f"score_buckets must be an array, got {type(buckets).__name__}"
    for index, bucket in enumerate(buckets):
        if not isinstance(bucket, dict):
            return f"score_buckets[{index}] must be a table, got {type(bucket).__name__}"
        for key in ("max", "step"):
            if key in bucket and not _is_int(bucket[key]):
                return f"score_buckets[{index}].{key} must be an integer"
    return None


def _split_lanes(lanes_tbl: dict) -> tuple:
    """Split `[policy.lanes.*]` into `(lanes, rejected_lanes)` (R5.8, R5.12).

    A bucket with `rung` but no `step` is the pre-step shape: an absolute
    ladder index that would be misread as a relative step. Its whole lane is
    dropped with a stated cause — a lane with a hole in its score bands is
    not a lane — and every other lane is kept.
    """
    lanes, rejected = {}, {}
    for lane_name, lane_tbl in lanes_tbl.items():
        shape_fault = _lane_shape_fault(lane_tbl)
        if shape_fault is not None:
            rejected[lane_name] = f"{shape_fault}; lane dropped"
            continue
        buckets = list(lane_tbl.get("score_buckets") or [])
        legacy = [
            index
            for index, bucket in enumerate(buckets)
            if isinstance(bucket, dict) and "rung" in bucket and "step" not in bucket
        ]
        if legacy:
            rejected[lane_name] = (
                f"score_buckets {legacy} have `rung` but no `step` (pre-step shape); "
                "lane dropped — rewrite each bucket as `step = <int <= 0>`"
            )
        else:
            lanes[lane_name] = buckets
    return lanes, rejected


@dataclass(frozen=True)
class RouterConfig:
    """Everything `router.toml` declares — policy only, never a model identity."""

    schema_version: int
    port: int | None
    upstream: str
    classifier: dict
    thresholds: dict
    escalation_window_s: int
    max_tiers_above_baseline: int
    tier_families: list
    lanes: dict
    context_window_default: int
    context_window_overrides: dict
    overrides: dict
    rejected_overrides: dict
    local: dict
    rejected_tier_families: dict = field(default_factory=dict)
    rejected_lanes: dict = field(default_factory=dict)
    deprecated_keys: dict = field(default_factory=dict)

    def context_window(self, model_id: str) -> int:
        return self.context_window_overrides.get(model_id, self.context_window_default)

    def is_enabled(self, model_id: str) -> bool:
        return self.overrides.get(model_id, {}).get("enabled", True)


def load_policy(path: Path) -> tuple:
    """Parse `router.toml`. Returns `(RouterConfig | None, cause: str | None)`.

    Absent or unparseable file means `RouterConfig` is `None` and `cause` states why
    — the router falls to pass-through, reusing R5.5's vocabulary for the
    policy file too rather than inventing a second one.
    """
    try:
        raw = tomllib.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None, f"router.toml not found: {path}"
    except (OSError, tomllib.TOMLDecodeError) as exc:
        return None, f"router.toml unparseable: {exc}"

    router_tbl = raw.get("router") or {}
    policy_tbl = raw.get("policy") or {}
    classifier_tbl = raw.get("classifier") or {}
    context_windows = dict(raw.get("context_windows") or {})
    context_default = context_windows.pop("default", 0)

    lanes, rejected_lanes = _split_lanes(policy_tbl.get("lanes") or {})
    deprecated_keys = {
        key: cause for key, cause in _DEPRECATED_POLICY_KEYS.items() if key in policy_tbl
    }

    overrides, rejected_overrides = {}, {}
    for model_id, entry in (raw.get("overrides") or {}).items():
        reason = _validate_override(entry)
        if reason:
            rejected_overrides[model_id] = reason
        else:
            overrides[model_id] = entry

    thresholds = {
        "safe_default_step": policy_tbl.get("safe_default_step"),
        "confidence_floor": policy_tbl.get("confidence_floor"),
        "privacy_threshold": policy_tbl.get("privacy_threshold"),
        "long_context_tokens": policy_tbl.get("long_context_tokens"),
    }

    tier_families, rejected_tier_families = _dedupe_tier_families(
        list((raw.get("tier_families") or {}).get("order") or [])
    )

    policy = RouterConfig(
        schema_version=raw.get("schema_version", 0),
        port=router_tbl.get("port"),
        upstream=router_tbl.get("upstream", ""),
        classifier=dict(classifier_tbl),
        thresholds=thresholds,
        escalation_window_s=policy_tbl.get("escalation_window_s", 0),
        max_tiers_above_baseline=policy_tbl.get("max_tiers_above_baseline", 0),
        tier_families=tier_families,
        lanes=lanes,
        context_window_default=context_default,
        context_window_overrides=context_windows,
        overrides=overrides,
        rejected_overrides=rejected_overrides,
        local=dict(raw.get("local") or {}),
        rejected_tier_families=rejected_tier_families,
        rejected_lanes=rejected_lanes,
        deprecated_keys=deprecated_keys,
    )
    return policy, None


@dataclass(frozen=True)
class Catalog:
    """The router's one entry point: discovered surface + policy, or pass-through."""

    pass_through: bool
    cause: str | None
    ladder: Ladder | None
    policy: RouterConfig | None
    rejected_models: dict = field(default_factory=dict)
    families: FamilyList | None = None

    def rung_of(self, model_id: str) -> int | None:
        if self.ladder is None:
            return None
        return self.ladder.rung_of.get(model_id)

    def slot_of(self, model_id: str) -> int | None:
        if self.families is None:
            return None
        return self.families.slot_of(model_id)

    def model_at_slot(self, slot: int) -> str | None:
        if self.families is None:
            return None
        return self.families.model_at(slot)

    def model_at_rung(self, rung: int) -> str | None:
        if self.ladder is None:
            return None
        return self.ladder.model_at(rung)

    def is_enabled(self, model_id: str) -> bool:
        if self.policy is None:
            return False
        return self.policy.is_enabled(model_id)

    def context_window(self, model_id: str) -> int:
        if self.policy is None:
            return 0
        return self.policy.context_window(model_id)


def load_catalog(router_toml_path: Path, catalogue_path: Path | None = None) -> Catalog:
    """Build the full `Catalog`: discover, validate, rank, load policy.

    Either stage failing — unreadable/stale pricing catalogue, or an
    absent/unparseable `router.toml` — yields `pass_through=True` plus the
    stated cause (R5.5); it never raises. A single malformed discovered entry
    or override disables only itself (R5.8).
    """
    discovery = discover_models(catalogue_path)
    if not discovery["discovered"]:
        return Catalog(pass_through=True, cause=discovery["source"], ladder=None, policy=None)

    valid_models, rejected_models = validate_models(discovery["models"])

    policy, cause = load_policy(router_toml_path)
    if policy is None:
        return Catalog(
            pass_through=True,
            cause=cause,
            ladder=None,
            policy=None,
            rejected_models=rejected_models,
        )

    ladder = build_ladder(valid_models, policy.tier_families)
    return Catalog(
        pass_through=False,
        cause=None,
        ladder=ladder,
        policy=policy,
        rejected_models=rejected_models,
        families=build_family_list(ladder, policy.tier_families, policy.is_enabled),
    )
