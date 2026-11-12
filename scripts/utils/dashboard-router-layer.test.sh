#!/usr/bin/env bash
# dashboard-router-layer.test.sh — proves the Router pipeline layer added to
# `render_headroom()` in dashboard.py (task 10.1) renders correctly in three
# states and that Net Saving is always `baseline_cost - actual_cost` over
# only the priced token buckets — never adjusted a second time for the
# unknown-cost count or the suspected-bad-route model count, both of which
# are informational-only per the comments in dashboard.py itself.
#
# Required because dashboard.py is a risk zone with a thin test history
# (yellow as of 2026-10-05) and is the one place model discovery depends on
# a dashboard refresh having already run.
#
# Mechanism: `_read_router_stats()` in dashboard.py reads
# `Path.home() / ".sdd-router" / "stats.json"` (dashboard.py ROUTER_STATS,
# matching scripts/router/ledger.py's DEFAULT_STATS_PATH). `Path.home()`
# honours the `HOME` env var (verified directly against this interpreter),
# so every scenario below runs with HOME pointed at a throwaway `mktemp -d`
# tree — the real ~/.sdd-router/stats.json and ~/.claude/ are never read or
# written. `render_headroom()` is called directly (importlib, no CLI/Flask)
# with a fabricated `pricing_snapshots` argument so no network fetch via
# `load_or_refresh_pricing_history()` ever happens.
#
# Pricing fixture: three fictitious models at $1/$2/$3 per-million input
# tokens ("cheap"/"mid"/"expensive") under provider key "anthropic/<model>"
# to match `_price_model_tokens()`'s lookup convention — chosen so every
# scenario's Net Saving is an exact dollar figure, not something to eyeball.
#
# Extraction: the returned HTML is sliced to just the Router layer's own
# <div> (found by locating the "Router — Model Selection" text, then
# rfind-ing the nearest preceding `_layer()` opening <div> tag — a plain
# string method, not a regex) up to the next section's "Headroom — Current
# Session" heading. All assertions are scoped to that slice so a coincidental
# match in another layer (e.g. a $0.00 RTK figure) can never pass this test.
set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DASHBOARD="$__here/dashboard.py"
PASS=0
FAIL=0

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

HOME_DIR="$TMP/home"
mkdir -p "$HOME_DIR"

check() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    printf '  ok    %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %s (expected %s, got %s)\n' "$label" "$expected" "$actual"
  fi
}

# ── Driver ────────────────────────────────────────────────────────────────────
# Imports dashboard.py fresh (importlib, matching dashboard-usage-dedup.test.sh's
# convention) under the overridden HOME above, then drives render_headroom()
# through four states by rewriting stats.json between calls — the module's
# ROUTER_STATS path constant is fixed at import time from HOME, but the file
# content behind that path is free to change per scenario.
cat > "$TMP/drive.py" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

DASHBOARD = sys.argv[1]
HOME_DIR = Path(sys.argv[2])
ROUTER_STATS_PATH = HOME_DIR / ".sdd-router" / "stats.json"

spec = importlib.util.spec_from_file_location("dash", DASHBOARD)
dash = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dash)

# Fixed fictitious catalogue: $1 / $2 / $3 per-million input tokens. A
# snapshot dated well in the past so get_pricing_at(..., today) always picks
# it, regardless of when this test runs.
PRICING = [{
    "fetched_at": "2020-01-01T00:00:00Z",
    "models": {
        "anthropic/cheap":     {"input": 1.0, "output": 5.0},
        "anthropic/mid":       {"input": 2.0, "output": 10.0},
        "anthropic/expensive": {"input": 3.0, "output": 15.0},
    },
}]

OPEN_DIV_PREFIX = '<div style="background:var(--surface0);border-radius:8px;padding:14px 16px;'
START_MARKER = "Router — Model Selection"
END_MARKER = "Headroom — Current Session"


def router_region(html: str) -> str:
    """Slice out just the Router layer's own <div> (plus its lane-detail
    html immediately below it) from the full render_headroom() return
    value, using only str.find/str.rfind -- no regex.
    """
    marker_idx = html.index(START_MARKER)
    start_idx = html.rfind(OPEN_DIV_PREFIX, 0, marker_idx)
    end_idx = html.index(END_MARKER, marker_idx)
    return html[start_idx:end_idx]


def write_stats(bucket: dict, by_lane: dict | None = None) -> None:
    stats = {
        "lifetime": bucket,
        "window_30d": bucket,
        "window_30d_since": None,
        "by_lane": by_lane or {},
    }
    ROUTER_STATS_PATH.parent.mkdir(parents=True, exist_ok=True)
    ROUTER_STATS_PATH.write_text(json.dumps(stats))


def empty_bucket() -> dict:
    return {
        "routed": 0,
        "failed_open": 0,
        "input_tokens_by_model": {},
        "output_tokens_by_model": {},
        "baseline_input_tokens_by_model": {},
        "baseline_output_tokens_by_model": {},
        "delta_input_tokens_by_model": {},
        "delta_output_tokens_by_model": {},
        "unknown_cost_calls": 0,
    }


results = {}

# ── Scenario 1: stats.json absent -> dimmed, no exception ──────────────────
if ROUTER_STATS_PATH.exists():
    ROUTER_STATS_PATH.unlink()
try:
    html1 = dash.render_headroom(repo_path=None, pricing_snapshots=PRICING)
    results["absent_no_exception"] = True
except Exception as exc:  # noqa: BLE001 - this IS the probe
    results["absent_no_exception"] = False
    results["absent_exception"] = repr(exc)
    html1 = ""
if html1:
    region1 = router_region(html1)
    results["absent_dimmed"] = "opacity:.45;" in region1
    results["absent_note"] = "not installed / no stats.json yet" in region1

# ── Scenario 2: normal data -- one save, one escalation, net to $0.00 ──────
# Call A: selected=cheap, baseline=expensive, 1,000,000 input tokens -> saves
#   $3.00 - $1.00 = $2.00.
# Call B: selected=expensive, baseline=cheap, 1,000,000 input tokens -> costs
#   $3.00 - $1.00 = $2.00 extra (a plain escalation, not flagged suspect).
# Net saving must be exactly their sum: $2.00 - $2.00 = $0.00.
bucket2 = empty_bucket()
bucket2["routed"] = 2
bucket2["input_tokens_by_model"] = {"cheap": 1_000_000, "expensive": 1_000_000}
bucket2["baseline_input_tokens_by_model"] = {"expensive": 1_000_000, "cheap": 1_000_000}
write_stats(bucket2)
html2 = dash.render_headroom(repo_path=None, pricing_snapshots=PRICING)
region2 = router_region(html2)
results["normal_not_dimmed"] = "opacity:.45;" not in region2
results["normal_net_saving"] = "$0.00" in region2
results["normal_tokens"] = "2,000,000" in region2
results["normal_note"] = (
    "2 routed · 0 fallback · 0 suspected bad-route model(s) (not subtracted) "
    "· 0 unknown-cost excluded" in region2
)

# ── Scenario 3: unknown-cost calls present, excluded from Net Saving ───────
# One priced call: selected=cheap, baseline=expensive, 500,000 input tokens
#   -> saves $1.50 - $0.50 = $1.00 by hand. Plus 3 unknown-cost calls, which
# per R8.7 arrive with zero tokens at the source and so never touch this sum
# -- only the visible counter below should move.
bucket3 = empty_bucket()
bucket3["routed"] = 4
bucket3["unknown_cost_calls"] = 3
bucket3["input_tokens_by_model"] = {"cheap": 500_000}
bucket3["baseline_input_tokens_by_model"] = {"expensive": 500_000}
write_stats(bucket3)
html3 = dash.render_headroom(repo_path=None, pricing_snapshots=PRICING)
region3 = router_region(html3)
results["unknown_net_saving"] = "$1.00" in region3
results["unknown_count_shown"] = "3 unknown-cost excluded" in region3
results["unknown_note"] = (
    "4 routed · 0 fallback · 0 suspected bad-route model(s) (not subtracted) "
    "· 3 unknown-cost excluded" in region3
)

# ── Scenario 4: suspected-bad-route models shown, not subtracted twice ─────
# Call D: selected=cheap, baseline=expensive, 2,000,000 input tokens -> saves
#   $6.00 - $2.00 = $4.00.
# Call E: selected=mid, baseline=cheap, 1,000,000 input tokens, flagged
#   suspect -> costs $2.00 - $1.00 = $1.00 extra.
# Call F: selected=expensive, baseline=cheap, 1,000,000 input tokens, flagged
#   suspect -> costs $3.00 - $1.00 = $2.00 extra.
# Net saving by hand, from priced buckets only: $4.00 - $1.00 - $2.00 = $1.00.
# delta_*_tokens_by_model (E and F) feeds ONLY the suspect-model count (2:
# "mid" and "expensive"), never a second subtraction -- if it did, net would
# instead read -$4.00 (($4.00-$1.00-$2.00) minus the delta cost again), so an
# exact "$1.00" match here is a regression lock on that boundary.
bucket4 = empty_bucket()
bucket4["routed"] = 3
bucket4["input_tokens_by_model"] = {"cheap": 2_000_000, "mid": 1_000_000, "expensive": 1_000_000}
bucket4["baseline_input_tokens_by_model"] = {"expensive": 2_000_000, "cheap": 2_000_000}
bucket4["delta_input_tokens_by_model"] = {"mid": 1_000_000, "expensive": 1_000_000}
write_stats(bucket4)
html4 = dash.render_headroom(repo_path=None, pricing_snapshots=PRICING)
region4 = router_region(html4)
results["suspect_net_saving"] = "$1.00" in region4
results["suspect_labelled_models_not_calls"] = (
    "2 suspected bad-route model(s) (not subtracted)" in region4
    and "bad-route calls" not in region4
)
results["suspect_note"] = (
    "3 routed · 0 fallback · 2 suspected bad-route model(s) (not subtracted) "
    "· 0 unknown-cost excluded" in region4
)

print(json.dumps(results))
PY

RESULT="$(HOME="$HOME_DIR" XDG_DATA_HOME="$HOME_DIR/.local/share" XDG_CONFIG_HOME="$HOME_DIR/.config" python3 "$TMP/drive.py" "$DASHBOARD" "$HOME_DIR")" || {
  echo "  FAIL  driver did not run"
  echo "$RESULT"
  exit 1
}

cat > "$TMP/field.py" <<'PY'
import json
import sys

d = json.loads(sys.stdin.read())
print(d.get(sys.argv[1], "<missing>"))
PY

field() { printf '%s' "$RESULT" | python3 "$TMP/field.py" "$1"; }

echo "dashboard router layer"

echo "-- scenario: stats.json absent (dimmed, no exception) --"
check "render_headroom() does not raise when stats.json is absent" \
  "True" "$(field absent_no_exception)"
check "absent layer is dimmed (opacity:.45)" "True" "$(field absent_dimmed)"
check "absent layer shows 'not installed / no stats.json yet'" "True" "$(field absent_note)"

echo "-- scenario: normal data (one save, one escalation, net \$0.00) --"
check "normal layer renders live (not dimmed)" "True" "$(field normal_not_dimmed)"
check "Net Saving = baseline - actual = \$2.00 - \$2.00 = \$0.00 exactly" \
  "True" "$(field normal_net_saving)"
check "baseline/actual token totals both read 2,000,000" "True" "$(field normal_tokens)"
check "note shows 2 routed, 0 suspect, 0 unknown-cost" "True" "$(field normal_note)"

echo "-- scenario: unknown-cost calls present (excluded, not subtracted) --"
check "Net Saving = \$1.50 - \$0.50 = \$1.00, unaffected by 3 unknown-cost calls" \
  "True" "$(field unknown_net_saving)"
check "unknown-cost count (3) is shown" "True" "$(field unknown_count_shown)"
check "note shows 4 routed, 0 suspect, 3 unknown-cost excluded" "True" "$(field unknown_note)"

echo "-- scenario: suspected-bad-route models present (shown, not double-subtracted) --"
check "Net Saving = \$4.00 - \$1.00 - \$2.00 = \$1.00 (delta tokens not re-subtracted)" \
  "True" "$(field suspect_net_saving)"
check "labelled 'model(s)' with count 2, never 'calls'" \
  "True" "$(field suspect_labelled_models_not_calls)"
check "note shows 3 routed, 2 suspect bad-route model(s), 0 unknown-cost" \
  "True" "$(field suspect_note)"

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
