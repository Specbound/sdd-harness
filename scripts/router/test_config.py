"""Unit tests for scripts/router/config.py.

Run via `scripts/router/config.test.sh` (wraps `python3 -m unittest`). Every
fixture model id/family below is fictitious — `config.py`'s own contract is
"no model identifier, price, or endpoint literal anywhere in the file"
(R5.1), so these tests double as proof that the Ladder never special-cases a
real model name: nothing here ever appears in `config.py` itself.
"""

from __future__ import annotations

import datetime as dt
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
confidence_floor = 0.5
privacy_threshold = 0.9
long_context_tokens = 100000
long_context_model = "big"
escalation_window_s = 60
max_tiers_above_baseline = 2

[policy.lanes.default]
score_buckets = [0.1, 0.9]

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
        self.assertEqual(policy.escalation_window_s, 60)
        self.assertEqual(policy.max_tiers_above_baseline, 2)
        self.assertEqual(policy.lanes, {"default": [0.1, 0.9]})


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
        self.assertEqual(len(catalog.ladder), 1)
        self.assertIn("claude-broken-1-0", catalog.rejected_models)
        self.assertEqual(catalog.rung_of("claude-sound-1-0"), 0)
        self.assertEqual(catalog.model_at_rung(0), "claude-sound-1-0")
        self.assertTrue(catalog.is_enabled("claude-sound-1-0"))


if __name__ == "__main__":
    unittest.main()
