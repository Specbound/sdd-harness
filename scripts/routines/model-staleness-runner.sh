#!/bin/bash
# model-staleness-runner.sh — weekly check of every Claude model name/ID in the
# harness's skills, agents, commands, hooks, scripts and templates against the
# live lineup on platform.claude.com.
#
# Deterministic (no LLM call). Thin wrapper around scripts/utils/model-staleness.py.
# Writes .claude/reports/model-staleness.json, which session-start-hook.sh reads
# to print [MODEL-STALE] while new findings remain.
# Harness-only: skills/agents/hooks are authored in the harness source tree, so
# downstream repos (installed copies) exit 0 immediately.
# Self-paces to weekly via a state-file guard, so calling it daily from the
# orchestrator is a cheap no-op between runs.
#
# Usage:
#   model-staleness-runner.sh            — current repo (cwd), respecting cadence
#   model-staleness-runner.sh --force    — ignore cadence guard, run now
# Env:
#   SDD_SKIP_MODEL_STALENESS=1           — opt out entirely
#   MODEL_STALENESS_GAP_DAYS=<days>      — cadence override (default 7)

set -u

[ "${SDD_SKIP_MODEL_STALENESS:-0}" = "1" ] && exit 0

REPO="$(pwd)"
FORCE=false
[ "${1:-}" = "--force" ] && FORCE=true

# Harness-only guard (same marker skill-curator-runner.sh uses)
[ -d "$REPO/docs/scheduled-tasks" ] || exit 0
[ -d "$REPO/.claude" ] || exit 0

MIN_GAP_DAYS="${MODEL_STALENESS_GAP_DAYS:-7}"
STATE_FILE="$REPO/.claude/memory/.last-model-staleness"

if [ "$FORCE" = false ] && [ -f "$STATE_FILE" ]; then
  last_day="$(cut -dT -f1 "$STATE_FILE" 2>/dev/null | head -1)"
  if [ -n "$last_day" ]; then
    gap="$(python3 -c "
import datetime
print((datetime.date.today() - datetime.date.fromisoformat('$last_day')).days)
" 2>/dev/null || echo "")"
    if [ -n "$gap" ] && [ "$gap" -lt "$MIN_GAP_DAYS" ] 2>/dev/null; then
      exit 0
    fi
  fi
fi

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CHECK_PY="$SCRIPT_DIR/../utils/model-staleness.py"

[ -f "$CHECK_PY" ] || { echo "model-staleness: $CHECK_PY missing" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "model-staleness: python3 not found" >&2; exit 1; }

mkdir -p "$REPO/.claude/reports"
OUT_FILE="$REPO/.claude/reports/model-staleness.json"

python3 "$CHECK_PY" "$REPO" --json > "$OUT_FILE.tmp"
CHECK_EXIT=$?

# Exit 2 = the live lineup could not be read. Keep the previous report rather
# than overwrite it with nothing, and do not stamp the run: an unread lineup is
# not a clean result, so tomorrow's tick retries.
if [ "$CHECK_EXIT" -gt 1 ]; then
  rm -f "$OUT_FILE.tmp"
  echo "model-staleness: live lineup unreadable (exit=$CHECK_EXIT); previous report kept, will retry" >&2
  exit 1
fi

mv "$OUT_FILE.tmp" "$OUT_FILE"
[ "$CHECK_EXIT" -eq 1 ] && echo "model-staleness: findings recorded in $OUT_FILE" >&2
date -Iseconds > "$STATE_FILE"
exit 0
