#!/bin/bash
# SDD Harness stop hook
# 1. Check if harness has updates since last install
# 2. Nudge /kiro:housekeeping if observations.md > 50 entries

HARNESS_DIR="$HOME/.claude/sdd-harness"
LAST_CHECK_FILE=".claude/.last-harness-check"

# --- Harness update check ---
if [ -d "$HARNESS_DIR/.git" ]; then
  HARNESS_LAST_COMMIT=$(cd "$HARNESS_DIR" && git log -1 --format="%aI" 2>/dev/null)
  if [ -f "$LAST_CHECK_FILE" ]; then
    LAST_CHECK=$(cat "$LAST_CHECK_FILE" | tr -d '[:space:]')
    if [[ "$HARNESS_LAST_COMMIT" > "$LAST_CHECK" ]]; then
      echo ""
      echo "SDD harness has updates since your last install."
      echo "Run: ~/.claude/sdd-harness/update.sh"
      echo ""
    fi
  fi
fi

# --- Memory health check ---
OBS_FILE=".claude/memory/observations.md"
if [ -f "$OBS_FILE" ]; then
  ENTRY_COUNT=$(grep -c "^- [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" "$OBS_FILE" 2>/dev/null || echo 0)
  if [ "$ENTRY_COUNT" -gt 50 ]; then
    echo ""
    echo "observations.md has $ENTRY_COUNT entries (limit: 50)."
    echo "Run: /kiro:housekeeping"
    echo ""
  fi
fi
