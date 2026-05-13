#!/bin/bash
# Local daily maintenance runner — one repo's daily loop.
# Designed to be invoked from this repo's working directory:
#   cd <repo> && bash .claude/scripts/daily-runner.sh
#
# Idempotent: writes today's date to .claude/memory/.last-routine-run at START;
# a second invocation on the same day exits in <1s.
# Race-safe: flock prevents two concurrent runners in the same repo.

set -u

REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
MEMORY_DIR=".claude/memory"
STATE_FILE="$MEMORY_DIR/.last-routine-run"
LOCK_FILE="$MEMORY_DIR/.last-routine-run.lock"
PROMPT_TEMPLATE=".claude/scripts/daily-maintenance-prompt.md"
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

mkdir -p "$MEMORY_DIR"
touch "$LOCK_FILE"

# --- Race protection ---
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  log "another runner active, skipping"
  exit 0
fi

# --- Date check (cheap short-circuit) ---
TODAY="$(date +%Y-%m-%d)"
if [ -f "$STATE_FILE" ]; then
  LAST_DAY="$(date -d "$(cat "$STATE_FILE")" +%Y-%m-%d 2>/dev/null || echo "")"
  if [ "$LAST_DAY" = "$TODAY" ]; then
    log "already ran today ($LAST_DAY), skipping"
    exit 0
  fi
fi

# --- Mark started ---
echo "$TIMESTAMP" > "$STATE_FILE"
log "starting daily maintenance"

# --- Substitute today's date into prompt and invoke claude --print ---
PROMPT="$(sed "s|TODAY_PLACEHOLDER|$TODAY|" "$PROMPT_TEMPLATE")"

if ! command -v claude >/dev/null 2>&1; then
  log "claude CLI not on PATH, aborting"
  exit 1
fi

echo "$PROMPT" | claude --print --output-format text
EXIT=$?

log "completed exit=$EXIT"
exit $EXIT
