#!/bin/bash
# Risk-zone reseed runner — refreshes .claude/steering/risk-zones.md from
# git churn + test-file presence + gitnexus impact (when installed).
# Invoke from the repo's working directory:
#   cd <repo> && bash .claude/scripts/routines/risk-zone-reseed-runner.sh
#
# Invoked weekly by the daily orchestrator (per repo) — risk zones drift slowly,
# unlike security-report's daily cadence. MIN_GAP_DAYS=7 so it runs at most
# once a week and no-ops between runs. Downtime-tolerant. Race-safe via mkdir
# lock. Override cadence with RISK_ZONE_GAP_DAYS; force a run with
# RISK_ZONE_FORCE=1. Opt out with SDD_SKIP_RISK_ZONE=1.

set -u

REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
MEMORY_DIR=".claude/memory"
STEERING_DIR=".claude/steering"
STATE_FILE="$MEMORY_DIR/.last-risk-zone-reseed-run"
LOCK_DIR="$MEMORY_DIR/.risk-zone-reseed.lock"
PROMPT_TEMPLATE=".claude/scripts/routines/risk-zone-reseed-prompt.md"
MIN_GAP_DAYS="${RISK_ZONE_GAP_DAYS:-7}"
TIMESTAMP="$(date -Iseconds)"
TODAY="$(date +%Y-%m-%d)"

log() { echo "[$TIMESTAMP] $REPO_NAME risk-zone-reseed: $*" >&2; }

# --- Guards ---
if [ "${SDD_SKIP_RISK_ZONE:-0}" = "1" ]; then
  log "opted out (SDD_SKIP_RISK_ZONE=1), skipping"
  exit 0
fi
if [ ! -d "$MEMORY_DIR" ]; then
  log "memory-not-bootstrapped, skipping"
  exit 0
fi
if [ ! -d .git ]; then
  log "not a git repo, skipping"
  exit 0
fi
if [ ! -f "$PROMPT_TEMPLATE" ]; then
  log "prompt-template-missing ($PROMPT_TEMPLATE), skipping"
  exit 1
fi

# --- Race protection ---
if [ -d "$LOCK_DIR" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -gt 7200 ]; then
    log "removing stale lock (age=${LOCK_AGE}s)"
    rm -rf "$LOCK_DIR"
  fi
fi
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another reseed active, skipping"
  exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

# --- Cadence guard ---
if [ "${RISK_ZONE_FORCE:-0}" != "1" ] && [ -s "$STATE_FILE" ]; then
  LAST_RAW="$(cat "$STATE_FILE")"
  # fromisoformat reads the `date -Iseconds` stamp ("+02:00") on any OS. The old
  # `date -j -f ...%z` only accepts "+0200", so on macOS every parse failed, read as
  # epoch 0, and the gap guard never skipped (weekly runners ran daily; 2026-11-18).
  LAST_EPOCH="$(python3 -c 'import sys, datetime; print(int(datetime.datetime.fromisoformat(sys.argv[1]).timestamp()))' "$LAST_RAW" 2>/dev/null || echo 0)"
  if [ "$LAST_EPOCH" -gt 0 ]; then
    GAP_DAYS=$(( ($(date +%s) - LAST_EPOCH) / 86400 ))
    if [ "$GAP_DAYS" -lt "$MIN_GAP_DAYS" ]; then
      log "last reseed ${GAP_DAYS}d ago (< ${MIN_GAP_DAYS}d), skipping"
      exit 0
    fi
  fi
fi

# --- Pre-flight ---
if ! command -v claude >/dev/null 2>&1; then
  log "claude CLI not on PATH, aborting"
  exit 1
fi

mkdir -p "$STEERING_DIR"

# --- Substitute today's date into prompt ---
PROMPT="$(sed "s|TODAY_PLACEHOLDER|$TODAY|g" "$PROMPT_TEMPLATE")"

log "starting reseed"

echo "$PROMPT" | SDD_HEADLESS=1 claude --print --output-format text --permission-mode bypassPermissions \
  | tee "$MEMORY_DIR/.last-risk-zone-reseed-output.log"
EXIT=${PIPESTATUS[0]}

if [ "$EXIT" -eq 0 ]; then
  echo "$TIMESTAMP" > "$STATE_FILE"
fi

log "completed exit=$EXIT"
exit $EXIT
