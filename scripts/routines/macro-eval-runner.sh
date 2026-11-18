#!/bin/bash
# Local macro-eval sweep runner — runs the ~twice-weekly Raindrop trace sweep
# for the current repo. Invoke from the repo's working directory:
#   cd <repo> && bash .claude/scripts/routines/macro-eval-runner.sh
#
# Invoked once per day by the daily orchestrator (per repo). The MIN_GAP_DAYS
# guard self-paces it to roughly twice a week: it no-ops unless the last
# successful sweep was >= MIN_GAP_DAYS ago. This is downtime-tolerant — if the
# machine was off, the next orchestrator tick after the gap runs it — and needs
# no separate scheduler. Race-safe via mkdir lock (portable; flock is Linux-only).
# Override cadence with MACRO_EVAL_GAP_DAYS; force a run with MACRO_EVAL_FORCE=1.

set -u

REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
MEMORY_DIR=".claude/memory"
REPORT_DIR=".claude/reports/macro-evals"
STATE_FILE="$MEMORY_DIR/.last-macro-eval-run"
LOCK_DIR="$MEMORY_DIR/.macro-eval.lock"
PROMPT_TEMPLATE=".claude/scripts/routines/macro-eval-prompt.md"
MIN_GAP_DAYS="${MACRO_EVAL_GAP_DAYS:-3}"
TIMESTAMP="$(date -Iseconds)"
TODAY="$(date +%Y-%m-%d)"

log() { echo "[$TIMESTAMP] $REPO_NAME macro-eval: $*" >&2; }

# --- Guards ---
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
if [ "${MACRO_EVAL_FORCE:-0}" != "1" ] && [ -s "$STATE_FILE" ]; then
  LAST_RAW="$(cat "$STATE_FILE")"
  # fromisoformat reads the `date -Iseconds` stamp ("+02:00") on any OS. The old
  # `date -j -f ...%z` only accepts "+0200", so on macOS every parse failed, read as
  # epoch 0, and the gap guard never skipped (weekly runners ran daily; 2026-11-18).
  LAST_EPOCH="$(python3 -c 'import sys, datetime; print(int(datetime.datetime.fromisoformat(sys.argv[1]).timestamp()))' "$LAST_RAW" 2>/dev/null || echo 0)"
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

mkdir -p "$REPORT_DIR"

# --- Substitute today's date into prompt ---
PROMPT="$(sed "s|TODAY_PLACEHOLDER|$TODAY|g" "$PROMPT_TEMPLATE")"

# --- Mark started (commit to today only after pre-flight passes) ---
echo "$TIMESTAMP" > "$STATE_FILE"
log "starting macro-eval sweep"

# --- Invoke claude ---
# NOTE: requires the Raindrop MCP server to be reachable in this context. The
# prompt's Step 0 preflight writes a *-SKIPPED.md report and exits 0 if it isn't.
echo "$PROMPT" | SDD_HEADLESS=1 claude --print --output-format text --permission-mode bypassPermissions
EXIT=$?

log "completed exit=$EXIT"
exit $EXIT
