#!/bin/bash
# Local daily maintenance runner — one repo's daily loop.
# Designed to be invoked from this repo's working directory:
#   cd <repo> && bash .claude/scripts/orchestration/daily-runner.sh
#
# Idempotent: writes today's date to .claude/memory/.last-routine-run at START;
# a second invocation on the same day exits in <1s.
# Race-safe: mkdir-based lock (portable; flock is Linux-only).

set -u

REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
MEMORY_DIR=".claude/memory"
STATE_FILE="$MEMORY_DIR/.last-routine-run"
LOCK_DIR="$MEMORY_DIR/.runner.lock"
PROMPT_TEMPLATE=".claude/scripts/routines/daily-maintenance-prompt.md"
TIMESTAMP="$(date -Iseconds)"

log() {
  echo "[$TIMESTAMP] $REPO_NAME: $*" >&2
}

# --- Guards ---
if [ ! -d "$MEMORY_DIR" ]; then
  log "memory-not-bootstrapped, skipping"
  exit 0
fi

if [ ! -f "$PROMPT_TEMPLATE" ]; then
  log "prompt-template-missing ($PROMPT_TEMPLATE), skipping"
  exit 1
fi

# --- Race protection (mkdir is atomic; works on macOS and Linux) ---
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another runner active, skipping"
  exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

# --- Date check (cheap short-circuit) ---
# Extract YYYY-MM-DD prefix from ISO timestamp — portable, no GNU date needed.
TODAY="$(date +%Y-%m-%d)"
if [ -s "$STATE_FILE" ]; then
  LAST_DAY="$(cut -dT -f1 "$STATE_FILE" 2>/dev/null || echo "")"
  if [ "$LAST_DAY" = "$TODAY" ]; then
    log "already ran today ($LAST_DAY), skipping"
    exit 0
  fi
fi

# --- Pre-flight: claude CLI must be available ---
if ! command -v claude >/dev/null 2>&1; then
  log "claude CLI not on PATH, aborting"
  exit 1
fi

# --- Substitute today's date into prompt ---
PROMPT="$(sed "s|TODAY_PLACEHOLDER|$TODAY|" "$PROMPT_TEMPLATE")"

# --- Mark started (commits us to today; do this only after pre-flight passes) ---
echo "$TIMESTAMP" > "$STATE_FILE"
log "starting daily maintenance"

# --- Invoke claude ---
echo "$PROMPT" | SDD_HEADLESS=1 claude --print --output-format text --permission-mode bypassPermissions
EXIT=$?

log "completed exit=$EXIT"
exit $EXIT
