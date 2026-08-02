#!/bin/bash
# Local weekly skill-curator runner — runs the weekly skill quality audit,
# description budget audit, and memory governance health check for the sdd-harness.
# Invoke from the repo's working directory:
#   cd <harness-repo> && bash .claude/scripts/routines/skill-curator-runner.sh
#
# Harness-only: exits 0 immediately in non-harness repos (checks for docs/scheduled-tasks/).
# Cadence: MIN_GAP_DAYS=7 (weekly). Self-pacing via state file — no separate scheduler.
# Race-safe via mkdir lock (portable; flock is Linux-only).
# Override cadence with SKILL_CURATOR_GAP_DAYS; force a run with SKILL_CURATOR_FORCE=1.

set -u

REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
MEMORY_DIR=".claude/memory"
STATE_FILE="$MEMORY_DIR/.last-skill-curator-run"
LOCK_DIR="$MEMORY_DIR/.skill-curator.lock"
PROMPT_TEMPLATE=".claude/scripts/routines/skill-curator-prompt.md"
MIN_GAP_DAYS="${SKILL_CURATOR_GAP_DAYS:-7}"
TIMESTAMP="$(date -Iseconds)"
TODAY="$(date +%Y-%m-%d)"

log() { echo "[$TIMESTAMP] $REPO_NAME skill-curator: $*" >&2; }

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
# Stale lock: if >2h old it was left by a SIGKILL'd run — safe to remove.
if [ -d "$LOCK_DIR" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -gt 7200 ]; then
    log "removing stale lock (age=${LOCK_AGE}s)"
    rm -rf "$LOCK_DIR"
  fi
fi
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another sweep active, skipping"
  exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

# --- Cadence guard: skip if last run was < MIN_GAP_DAYS ago (unless forced) ---
if [ "${SKILL_CURATOR_FORCE:-0}" != "1" ] && [ -s "$STATE_FILE" ]; then
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
log "starting skill-curator sweep"

# --- Invoke claude ---
echo "$PROMPT" | SDD_HEADLESS=1 claude --print --output-format text --permission-mode bypassPermissions
EXIT=$?

log "completed exit=$EXIT"
exit $EXIT
