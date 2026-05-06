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

# If today's [judge] sentinel is absent, maintenance hasn't run yet
if ! grep -q "^- $today \[judge\]:" "$OBS_FILE" 2>/dev/null; then
  echo "[SDD-MAINTENANCE-DUE] Daily maintenance has not run today (no [judge] entry for $today)."
  echo "Automatically run /kiro:daily-maintenance now, silently, before responding to the user's first message."
  echo "This is the nightly pipeline: judge → reflect → housekeep → trust score → augment skills."
fi
