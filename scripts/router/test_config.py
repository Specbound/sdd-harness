"""Unit tests for scripts/router/config.py.

Run via `scripts/router/config.test.sh` (wraps `python3 -m unittest`). Every
fixture model id/family below is fictitious — `config.py`'s own contract is
"no model identifier, price, or endpoint literal anywhere in the file"
(R5.1), so these tests double as proof that the Ladder never special-cases a
real model name: nothing here ever appears in `config.py` itself.
"""

from __future__ import annotations

import datetime as dt
import itertools
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import config


def _iso_now(days_ago: float = 0) -> str:
    when = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days_ago)
    return when.isoformat()


class BuildLadderFamilyOrderTests(unittest.TestCase):
    """R5.3 — declared family+generation order first, price only breaks ties."""

    # Verifies: specs/model-router/requirements.md#5.3
    def test_declared_family_order_beats_price_across_families(self):
        # Family is the single token right after "claude" — "weak"/"strong"
        # here, each declared at a distinct rank in tier_families.
        tier_families = ["weak", "strong"]
        models = {
            "claude-weak-5-0": {"input": 10.0, "output": 10.0},  # pricier but declared weaker
            "claude-strong-5-0": {"input": 1.0, "output": 1.0},  # cheaper but declared stronger
        }
        ladder = config.build_ladder(models, tier_families)
        self.assertLess(
            ladder.rung_of["claude-weak-5-0"],
            ladder.rung_of["claude-strong-5-0"],
        )

    # Verifies: specs/model-router/requirements.md#5.3
    def test_newer_generation_outranks_cheaper_older_sibling(self):
        # Mirrors the documented live-catalogue bug: a newer point release
        # that prices lower than its older sibling must still rank higher.
        tier_families = ["fam"]
        models = {
            "claude-fam-5-4": {"input": 5.0, "output": 5.0},  # older, pricier
            "claude-fam-5-5": {"input": 4.0, "output": 4.0},  # newer, cheaper
        }
        ladder = config.build_ladder(models, tier_families)
        self.assertLess(
            ladder.rung_of["claude-fam-5-4"],
            ladder.rung_of["claude-fam-5-5"],
        )

    # Verifies: specs/model-router/requirements.md#5.3
    def test_price_breaks_tie_within_identical_generation(self):
        # Both ids parse to family "tie", generation (2, 0) — "-beta" is not
        # a digit token so it is dropped rather than changing the key. This
        # is a genuine tie, independent of the dated-alias path.
        tier_families = ["tie"]
        models = {
            "claude-tie-2-0-beta": {"input": 9.0, "output": 9.0},
            "claude-tie-2-0": {"input": 3.0, "output": 3.0},
        }
        ladder = config.build_ladder(models, tier_families)
        rung = ladder.rung_of["claude-tie-2-0"]
        self.assertEqual(rung, ladder.rung_of["claude-tie-2-0-beta"])
        self.assertEqual(ladder.model_at(rung), "claude-tie-2-0")
        ids_at_rung = {entry.model_id for entry in ladder.entries_at(rung)}
        self.assertEqual(ids_at_rung, {"claude-tie-2-0", "claude-tie-2-0-beta"})

    # Verifies: specs/model-router/requirements.md#5.3
    def test_price_alone_orders_undeclared_families(self):
        # Every family absent from tier_families shares one undifferentiated
        # rank (per build_ladder's docstring) and loses its generation
        # signal, so the two undeclared families below land on the *same*
        # merged rung — price alone then decides which becomes canonical,
        # which is exactly "price only ... order[s] between [undeclared]
        # families" for the one shared tier they're pooled into.
        tier_families = ["known-fam"]
        models = {
            "claude-zed-1-0": {"input": 2.0, "output": 2.0},
            "claude-yak-9-9": {"input": 1.0, "output": 1.0},
        }
        ladder = config.build_ladder(models, tier_families)
        self.assertEqual(
            ladder.rung_of["claude-yak-9-9"], ladder.rung_of["claude-zed-1-0"]
        )
        shared_rung = ladder.rung_of["claude-yak-9-9"]
        self.assertEqual(ladder.model_at(shared_rung), "claude-yak-9-9")

    # Verifies: specs/model-router/requirements.md#5.3
    def test_no_hardcoded_model_list_handles_arbitrary_declared_families(self):
        # None of these family/model ids appear anywhere in config.py — the
        # Ladder must rank them correctly purely from the declared order
        # passed in, with no per-model special-casing in source.
        tier_families = [f"nonce{i}" for i in range(5)]
        models = {
            f"claude-nonce{i}-{i}-0": {"input": float(10 - i), "output": float(10 - i)}
            for i in range(5)
        }
        ladder = config.build_ladder(models, tier_families)
        self.assertEqual(len(ladder), 5)
        self.assertEqual(set(ladder.rung_of), set(models))
        # Declared order preserved weakest(0) -> strongest(-1).
        for i in range(5):
            self.assertEqual(ladder.rung_of[f"claude-nonce{i}-{i}-0"], i)

    # Verifies: specs/model-router/requirements.md#5.3 (property)
    def test_build_ladder_is_order_independent_and_idempotent(self):
        """Property: result depends only on the (id, prices) set, not on dict
        insertion order, and repeated calls on the same input agree."""
        tier_families = ["alpha", "beta"]
        items = [
            ("claude-alpha-1-0", {"input": 3.0, "output": 3.0}),
            ("claude-alpha-1-0-20251001", {"input": 1.0, "output": 1.0}),
            ("claude-beta-2-1", {"input": 7.0, "output": 7.0}),
            ("claude-gamma-9-0", {"input": 0.5, "output": 0.5}),
        ]
        forward = dict(items)
        reversed_ = dict(reversed(items))

        ladder_forward = config.build_ladder(forward, tier_families)
        ladder_reversed = config.build_ladder(reversed_, tier_families)
        ladder_forward_again = config.build_ladder(dict(forward), tier_families)

        self.assertEqual(ladder_forward.canonical, ladder_reversed.canonical)
        self.assertEqual(ladder_forward.rung_of, ladder_reversed.rung_of)
        self.assertEqual(ladder_forward.canonical, ladder_forward_again.canonical)
        self.assertEqual(ladder_forward.rung_of, ladder_forward_again.rung_of)


class DatedAliasCollapseTests(unittest.TestCase):
    """R5.9 — a dated alias collapses onto its undated sibling's rung."""

    # Verifies: specs/model-router/requirements.md#5.9
    def test_dated_alias_collapses_onto_undated_rung(self):
        tier_families = ["haiku"]
        models = {
            "claude-haiku-4-5": {"input": 5.0, "output": 5.0},
            # Cheaper than the undated sibling — proves canonical preference
            # is not decided by price once an undated option exists.
            "claude-haiku-4-5-20251001": {"input": 1.0, "output": 1.0},
        }
        ladder = config.build_ladder(models, tier_families)
        self.assertEqual(len(ladder), 1)
        rung = ladder.rung_of["claude-haiku-4-5"]
        self.assertEqual(rung, ladder.rung_of["claude-haiku-4-5-20251001"])
        self.assertEqual(ladder.model_at(rung), "claude-haiku-4-5")


class DiscoverModelsTests(unittest.TestCase):
    """R5.5 — missing/stale/unreadable catalogue reports a cause, never raises."""

    # Verifies: specs/model-router/requirements.md#5.5
    def test_missing_catalogue_reports_cause_without_raising(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "does-not-exist.json"
            result = config.discover_models(catalogue_path=missing)
        self.assertFalse(result["discovered"])
        self.assertIn("unreadable", result["source"])

    # Verifies: specs/model-router/requirements.md#5.5
    def test_malformed_json_reports_cause_without_raising(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.json"
            bad.write_text("{not valid json", encoding="utf-8")
            result = config.discover_models(catalogue_path=bad)
        self.assertFalse(result["discovered"])
        self.assertIn("unreadable", result["source"])

    # Verifies: specs/model-router/requirements.md#5.5
    def test_stale_catalogue_reports_cause(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pricing.json"
            payload = {
                "snapshots": [
                    {
                        "fetched_at": _iso_now(days_ago=40),
                        "models": {
                            "anthropic/claude-stale-1-0": {"input": 1.0, "output": 1.0}
                        },
                    }
                ]
            }
            path.write_text(json.dumps(payload), encoding="utf-8")
            result = config.discover_models(catalogue_path=path)
        self.assertFalse(result["discovered"])
        self.assertIn("stale", result["source"])

    # Verifies: specs/model-router/requirements.md#5.1, specs/model-router/requirements.md#5.5
    def test_valid_catalogue_discovers_anthropic_entries_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pricing.json"
            payload = {
                "snapshots": [
                    {
                        "fetched_at": _iso_now(),
                        "models": {
                            "anthropic/claude-fresh-1-0": {"input": 1.0, "output": 2.0},
                            "openai/gpt-irrelevant": {"input": 1.0, "output": 1.0},
                        },
                    }
                ]
            }
            path.write_text(json.dumps(payload), encoding="utf-8")
            result = config.discover_models(catalogue_path=path)
        self.assertTrue(result["discovered"])
        self.assertEqual(
            result["models"], {"claude-fresh-1-0": {"input": 1.0, "output": 2.0}}
        )


class ValidateModelsTests(unittest.TestCase):
    """R5.8 — one malformed entry disables only itself."""

    # Verifies: specs/model-router/requirements.md#5.8
    def test_malformed_entry_rejected_without_affecting_valid_entries(self):
        models = {
            "claude-good-1-0": {"input": 1.0, "output": 2.0},
            "claude-bad-missing-output": {"input": 1.0},
            "claude-bad-non-numeric": {"input": "oops", "output": 2.0},
        }
        valid, rejected = config.validate_models(models)
        self.assertEqual(valid, {"claude-good-1-0": {"input": 1.0, "output": 2.0}})
        self.assertEqual(
            set(rejected), {"claude-bad-missing-output", "claude-bad-non-numeric"}
        )


class LoadPolicyTests(unittest.TestCase):
    """R5.5 (policy file) and R5.8 (override validation)."""

    # Verifies: specs/model-router/requirements.md#5.5
    def test_missing_router_toml_reports_cause_without_raising(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "router.toml"
            policy, cause = config.load_policy(missing)
        self.assertIsNone(policy)
        self.assertIn("not found", cause)

    # Verifies: specs/model-router/requirements.md#5.5
    def test_malformed_router_toml_reports_cause_without_raising(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "router.toml"
            path.write_text("this [[[ is not = toml", encoding="utf-8")
            policy, cause = config.load_policy(path)
        self.assertIsNone(policy)
        self.assertIn("unparseable", cause)

    # Verifies: specs/model-router/requirements.md#5.7, specs/model-router/requirements.md#5.8
    def test_valid_router_toml_parses_fields_and_rejects_bad_override_alone(self):
        toml_text = """
schema_version = 1

[router]
upstream = "https://example.invalid"

[policy]
safe_default = 0
safe_default_step = -2
confidence_floor = 0.5
privacy_threshold = 0.9
long_context_tokens = 100000
long_context_model = "big"
escalation_window_s = 60
max_tiers_above_baseline = 2

[policy.lanes.default]
score_buckets = [ { max = 10, step = -1 } ]

[tier_families]
order = ["haiku", "opus"]

[context_windows]
default = 8000
"claude-big-1-0" = 200000

[overrides."claude-good-1-0"]
enabled = false

[overrides."claude-bad-1-0"]
enabled = "notabool"

[classifier]
timeout_ms = 500

[local]
foo = "bar"
"""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "router.toml"
            path.write_text(toml_text, encoding="utf-8")
            policy, cause = config.load_policy(path)

        self.assertIsNone(cause)
        self.assertIsNotNone(policy)
        self.assertEqual(policy.upstream, "https://example.invalid")
        self.assertEqual(policy.tier_families, ["haiku", "opus"])
        self.assertEqual(policy.context_window_default, 8000)
        self.assertEqual(policy.context_window_overrides, {"claude-big-1-0": 200000})
        self.assertEqual(policy.overrides, {"claude-good-1-0": {"enabled": False}})
        self.assertEqual(
            policy.rejected_overrides,
            {"claude-bad-1-0": "enabled must be true or false"},
        )
        self.assertEqual(policy.thresholds["confidence_floor"], 0.5)
        self.assertEqual(policy.thresholds["safe_default_step"], -2)
        self.assertEqual(policy.rejected_tier_families, {})
        self.assertEqual(policy.escalation_window_s, 60)
        self.assertEqual(policy.max_tiers_above_baseline, 2)
        self.assertEqual(policy.lanes, {"default": [{"max": 10, "step": -1}]})


class ContextWindowDefaultTests(unittest.TestCase):
    """R5.7 — a model with no window override takes the conservative default."""

    # Verifies: specs/model-router/requirements.md#5.7
    def test_unknown_model_uses_conservative_default(self):
        policy = config.RouterConfig(
            schema_version=1,
            port=None,
            upstream="",
            classifier={},
            thresholds={},
            escalation_window_s=0,
            max_tiers_above_baseline=0,
            tier_families=[],
            lanes={},
            context_window_default=8000,
            context_window_overrides={},
            overrides={},
            rejected_overrides={},
            local={},
        )
        self.assertEqual(policy.context_window("claude-never-configured"), 8000)

    # Verifies: specs/model-router/requirements.md#5.7
    def test_explicit_override_takes_precedence_over_default(self):
        policy = config.RouterConfig(
            schema_version=1,
            port=None,
            upstream="",
            classifier={},
            thresholds={},
            escalation_window_s=0,
            max_tiers_above_baseline=0,
            tier_families=[],
            lanes={},
            context_window_default=8000,
            context_window_overrides={"claude-wide-1-0": 200000},
            overrides={},
            rejected_overrides={},
            local={},
        )
        self.assertEqual(policy.context_window("claude-wide-1-0"), 200000)


class LoadCatalogTests(unittest.TestCase):
    """Integration across discover -> validate -> load_policy -> build_ladder."""

    def _write_catalogue(self, tmp: Path, models: dict) -> Path:
        path = tmp / "pricing.json"
        payload = {"snapshots": [{"fetched_at": _iso_now(), "models": models}]}
        path.write_text(json.dumps(payload), encoding="utf-8")
        return path

    # Verifies: specs/model-router/requirements.md#5.5
    def test_missing_catalogue_yields_pass_through_with_cause(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            catalogue = tmp_path / "missing-pricing.json"
            router_toml = tmp_path / "router.toml"
            catalog = config.load_catalog(router_toml, catalogue_path=catalogue)
        self.assertTrue(catalog.pass_through)
        self.assertIsNotNone(catalog.cause)
        self.assertIsNone(catalog.ladder)
        self.assertIsNone(catalog.policy)

    # Verifies: specs/model-router/requirements.md#5.5
    def test_missing_router_toml_yields_pass_through_with_cause(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            catalogue = self._write_catalogue(
                tmp_path, {"anthropic/claude-ok-1-0": {"input": 1.0, "output": 1.0}}
            )
            router_toml = tmp_path / "router.toml"  # never written
            catalog = config.load_catalog(router_toml, catalogue_path=catalogue)
        self.assertTrue(catalog.pass_through)
        assert catalog.cause is not None
        self.assertIn("router.toml", catalog.cause)
        self.assertIsNone(catalog.ladder)

    # Verifies: specs/model-router/requirements.md#5.3, specs/model-router/requirements.md#5.8
    def test_valid_inputs_build_ladder_and_track_rejected_models(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            catalogue = self._write_catalogue(
                tmp_path,
                {
                    "anthropic/claude-sound-1-0": {"input": 1.0, "output": 1.0},
                    "anthropic/claude-broken-1-0": {"input": "oops", "output": 1.0},
                },
            )
            router_toml = tmp_path / "router.toml"
            router_toml.write_text(
                '[router]\nupstream = "https://example.invalid"\n'
                "[tier_families]\norder = []\n",
                encoding="utf-8",
            )
            catalog = config.load_catalog(router_toml, catalogue_path=catalogue)

        self.assertFalse(catalog.pass_through)
        self.assertIsNone(catalog.cause)
        self.assertIsNotNone(catalog.ladder)
        assert catalog.ladder is not None
        self.assertEqual(len(catalog.ladder), 1)
        self.assertIn("claude-broken-1-0", catalog.rejected_models)
        self.assertEqual(catalog.rung_of("claude-sound-1-0"), 0)
        self.assertEqual(catalog.model_at_rung(0), "claude-sound-1-0")
        self.assertTrue(catalog.is_enabled("claude-sound-1-0"))

    # Verifies: specs/model-router/requirements.md#5.11
    def test_catalog_exposes_newest_per_family_slots_honouring_overrides(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            catalogue = self._write_catalogue(
                tmp_path,
                {
                    "anthropic/claude-haiku-4-5": {"input": 1.0, "output": 1.0},
                    "anthropic/claude-haiku-5-5": {"input": 1.0, "output": 1.0},
                    "anthropic/claude-sonnet-5-5": {"input": 3.0, "output": 3.0},
                },
            )
            router_toml = tmp_path / "router.toml"
            router_toml.write_text(
                '[router]\nupstream = "https://example.invalid"\n'
                '[tier_families]\norder = ["haiku", "sonnet"]\n'
                '[overrides."claude-haiku-5-5"]\nenabled = false\n',
                encoding="utf-8",
            )
            catalog = config.load_catalog(router_toml, catalogue_path=catalogue)

        self.assertIsNotNone(catalog.families)
        self.assertEqual(catalog.model_at_slot(0), "claude-haiku-4-5")
        self.assertEqual(catalog.model_at_slot(1), "claude-sonnet-5-5")
        self.assertEqual(catalog.slot_of("claude-sonnet-4-5-20250929"), 1)

    # Verifies: specs/model-router/requirements.md#5.11
    def test_pass_through_catalog_has_no_slots(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            catalog = config.load_catalog(
                tmp_path / "router.toml", catalogue_path=tmp_path / "missing.json"
            )
        self.assertIsNone(catalog.families)
        self.assertIsNone(catalog.slot_of("claude-haiku-5-5"))
        self.assertIsNone(catalog.model_at_slot(0))

    # Verifies: specs/model-router/requirements.md#5.8
    def test_duplicate_tier_family_rejected_at_load_and_both_orders_agree(self):
        """A family named twice in `[tier_families].order` is rejected at load
        (R5.8: the duplicate entry alone, first occurrence kept, cause stated),
        so the rung ladder and the newest-per-family list rank it identically.
        Before the fix, `build_ladder` kept the last position and
        `build_family_list` the first, so they disagreed on the same config.
        """
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            catalogue = self._write_catalogue(
                tmp_path,
                {
                    "anthropic/claude-haiku-5-5": {"input": 1.0, "output": 1.0},
                    "anthropic/claude-sonnet-5-5": {"input": 3.0, "output": 3.0},
                },
            )
            router_toml = tmp_path / "router.toml"
            router_toml.write_text(
                '[router]\nupstream = "https://example.invalid"\n'
                '[tier_families]\norder = ["haiku", "sonnet", "haiku"]\n',
                encoding="utf-8",
            )
            catalog = config.load_catalog(router_toml, catalogue_path=catalogue)

        assert catalog.policy is not None
        self.assertEqual(catalog.policy.tier_families, ["haiku", "sonnet"])
        self.assertIn("haiku", catalog.policy.rejected_tier_families)
        self.assertIn("duplicate", catalog.policy.rejected_tier_families["haiku"])
        haiku_rung = catalog.rung_of("claude-haiku-5-5")
        sonnet_rung = catalog.rung_of("claude-sonnet-5-5")
        assert haiku_rung is not None and sonnet_rung is not None
        self.assertLess(haiku_rung, sonnet_rung)
        self.assertEqual(catalog.slot_of("claude-haiku-5-5"), 0)
        self.assertEqual(catalog.slot_of("claude-sonnet-5-5"), 1)


def _load_policy_text(toml_text: str):
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "router.toml"
        path.write_text(toml_text, encoding="utf-8")
        return config.load_policy(path)


class LegacyConfigMigrationTests(unittest.TestCase):
    """Task 14.4 — pre-step `router.toml` shapes are reported, never misread."""

    # Verifies: specs/model-router/requirements.md#5.8
    # Verifies: specs/model-router/requirements.md#5.12
    def test_rung_only_bucket_drops_its_lane_with_a_cause_and_keeps_the_rest(self):
        policy, cause = _load_policy_text(
            """
[policy.lanes.code]
score_buckets = [ { max = 3, rung = 0 }, { max = 10, rung = -1 } ]

[policy.lanes.chitchat]
score_buckets = [ { max = 10, step = -2 } ]

[policy.lanes.simple]
score_buckets = [ { max = 10, step = -1 } ]
"""
        )
        self.assertIsNone(cause)
        self.assertNotIn("code", policy.lanes)
        self.assertEqual(set(policy.lanes), {"chitchat", "simple"})
        self.assertIn("code", policy.rejected_lanes)
        self.assertIn("rung", policy.rejected_lanes["code"])
        self.assertIn("step", policy.rejected_lanes["code"])

    # Verifies: specs/model-router/requirements.md#5.8
    def test_malformed_lane_shapes_drop_only_that_lane_with_a_cause(self):
        # A lane that isn't a table, a non-list score_buckets (a string would
        # otherwise iterate per character), a bucket that isn't a table, and a
        # non-integer max/step each reject their own lane; the good lane stays.
        policy, cause = _load_policy_text(
            """
[policy.lanes]
scalar = 5

[policy.lanes.stringy]
score_buckets = "max=3"

[policy.lanes.notable]
score_buckets = [ 3, { max = 10, step = -1 } ]

[policy.lanes.badstep]
score_buckets = [ { max = 10, step = "down" } ]

[policy.lanes.boolmax]
score_buckets = [ { max = true, step = -1 } ]

[policy.lanes.good]
score_buckets = [ { max = 10, step = -1 } ]
"""
        )
        self.assertIsNone(cause)
        self.assertEqual(set(policy.lanes), {"good"})
        self.assertEqual(
            set(policy.rejected_lanes), {"scalar", "stringy", "notable", "badstep", "boolmax"}
        )
        for name, reason in policy.rejected_lanes.items():
            self.assertTrue(reason, f"{name} rejected without a stated cause")

    # Verifies: specs/model-router/requirements.md#5.12
    def test_one_rung_only_bucket_among_step_buckets_still_drops_the_lane(self):
        policy, _ = _load_policy_text(
            """
[policy.lanes.code]
score_buckets = [ { max = 3, step = -2 }, { max = 10, rung = -1 } ]
"""
        )
        self.assertEqual(policy.lanes, {})
        self.assertIn("code", policy.rejected_lanes)

    # Verifies: specs/model-router/requirements.md#5.12
    def test_bucket_with_both_rung_and_step_is_kept(self):
        policy, _ = _load_policy_text(
            """
[policy.lanes.code]
score_buckets = [ { max = 10, step = -1, rung = 0 } ]
"""
        )
        self.assertEqual(policy.lanes, {"code": [{"max": 10, "step": -1, "rung": 0}]})
        self.assertEqual(policy.rejected_lanes, {})

    # Verifies: specs/model-router/requirements.md#5.12
    def test_safe_default_and_long_context_model_are_deprecated_not_errors(self):
        policy, cause = _load_policy_text(
            """
[policy]
safe_default = "<catalog key>"
long_context_model = "<catalog key>"
long_context_tokens = 60000
safe_default_step = -1
"""
        )
        self.assertIsNone(cause)
        self.assertEqual(set(policy.deprecated_keys), {"safe_default", "long_context_model"})
        self.assertIn("safe_default_step", policy.deprecated_keys["safe_default"])
        self.assertIn("long_context_tokens", policy.deprecated_keys["long_context_model"])
        self.assertNotIn("safe_default", policy.thresholds)
        self.assertNotIn("long_context_model", policy.thresholds)
        self.assertEqual(policy.thresholds["long_context_tokens"], 60000)
        self.assertEqual(policy.thresholds["safe_default_step"], -1)

    # Verifies: specs/model-router/requirements.md#5.12
    def test_current_shape_reports_no_rejected_lanes_or_deprecated_keys(self):
        policy, _ = _load_policy_text(
            """
[policy]
safe_default_step = -1

[policy.lanes.code]
score_buckets = [ { max = 10, step = 0 } ]
"""
        )
        self.assertEqual(policy.rejected_lanes, {})
        self.assertEqual(policy.deprecated_keys, {})


_TEMPLATE = Path(__file__).resolve().parents[2] / "templates" / "router.toml.template"


class ShippedTemplateTests(unittest.TestCase):
    """The template `router-setup.sh` copies is already in the step shape."""

    def setUp(self):
        policy, cause = config.load_policy(_TEMPLATE)
        self.assertIsNone(cause)
        self.policy = policy

    # Verifies: specs/model-router/requirements.md#5.14
    def test_template_declares_the_five_lanes(self):
        self.assertEqual(
            list(self.policy.lanes),
            ["chitchat", "simple", "rewrite", "code", "reasoning"],
        )

    # Verifies: specs/model-router/requirements.md#5.12
    def test_template_buckets_are_all_steps_and_nothing_is_rejected(self):
        for lane, buckets in self.policy.lanes.items():
            for bucket in buckets:
                self.assertIn("step", bucket, lane)
                self.assertNotIn("rung", bucket, lane)
                self.assertLessEqual(bucket["step"], 0, lane)
        self.assertEqual(self.policy.rejected_lanes, {})
        self.assertEqual(self.policy.deprecated_keys, {})

    # Verifies: specs/model-router/requirements.md#5.12
    def test_template_safe_default_is_a_step_and_long_context_tokens_stays(self):
        self.assertEqual(self.policy.thresholds["safe_default_step"], -1)
        self.assertEqual(self.policy.thresholds["long_context_tokens"], 60000)

    # Verifies: specs/model-router/requirements.md#5.1
    def test_template_names_no_model_id_or_placeholder(self):
        text = _TEMPLATE.read_text(encoding="utf-8")
        self.assertNotIn("claude-", text)
        self.assertNotIn("<catalog key>", text)
        self.assertNotIn("rung =", text)


def _family_list(models: dict, tier_families: list, disabled: frozenset = frozenset()):
    ladder = config.build_ladder(models, tier_families)
    return config.build_family_list(ladder, tier_families, lambda mid: mid not in disabled)


def _price(value: float) -> dict:
    return {"input": value, "output": value}


class NewestPerFamilyListTests(unittest.TestCase):
    """R5.11 — targets come only from each family's newest enabled generation."""

    # Verifies: specs/model-router/requirements.md#5.11
    def test_older_generation_never_on_list_when_newer_exists(self):
        families = _family_list(
            {
                "claude-haiku-4-5": _price(1.0),
                "claude-haiku-5-5": _price(1.0),
                "claude-sonnet-5-5": _price(3.0),
            },
            ["haiku", "sonnet"],
        )
        self.assertEqual(families.slots, ["claude-haiku-5-5", "claude-sonnet-5-5"])
        self.assertNotIn("claude-haiku-4-5", families.slots)

    # Verifies: specs/model-router/requirements.md#5.11
    def test_adding_new_generation_replaces_previous_with_no_config_edit(self):
        tiers = ["haiku", "sonnet"]
        models = {"claude-haiku-5-5": _price(1.0), "claude-sonnet-5-5": _price(3.0)}
        before = _family_list(models, tiers)
        after = _family_list({**models, "claude-sonnet-6": _price(3.0)}, tiers)
        self.assertEqual(before.slots, ["claude-haiku-5-5", "claude-sonnet-5-5"])
        self.assertEqual(after.slots, ["claude-haiku-5-5", "claude-sonnet-6"])

    # Verifies: specs/model-router/requirements.md#5.11
    def test_disabled_newest_generation_falls_back_to_next_newest_enabled(self):
        families = _family_list(
            {
                "claude-haiku-3-5": _price(1.0),
                "claude-haiku-4-5": _price(1.0),
                "claude-haiku-5-5": _price(1.0),
            },
            ["haiku"],
            disabled=frozenset({"claude-haiku-5-5"}),
        )
        self.assertEqual(families.slots, ["claude-haiku-4-5"])

    # Verifies: specs/model-router/requirements.md#5.11
    def test_family_with_every_generation_disabled_has_no_slot(self):
        families = _family_list(
            {"claude-haiku-5-5": _price(1.0), "claude-sonnet-5-5": _price(3.0)},
            ["haiku", "sonnet"],
            disabled=frozenset({"claude-haiku-5-5"}),
        )
        self.assertEqual(families.slots, ["claude-sonnet-5-5"])
        self.assertIsNone(families.slot_of("claude-haiku-5-5"))
        self.assertEqual(families.slot_of("claude-sonnet-5-5"), 0)

    # Verifies: specs/model-router/requirements.md#5.11
    def test_slot_holds_canonical_undated_id(self):
        families = _family_list(
            {
                "claude-haiku-4-5": _price(5.0),
                "claude-haiku-4-5-20251001": _price(1.0),
            },
            ["haiku"],
        )
        self.assertEqual(families.slots, ["claude-haiku-4-5"])

    # Verifies: specs/model-router/requirements.md#5.11
    def test_listed_families_follow_declared_order_not_price(self):
        families = _family_list(
            {"claude-weak-1-0": _price(9.0), "claude-strong-1-0": _price(1.0)},
            ["weak", "strong"],
        )
        self.assertEqual(families.slots, ["claude-weak-1-0", "claude-strong-1-0"])

    # Verifies: specs/model-router/requirements.md#5.11
    def test_unlisted_families_append_after_listed_ordered_by_price(self):
        families = _family_list(
            {
                "claude-known-1-0": _price(50.0),
                "claude-zed-1-0": _price(2.0),
                "claude-zed-2-0": _price(4.0),
                "claude-yak-9-9": _price(3.0),
            },
            ["known"],
        )
        # zed's slot holds its newest generation (zed-2-0 at 4.0), so yak
        # (3.0) sorts before it; both trail the listed family regardless of price.
        self.assertEqual(
            families.slots, ["claude-known-1-0", "claude-yak-9-9", "claude-zed-2-0"]
        )

    # Verifies: specs/model-router/requirements.md#5.11
    def test_duplicate_declared_family_gets_one_slot(self):
        families = _family_list(
            {"claude-haiku-5-5": _price(1.0), "claude-sonnet-5-5": _price(3.0)},
            ["haiku", "haiku", "sonnet"],
        )
        self.assertEqual(families.slots, ["claude-haiku-5-5", "claude-sonnet-5-5"])
        self.assertEqual(families.slot_of("claude-sonnet-5-5"), 1)

    # Verifies: specs/model-router/requirements.md#5.11
    def test_slot_of_resolves_any_generation_by_family(self):
        families = _family_list(
            {
                "claude-haiku-5-5": _price(1.0),
                "claude-sonnet-5-5": _price(3.0),
                "claude-opus-5-5": _price(4.0),
            },
            ["haiku", "sonnet", "opus"],
        )
        # opus-4-6 is not even in the catalogue — its family still has a slot.
        self.assertEqual(families.slot_of("claude-opus-4-6"), 2)
        self.assertEqual(families.slot_of("claude-opus-5-5"), 2)
        self.assertEqual(families.slot_of("claude-haiku-4-5-20251001"), 0)
        self.assertIsNone(families.slot_of("claude-nosuch-1-0"))
        self.assertIsNone(families.slot_of(""))

    # Verifies: specs/model-router/requirements.md#5.11
    def test_model_at_rejects_out_of_range_and_negative_slots(self):
        families = _family_list({"claude-haiku-5-5": _price(1.0)}, ["haiku"])
        self.assertEqual(families.model_at(0), "claude-haiku-5-5")
        self.assertIsNone(families.model_at(1))
        self.assertIsNone(families.model_at(-1))
        self.assertEqual(len(families), 1)

    # Verifies: specs/model-router/requirements.md#5.11 (property)
    def test_list_is_order_independent_and_matches_newest_enabled_oracle(self):
        """Property: for every input order and every disabled subset, each
        family appears at most once, and its slot holds the max enabled
        generation (oracle: brute force over the parsed ids)."""
        tiers = ["haiku", "sonnet"]
        items = [
            ("claude-haiku-4-5", _price(1.0)),
            ("claude-haiku-5-5", _price(1.0)),
            ("claude-sonnet-4-5", _price(3.0)),
            ("claude-sonnet-6", _price(3.0)),
            ("claude-zed-1-0", _price(2.0)),
        ]
        ids = [mid for mid, _ in items]
        for mask in range(1 << len(ids)):
            disabled = frozenset(ids[i] for i in range(len(ids)) if mask & (1 << i))
            expected = {}
            for mid in ids:
                if mid in disabled:
                    continue
                fam, gen = config._parse_family_generation(mid)
                if fam not in expected or gen > expected[fam][0]:
                    expected[fam] = (gen, mid)
            for order in itertools.permutations(items):
                families = _family_list(dict(order), tiers, disabled)
                self.assertEqual(
                    sorted(families.slots), sorted(mid for _, mid in expected.values())
                )
                fams = [config._parse_family_generation(m)[0] for m in families.slots]
                self.assertEqual(len(fams), len(set(fams)))


if __name__ == "__main__":
    unittest.main()
