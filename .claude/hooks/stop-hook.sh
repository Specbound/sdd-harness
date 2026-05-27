#!/bin/bash
# SDD Harness stop hook
# 1. Check if harness has updates since last install
# 2. Nudge /kiro:housekeeping if observations.md > 50 entries

# Profile guard — skip all checks if profile is minimal
SDD_PROFILE="${SDD_PROFILE:-standard}"
if [ "$SDD_PROFILE" = "minimal" ]; then
  exit 0
fi

# Detect harness root from this script's location (works with absolute or relative invocation).
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "$_SCRIPT_DIR/../.." && pwd)"
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

# --- Session signal detection (drain + charge) ---
# Drain: re-explanation phrases the user had to say → [memory-gap]
# Charge: unambiguous approval phrases → [session-charge]
# Both write at most once per calendar day (idempotent).
DETECTOR="$HARNESS_DIR/scripts/detect_reexplanation.py"
# Skip detector in headless/print sessions to prevent recursive spawning.
# daily-runner.sh sets SDD_HEADLESS=1 before invoking claude --print.
if [ -f "$DETECTOR" ] && [ -f "$OBS_FILE" ] && [ "${SDD_HEADLESS:-0}" != "1" ]; then
  (
    today=$(date +%Y-%m-%d)

    # Drain
    drain_hits=$(python3 "$DETECTOR" --auto-transcript --mode drain 2>/dev/null || echo "[]")
    drain_count=$(echo "$drain_hits" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)
    if [ "$drain_count" -gt 0 ] && ! grep -q "^- $today \[memory-gap\]:" "$OBS_FILE" 2>/dev/null; then
      topic=$(echo "$drain_hits" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(", ".join(sorted({h["suggested_memory_topic"] for h in d}))[:80])' 2>/dev/null || echo "?")
      echo "- $today [memory-gap]: $drain_count re-explanation phrase(s) detected — topics: $topic" >> "$OBS_FILE"
    fi

    # Micro-reflect: immediately ingest drain context into hot-memory as [auto-learn] entries.
    # These are probationary — housekeeping promotes or removes them within 7 days.
    MICRO_REFLECT="$HARNESS_DIR/scripts/micro_reflect.py"
    if [ -f "$MICRO_REFLECT" ] && [ "$drain_count" -gt 0 ] && [ -f ".claude/memory/hot-memory.md" ]; then
      echo "$drain_hits" | python3 "$MICRO_REFLECT" 2>/dev/null
    fi

    # Charge
    if ! grep -q "^- $today \[session-charge\]:" "$OBS_FILE" 2>/dev/null; then
      charge_hits=$(python3 "$DETECTOR" --auto-transcript --mode charge 2>/dev/null || echo "[]")
      charge_count=$(echo "$charge_hits" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)
      if [ "$charge_count" -gt 0 ]; then
        echo "- $today [session-charge]: $charge_count approval signal(s) detected in session" >> "$OBS_FILE"
      fi
    fi
  ) &
fi

# --- Session depth tracking (context health) ---
# Appends an ISO timestamp to .claude/memory/.session-history so the dashboard
# can show session frequency and prompt context-management habits.
SESSION_HISTORY=".claude/memory/.session-history"
if [ -d ".claude/memory" ]; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$SESSION_HISTORY"
  # Keep only the last 30 entries
  if [ -f "$SESSION_HISTORY" ]; then
    tail -30 "$SESSION_HISTORY" > "${SESSION_HISTORY}.tmp" && mv "${SESSION_HISTORY}.tmp" "$SESSION_HISTORY"
  fi
fi

# --- Agent failure pattern detection (self-tightening loop) ---
TRACE_LOG=".claude/memory/trace.log"
if [ -f "$TRACE_LOG" ]; then
  # Check for 3+ consecutive failures for the same agent type
  REPEAT_FAILURES=$(awk -F'|' '
    {
      gsub(/^[ \t]+|[ \t]+$/, "", $2); agent=$2
      gsub(/^[ \t]+|[ \t]+$/, "", $4); outcome=$4
    }
    outcome ~ /fail|error|no-go/ {
      if (agent == last_agent) { count++ } else { count=1 }
      last_agent=agent
      if (count >= 3) { print agent; found=1; exit }
    }
  ' "$TRACE_LOG" 2>/dev/null)

  if [ -n "$REPEAT_FAILURES" ]; then
    echo ""
    echo "Agent '$REPEAT_FAILURES' has 3+ consecutive failures in trace.log."
    echo "Run: /kiro:evolve to investigate friction patterns and propose improvements."
    echo ""
  fi
fi
