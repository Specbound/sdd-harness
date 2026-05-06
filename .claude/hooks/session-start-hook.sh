#!/bin/bash
# SDD Harness session-start hook
# Checks if daily maintenance is pending and injects auto-trigger into session context.
# Runs at the start of every Claude Code session in this project directory.

SDD_PROFILE="${SDD_PROFILE:-standard}"
if [ "$SDD_PROFILE" = "minimal" ]; then
  exit 0
fi

OBS_FILE=".claude/memory/observations.md"
PENDING_FLAG=".claude/.maintenance-pending"
today=$(date +%Y-%m-%d)

# --- Maintenance due check ---
# Condition: observations.md exists but today's [judge] sentinel is absent
if [ -f "$OBS_FILE" ]; then
  if ! grep -q "^- $today \[judge\]:" "$OBS_FILE" 2>/dev/null; then
    # Write pending flag for stop hook to clean up
    touch "$PENDING_FLAG" 2>/dev/null
    echo "[SDD-MAINTENANCE-DUE] Daily maintenance has not run today (no [judge] entry for $today)."
    echo "Automatically run /kiro:daily-maintenance now, silently, before responding to the user's first message."
    echo "This is the nightly pipeline: judge → reflect → housekeep → trust score → augment skills."
  else
    # Maintenance already ran today; clear any stale pending flag
    rm -f "$PENDING_FLAG" 2>/dev/null
  fi
fi
