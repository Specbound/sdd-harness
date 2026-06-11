#!/bin/bash
# SDD Harness stop hook
# 1. Check if harness has updates since last install
# 2. Nudge /kiro:housekeeping if observations.md > 50 entries

# Profile guard — skip all checks if profile is minimal
SDD_PROFILE="${SDD_PROFILE:-standard}"
if [ "$SDD_PROFILE" = "minimal" ]; then
  exit 0
fi

HARNESS_DIR="$(cat "$HOME/.sdd-harness-root" 2>/dev/null || true)"
if [ -z "$HARNESS_DIR" ] || [ ! -d "$HARNESS_DIR" ]; then
  exit 0
fi
LAST_CHECK_FILE=".claude/.last-harness-check"

# --- Harness update check ---
if [ -d "$HARNESS_DIR/.git" ]; then
  HARNESS_LAST_COMMIT=$(cd "$HARNESS_DIR" && git log -1 --format="%aI" 2>/dev/null)
  if [ -f "$LAST_CHECK_FILE" ]; then
    LAST_CHECK=$(cat "$LAST_CHECK_FILE" | tr -d '[:space:]')
    if [[ "$HARNESS_LAST_COMMIT" > "$LAST_CHECK" ]]; then
      echo ""
      echo "SDD harness has updates since your last install."
      echo "Run: $HARNESS_DIR/update.sh"
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

# --- Memory-gap detection (re-explanation signal) ---
# Scan the current session's transcript for phrases indicating the user had to
# re-explain context — each hit = a memory the harness should have saved.
# Runs in background; failures are silent (detector is best-effort).
DETECTOR=".claude/scripts/session/detect_reexplanation.py"
if [ -f "$DETECTOR" ] && [ -f "$OBS_FILE" ]; then
  (
    today=$(date +%Y-%m-%d)
    # Skip if today's [memory-gap] already exists (idempotency guard)
    if ! grep -q "^- $today \[memory-gap\]:" "$OBS_FILE" 2>/dev/null; then
      python3 "$DETECTOR" --auto-transcript --emit observation 2>/dev/null >> "$OBS_FILE" || true
    fi
  ) &
fi

# --- Session depth tracking (context health) ---
SESSION_HISTORY=".claude/memory/.session-history"
if [ -d ".claude/memory" ]; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$SESSION_HISTORY"
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

# --- Loop-debt detection (cognitive surrender proxy) ---
# Emit [loop-debt] if skill updates ran ≥3 days ago with no session-charge since.
# Signal: loop shipped improvements the human never engaged with.
if [ -f "$OBS_FILE" ]; then
  today=$(date +%Y-%m-%d)
  if ! grep -q "^- $today \[loop-debt\]:" "$OBS_FILE" 2>/dev/null; then
    python3 - "$OBS_FILE" "$today" <<'PYEOF' >> "$OBS_FILE" 2>/dev/null || true
import sys, re, datetime
obs_path, today_str = sys.argv[1], sys.argv[2]
today = datetime.date.fromisoformat(today_str)
pat = re.compile(r"^- (\d{4}-\d{2}-\d{2}) \[([^\]]+)\]:")
last_update = last_charge = None
for line in open(obs_path).read().splitlines():
    m = pat.match(line)
    if not m:
        continue
    d = datetime.date.fromisoformat(m.group(1))
    tag = m.group(2)
    if tag == "skill-update" and (last_update is None or d > last_update):
        last_update = d
    if tag == "session-charge" and (last_charge is None or d > last_charge):
        last_charge = d
if last_update is None:
    sys.exit(0)
days_since = (today - last_update).days
if days_since < 3:
    sys.exit(0)
if last_charge and last_charge >= last_update:
    sys.exit(0)
print(f"- {today_str} [loop-debt]: skill updates from {last_update} ({days_since}d ago) with no session-charge since — possible cognitive surrender")
PYEOF
  fi
fi
