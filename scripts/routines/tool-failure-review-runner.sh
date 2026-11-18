#!/bin/bash
# Tool-failure review runner — promotes recurring tool failures into memory.
# Invoke from the repo's working directory:
#   cd <repo> && bash .claude/scripts/routines/tool-failure-review-runner.sh
#
# Invoked once per day by the daily orchestrator (per repo). The MIN_GAP_DAYS
# guard self-paces it to ~twice a week: it no-ops unless the last successful
# review was >= MIN_GAP_DAYS ago, AND there is at least one promotable entry in
# the ledger. Downtime-tolerant (next tick after the gap runs it); needs no
# separate scheduler. Race-safe via mkdir lock (portable; flock is Linux-only).
# Override cadence with TOOL_FAILURE_GAP_DAYS; force with TOOL_FAILURE_FORCE=1.

set -u

REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
MEMORY_DIR=".claude/memory"
LEDGER="$MEMORY_DIR/tool-failures.jsonl"
COMMAND_FILE=".claude/commands/kiro/tool-failure-review.md"
STATE_FILE="$MEMORY_DIR/.last-tool-failure-review"
LOCK_DIR="$MEMORY_DIR/.tool-failure-review.lock"
MIN_GAP_DAYS="${TOOL_FAILURE_GAP_DAYS:-3}"
MIN_COUNT="${TOOL_FAILURE_MIN_COUNT:-3}"
TIMESTAMP="$(date -Iseconds)"
TODAY="$(date +%Y-%m-%d)"

log() { echo "[$TIMESTAMP] $REPO_NAME tool-failure-review: $*" >&2; }
# Record why a guard no-opped so the dashboard can tell "idle" from "never fired".
SKIP_FILE="$MEMORY_DIR/.skip-reason-tool-failure-review"
skip() {
  printf '%s|%s\n' "$TIMESTAMP" "${1%, skipping}" > "$SKIP_FILE" 2>/dev/null
  log "$1"
  exit 0
}

# --- Guards ---
if [ ! -d "$MEMORY_DIR" ]; then
  skip "memory-not-bootstrapped, skipping"
fi
if [ ! -f "$LEDGER" ]; then
  skip "no ledger yet, skipping"
fi
if [ ! -f "$COMMAND_FILE" ]; then
  skip "command file missing ($COMMAND_FILE), skipping"
fi

# --- Is there anything promotable? (count >= MIN_COUNT, open, not promoted) ---
PROMOTABLE="$(LEDGER="$LEDGER" MIN_COUNT="$MIN_COUNT" python3 - <<'PY' 2>/dev/null || echo 0
import json, os
led = os.environ["LEDGER"]; mc = int(os.environ["MIN_COUNT"])
n = 0
for line in open(led):
    line = line.strip()
    if not line:
        continue
    try:
        o = json.loads(line)
    except Exception:
        continue
    if o.get("count", 0) >= mc and o.get("status") == "open" and not o.get("promoted"):
        n += 1
print(n)
PY
)"
if [ "${PROMOTABLE:-0}" = "0" ]; then
  skip "no promotable failures (>= ${MIN_COUNT} fails), skipping"
fi

# --- Race protection (mkdir is atomic on macOS and Linux) ---
# Stale lock: if >2h old it was left by a SIGKILL'd run — safe to remove.
if [ -d "$LOCK_DIR" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -gt 7200 ]; then
    log "removing stale lock (age=${LOCK_AGE}s)"
    rm -rf "$LOCK_DIR"
  fi
fi
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  skip "another review active, skipping"
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

# --- Cadence guard: skip if last run was < MIN_GAP_DAYS ago (unless forced) ---
if [ "${TOOL_FAILURE_FORCE:-0}" != "1" ] && [ -s "$STATE_FILE" ]; then
  LAST_RAW="$(cat "$STATE_FILE")"
  # fromisoformat reads the `date -Iseconds` stamp ("+02:00") on any OS. The old
  # `date -j -f ...%z` only accepts "+0200", so on macOS every parse failed, read as
  # epoch 0, and the gap guard never skipped (weekly runners ran daily; 2026-11-18).
  LAST_EPOCH="$(python3 -c 'import sys, datetime; print(int(datetime.datetime.fromisoformat(sys.argv[1]).timestamp()))' "$LAST_RAW" 2>/dev/null || echo 0)"
  if [ "$LAST_EPOCH" -gt 0 ]; then
    GAP_DAYS=$(( ($(date +%s) - LAST_EPOCH) / 86400 ))
    if [ "$GAP_DAYS" -lt "$MIN_GAP_DAYS" ]; then
      skip "last review ${GAP_DAYS}d ago (< ${MIN_GAP_DAYS}d), skipping"
    fi
  fi
fi

# --- Pre-flight: claude CLI must be available ---
if ! command -v claude >/dev/null 2>&1; then
  log "claude CLI not on PATH, aborting"
  exit 1
fi

# --- Mark started (only after pre-flight passes) ---
echo "$TIMESTAMP" > "$STATE_FILE"
rm -f "$SKIP_FILE"
log "starting review ($PROMOTABLE promotable)"

PROMPT="Read and follow the instructions in $COMMAND_FILE to review the accumulated tool-call failure ledger and promote recurring, understood failures into memory. Use min-count $MIN_COUNT. Today is $TODAY."

echo "$PROMPT" | SDD_HEADLESS=1 claude --print --output-format text --permission-mode bypassPermissions
EXIT=$?

log "completed exit=$EXIT"
exit $EXIT
