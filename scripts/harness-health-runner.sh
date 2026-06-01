#!/bin/bash
# Local bi-weekly harness health runner — CLAUDE.md review across registered repos
# plus iterative skill repair. Invoke from the harness repo's working directory:
#   cd <harness-repo> && bash .claude/scripts/harness-health-runner.sh
#
# Harness-only: exits 0 immediately in non-harness repos (checks for docs/scheduled-tasks/).
# Cadence: MIN_GAP_DAYS=13 (~bi-weekly). Self-pacing via state file — no separate scheduler.
# Race-safe via mkdir lock (portable; flock is Linux-only).
# Override cadence with HARNESS_HEALTH_GAP_DAYS; force a run with HARNESS_HEALTH_FORCE=1.

set -u

REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
MEMORY_DIR=".claude/memory"
STATE_FILE="$MEMORY_DIR/.last-harness-health-run"
LOCK_DIR="$MEMORY_DIR/.harness-health.lock"
PROMPT_TEMPLATE=".claude/scripts/harness-health-prompt.md"
MIN_GAP_DAYS="${HARNESS_HEALTH_GAP_DAYS:-13}"
TIMESTAMP="$(date -Iseconds)"
TODAY="$(date +%Y-%m-%d)"

log() { echo "[$TIMESTAMP] $REPO_NAME harness-health: $*" >&2; }

# --- Harness-only guard ---
if [ ! -d "docs/scheduled-tasks" ]; then
  exit 0
fi

# --- Standard guards ---
if [ ! -d "$MEMORY_DIR" ]; then
  log "memory-not-bootstrapped, skipping"
  exit 0
fi
if [ ! -f "$PROMPT_TEMPLATE" ]; then
  log "prompt-template-missing ($PROMPT_TEMPLATE), skipping"
  exit 1
fi

# --- Race protection (mkdir is atomic on macOS and Linux) ---
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another sweep active, skipping"
  exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

# --- Cadence guard: skip if last run was < MIN_GAP_DAYS ago (unless forced) ---
if [ "${HARNESS_HEALTH_FORCE:-0}" != "1" ] && [ -s "$STATE_FILE" ]; then
  LAST_RAW="$(cat "$STATE_FILE")"
  LAST_EPOCH="$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$LAST_RAW" +%s 2>/dev/null \
              || date -d "$LAST_RAW" +%s 2>/dev/null || echo 0)"
  if [ "$LAST_EPOCH" -gt 0 ]; then
    GAP_DAYS=$(( ($(date +%s) - LAST_EPOCH) / 86400 ))
    if [ "$GAP_DAYS" -lt "$MIN_GAP_DAYS" ]; then
      log "last sweep ${GAP_DAYS}d ago (< ${MIN_GAP_DAYS}d), skipping"
      exit 0
    fi
  fi
fi

# --- Pre-flight: claude CLI must be available ---
if ! command -v claude >/dev/null 2>&1; then
  log "claude CLI not on PATH, aborting"
  exit 1
fi

mkdir -p "docs"

# --- Substitute today's date into prompt ---
PROMPT="$(sed "s|TODAY_PLACEHOLDER|$TODAY|g" "$PROMPT_TEMPLATE")"

# --- Mark started ---
echo "$TIMESTAMP" > "$STATE_FILE"
log "starting harness-health sweep"

# --- Invoke claude ---
echo "$PROMPT" | SDD_HEADLESS=1 claude --print --output-format text --permission-mode bypassPermissions
EXIT=$?

log "completed exit=$EXIT"
exit $EXIT
