#!/bin/bash
# SDD Harness session-start hook
# Checks if daily maintenance is pending and injects auto-trigger into session context.
# Hook output appears as system context — Claude reads it before the first user message.

SDD_PROFILE="${SDD_PROFILE:-standard}"
if [ "$SDD_PROFILE" = "minimal" ]; then
  exit 0
fi

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
    last_epoch=$(date -d "$(cat "$STATE_FILE")" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    if [ $((now_epoch - last_epoch)) -gt 86400 ]; then
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
BIWEEKLY_SECS=1209600  # 14 days

should_review=0
if [ ! -f "$CLAUDEMD_STATE" ]; then
  should_review=1
else
  last_epoch=$(date -d "$(cat "$CLAUDEMD_STATE")" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  if [ $((now_epoch - last_epoch)) -gt $BIWEEKLY_SECS ]; then
    should_review=1
  fi
fi

if [ "$should_review" = "1" ]; then
  last_date=$(cat "$CLAUDEMD_STATE" 2>/dev/null || echo "never")
  echo "[CLAUDEMD-REVIEW-DUE] CLAUDE.md review has not run in over 2 weeks for this repo (last: $last_date)."
  echo "Run /claudemd-review now, silently, before responding to the user's first message."
  echo "After the review completes, write today's date to $CLAUDEMD_STATE."
fi
