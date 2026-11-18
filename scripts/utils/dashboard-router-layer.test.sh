#!/usr/bin/env bash
# dashboard-router-layer.test.sh — proves the Router pipeline layer in
# `render_headroom()` (dashboard.py) renders correctly and that Net Saving is
# always `cost as requested - cost as routed` summed over ledger rows, priced
# over the full bill (uncached input, output, cache reads, cache writes) —
# never adjusted a second time for errored calls or the suspected-bad-route
# model count, both of which are informational only.
#
# Since 2026-11-17 the dollar figures come from ~/.sdd-router/ledger.jsonl,
# not stats.json: only ledger rows carry cache usage and the per-call
# counterfactual (ledger.py `counterfactual_cache_tokens`), and cache
# reads/writes are most of the real bill. stats.json still gates the layer
# (absent => dimmed) and supplies the routed/fallback/suspect counts.
#
# Mechanism: dashboard.py reads `Path.home() / ".sdd-router" / ...`, and
# `Path.home()` honours `HOME`, so every scenario runs with HOME pointed at a
# throwaway `mktemp -d` tree — the real ~/.sdd-router and ~/.claude are never
# read or written. `render_headroom()` is called directly with a fabricated
# `pricing_snapshots` argument so no network fetch ever happens.
#
# Pricing fixture: fictitious models at $1/$2/$3 per-million input tokens
# ("cheap"/"mid"/"expensive") with output 5x, cache reads 0.1x and 5-minute
# cache writes 1.25x input (Anthropic's ratios) — chosen so every scenario's
# Net Saving is an exact dollar figure. "unpriced" is deliberately absent.
#
# Extraction: the returned HTML is sliced to just the Router layer's own
# <div> plus its route table, up to the next section's "Headroom — Current
# Session" heading, using str.find/rfind only (no regex). All assertions are
# scoped to that slice so a match in another layer can never pass this test.
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

cat > "$TMP/drive.py" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

DASHBOARD = sys.argv[1]
HOME_DIR = Path(sys.argv[2])
ROUTER_DIR = HOME_DIR / ".sdd-router"
STATS = ROUTER_DIR / "stats.json"
LEDGER = ROUTER_DIR / "ledger.jsonl"

spec = importlib.util.spec_from_file_location("dash", DASHBOARD)
dash = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dash)


def price(per_m_input: float) -> dict:
    return {
        "input": per_m_input, "output": per_m_input * 5,
        "cache_read": per_m_input * 0.1, "cache_write": per_m_input * 1.25,
    }


PRICING = [{
    "fetched_at": "2020-01-01T00:00:00Z",
    "models": {
        "anthropic/cheap": price(1.0),
        "anthropic/mid": price(2.0),
        "anthropic/expensive": price(3.0),
    },
}]

OPEN_DIV_PREFIX = '<div style="background:var(--surface0);border-radius:8px;padding:14px 16px;'
START_MARKER = "Router — Model Selection"
END_MARKER = "Headroom — Current Session"


def router_region(html: str) -> str:
    marker_idx = html.index(START_MARKER)
    start_idx = html.rfind(OPEN_DIV_PREFIX, 0, marker_idx)
    end_idx = html.index(END_MARKER, marker_idx)
    return html[start_idx:end_idx]


def card(region: str) -> str:
    """The card alone, without the route table below it."""
    end = region.find("Router Routes")
    return region if end < 0 else region[:end]


def write_stats(routed: int, suspect_models: tuple = ()) -> None:
    bucket = {
        "routed": routed, "failed_open": 0,
        "delta_input_tokens_by_model": {m: 1 for m in suspect_models},
        "delta_output_tokens_by_model": {},
    }
    ROUTER_DIR.mkdir(parents=True, exist_ok=True)
    STATS.write_text(json.dumps({"lifetime": bucket, "window_30d": bucket, "by_lane": {}}))


def row(base, sel, i=0, o=0, cr=0, cc=0, cc1h=0, bcr=None, bcc=None, bcc1h=None,
        cost_state="known", tracked=True) -> dict:
    """One ledger line. Baseline cache fields default to the unrouted rule
    (identical to actual); routed scenarios pass them explicitly."""
    r = {
        "baseline_model": base, "selected_model": sel, "cost_state": cost_state,
        "input_tokens": i, "output_tokens": o,
    }
    if tracked:
        r.update({
            "cache_read_tokens": cr, "cache_creation_tokens": cc, "cache_creation_1h_tokens": cc1h,
            "baseline_cache_read_tokens": cr if bcr is None else bcr,
            "baseline_cache_creation_tokens": cc if bcc is None else bcc,
            "baseline_cache_creation_1h_tokens": cc1h if bcc1h is None else bcc1h,
        })
    return r


def write_ledger(rows: list) -> None:
    ROUTER_DIR.mkdir(parents=True, exist_ok=True)
    LEDGER.write_text("".join(json.dumps(r) + "\n" for r in rows))


def render() -> str:
    return router_region(dash.render_headroom(repo_path=None, pricing_snapshots=PRICING))


results = {}

# ── 1: stats.json absent -> dimmed, no exception ─────────────────────────────
try:
    html1 = dash.render_headroom(repo_path=None, pricing_snapshots=PRICING)
    results["absent_no_exception"] = True
    region1 = router_region(html1)
    results["absent_dimmed"] = "opacity:.45;" in region1
    results["absent_note"] = "not installed / no stats.json yet" in region1
except Exception as exc:  # noqa: BLE001 - this IS the probe
    results["absent_no_exception"] = False
    results["absent_exception"] = repr(exc)

# ── 2: one save, one escalation -> net $0.00 ─────────────────────────────────
# A: expensive -> cheap, 1M input: $3.00 - $1.00 = $2.00 saved.
# B: cheap -> expensive, 1M input: $1.00 - $3.00 = $2.00 lost.
write_stats(routed=2)
write_ledger([row("expensive", "cheap", i=1_000_000), row("cheap", "expensive", i=1_000_000)])
region2 = render()
results["normal_not_dimmed"] = "opacity:.45;" not in region2
results["normal_net_saving"] = "$0.00" in card(region2)
results["normal_tokens"] = "2,000,000" in card(region2)
results["normal_note"] = "2 routed · 0 fallback · 0 suspected bad-route model(s) (not subtracted)" in region2

# ── 3: errored and pre-tracking rows never move Net Saving ───────────────────
# One priced row: expensive -> cheap, 500k input: $1.50 - $0.50 = $1.00.
# Three errored rows on the same route (no usage, not billed) and two rows
# from before cache tracking, whose huge token counts must be ignored.
write_stats(routed=6)
write_ledger(
    [row("expensive", "cheap", i=500_000)]
    + [row("expensive", "cheap", cost_state="unknown") for _ in range(3)]
    + [row("expensive", "cheap", i=9_000_000, tracked=False) for _ in range(2)]
)
region3 = render()
results["errored_net_saving"] = "$1.00" in card(region3)
results["errored_count_shown"] = "(3 errored)" in region3
results["untracked_footnote"] = "2 calls logged before cache tracking began" in region3

# ── 4: suspected-bad-route models shown, never subtracted twice ──────────────
# D: expensive -> cheap, 2M: $6.00 - $2.00 = $4.00 saved.
# E: cheap -> mid, 1M: $1.00 - $2.00 = $1.00 lost.
# F: cheap -> expensive, 1M: $1.00 - $3.00 = $2.00 lost.  Net = $1.00.
write_stats(routed=3, suspect_models=("mid", "expensive"))
write_ledger([
    row("expensive", "cheap", i=2_000_000),
    row("cheap", "mid", i=1_000_000),
    row("cheap", "expensive", i=1_000_000),
])
region4 = render()
results["suspect_net_saving"] = "$1.00" in card(region4)
results["suspect_labelled_models_not_calls"] = (
    "2 suspected bad-route model(s) (not subtracted)" in region4
    and "bad-route calls" not in region4
)

# ── 5: the cold-cache penalty makes a route lose money ───────────────────────
# Routed expensive -> cheap; cheap had to write 1M cache tokens (5-minute)
# that expensive already held: as routed $1.25 (1M x 1.25), as requested
# $0.30 (1M reads x 0.3). Net = -$0.95, shown red.
write_stats(routed=1)
write_ledger([row("expensive", "cheap", cc=1_000_000, bcr=1_000_000, bcc=0, bcc1h=0)])
region5 = render()
results["cache_loss_net"] = "-$0.95" in card(region5)
results["cache_loss_red"] = "color:var(--red)\">-$0.95" in card(region5)
results["cache_columns"] = "CACHE READ" in region5 and "CACHE WRITE" in region5

# ── 6: 1-hour cache writes bill at 2x input ──────────────────────────────────
# Same as 5 but all 1M writes are 1-hour: as routed 1M x 2 x $1 = $2.00,
# as requested $0.30. Net = -$1.70.
write_stats(routed=1)
write_ledger([row("expensive", "cheap", cc=1_000_000, cc1h=1_000_000, bcr=1_000_000, bcc=0, bcc1h=0)])
results["cache_1h_net"] = "-$1.70" in card(render())

# ── 7: an unpriced model is named, not silently priced at $0 ─────────────────
write_stats(routed=2)
write_ledger([row("expensive", "cheap", i=1_000_000), row("expensive", "unpriced", i=1_000_000)])
region7 = render()
results["unpriced_named"] = "Not priced (model missing from pricing catalogue): expensive → unpriced" in region7
results["unpriced_excluded_from_net"] = "$2.00" in card(region7)

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
check "render_headroom() does not raise when stats.json is absent" "True" "$(field absent_no_exception)"
check "absent layer is dimmed (opacity:.45)" "True" "$(field absent_dimmed)"
check "absent layer shows 'not installed / no stats.json yet'" "True" "$(field absent_note)"

echo "-- scenario: one save, one escalation (net \$0.00) --"
check "normal layer renders live (not dimmed)" "True" "$(field normal_not_dimmed)"
check "Net Saving = \$2.00 saved - \$2.00 lost = \$0.00" "True" "$(field normal_net_saving)"
check "tokens on routed calls reads 2,000,000" "True" "$(field normal_tokens)"
check "note shows 2 routed, 0 suspect" "True" "$(field normal_note)"

echo "-- scenario: errored and pre-tracking rows (excluded, not subtracted) --"
check "Net Saving = \$1.00, unaffected by errored and pre-tracking rows" "True" "$(field errored_net_saving)"
check "errored count (3) is shown on its route" "True" "$(field errored_count_shown)"
check "pre-tracking rows (2) are named in a footnote" "True" "$(field untracked_footnote)"

echo "-- scenario: suspected-bad-route models (shown, not double-subtracted) --"
check "Net Saving = \$4.00 - \$1.00 - \$2.00 = \$1.00" "True" "$(field suspect_net_saving)"
check "labelled 'model(s)' with count 2, never 'calls'" "True" "$(field suspect_labelled_models_not_calls)"

echo "-- scenario: cache costs --"
check "cold-cache writes make the route lose money: -\$0.95" "True" "$(field cache_loss_net)"
check "a loss is shown in red" "True" "$(field cache_loss_red)"
check "route table has CACHE READ / CACHE WRITE columns" "True" "$(field cache_columns)"
check "1-hour cache writes bill at 2x input: -\$1.70" "True" "$(field cache_1h_net)"

echo "-- scenario: unpriced model --"
check "unpriced route is named in a footnote" "True" "$(field unpriced_named)"
check "unpriced route is left out of Net Saving (\$2.00)" "True" "$(field unpriced_excluded_from_net)"

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
