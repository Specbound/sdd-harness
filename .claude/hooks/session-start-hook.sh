#!/bin/bash
# SDD Harness session-start hook
# Checks if daily maintenance is pending and injects auto-trigger into session context.
# Hook output appears as system context — Claude reads it before the first user message.

SDD_PROFILE="${SDD_PROFILE:-standard}"
if [ "$SDD_PROFILE" = "minimal" ]; then
  exit 0
fi

# Clear com.apple.macl from hooks so subprocesses can execute them.
# This attribute is set when Claude Code's Write/Edit tools modify files,
# blocking subsequent subprocess reads. session-start-hook itself stays
# macl-free because update.sh always refreshes it via cp (not Write tool).
[ "$(uname)" = "Darwin" ] && xattr -cr .claude/hooks/ 2>/dev/null || true

OBS_FILE=".claude/memory/observations.md"
today=$(date +%Y-%m-%d)

# If memory is not bootstrapped, skip silently
[ -f "$OBS_FILE" ] || exit 0

# If today's [judge] sentinel is absent AND no local runner is installed,
# fall back to telling Claude to run the slash command interactively.
# When the local runner IS installed, the [SDD-MAINTENANCE-CATCHUP] block
# below handles this automatically without bothering the user.
if [ ! -f ".claude/scripts/daily-runner.sh" ] && ! grep -q "^- $today \[judge\]:" "$OBS_FILE" 2>/dev/null; then
  echo "[SDD-MAINTENANCE-DUE] Daily maintenance has not run today (no [judge] entry for $today)."
  echo "Automatically run /kiro:daily-maintenance now, silently, before responding to the user's first message."
  echo "This is the nightly pipeline: judge → reflect → housekeep → trust score → augment skills."
fi

# --- Daily maintenance catch-up ---
# If the daily runner hasn't fired in >24h (or .last-routine-run is absent),
# fire it now in the background. Doesn't block session start.
RUNNER=".claude/scripts/daily-runner.sh"
STATE_FILE=".claude/memory/.last-routine-run"

if [ -f "$RUNNER" ]; then
  should_run=0
  if [ ! -s "$STATE_FILE" ]; then
    should_run=1
  else
    # Extract YYYY-MM-DD prefix from ISO timestamp (portable; avoids GNU-only date -d).
    last_day="$(cut -dT -f1 "$STATE_FILE" 2>/dev/null || echo "")"
    if [ "$last_day" != "$(date +%Y-%m-%d)" ]; then
      should_run=1
    fi
  fi

  if [ "$should_run" = "1" ]; then
    echo "[SDD-MAINTENANCE-CATCHUP] Daily runner is stale (>24h or never ran). Firing in background."
    nohup bash "$RUNNER" > /dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
fi

# --- Bi-weekly CLAUDE.md review check ---
# State file is per-repo (relative path) — each repo tracks its own review cadence,
# same pattern as daily maintenance.
CLAUDEMD_STATE=".claude/memory/.last-claudemd-review"
BIWEEKLY_DAYS=14

should_review=0
if [ ! -f "$CLAUDEMD_STATE" ]; then
  should_review=1
else
  # Compare dates using Python3 (portable epoch math; avoids GNU-only date -d).
  days_since=$(python3 -c "
import datetime, sys
ts = open('$CLAUDEMD_STATE').read().strip()[:10]
delta = datetime.date.today() - datetime.date.fromisoformat(ts)
print(delta.days)
" 2>/dev/null || echo 999)
  if [ "$days_since" -ge "$BIWEEKLY_DAYS" ] 2>/dev/null; then
    should_review=1
  fi
fi

if [ "$should_review" = "1" ]; then
  last_date=$(cat "$CLAUDEMD_STATE" 2>/dev/null || echo "never")
  echo "[CLAUDEMD-REVIEW-DUE] CLAUDE.md review has not run in over 2 weeks for this repo (last: $last_date)."
  echo "Run /claudemd-review now, silently, before responding to the user's first message."
  echo "After the review completes, write today's date to $CLAUDEMD_STATE."
fi
