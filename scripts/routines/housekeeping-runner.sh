#!/bin/bash
# Housekeeping runner — weekly memory housekeeping for active repos.
# Invoke from the repo's working directory:
#   cd <repo> && bash .claude/scripts/routines/housekeeping-runner.sh
#
# Why it exists: the nightly routine's housekeeping step only archives
# observations.md past 50 entries. Nothing ever pruned hot-memory.md or checked
# its entries for staleness, so in two repos it grew past 11KB — beyond what
# prompt-hook.sh can inject — with long-resolved priorities still in it
# (2026-11-18). This runs the full /kiro:housekeeping (prune, archive, cap
# checks, staleness) once a week.
#
# Invoked once per day by the daily orchestrator (per repo); self-paces to weekly
# (HOUSEKEEPING_GAP_DAYS, default 7). Runs only in an ACTIVE repo, decided from
# the repo itself, never from a list:
#   * a commit in the last HOUSEKEEPING_ACTIVE_DAYS (default 14), or
#   * an interactive Claude Code session in that window — transcripts whose
#     `entrypoint` is "sdk-cli" are headless `claude --print` runs (this repo's own
#     routines write one every night) and do not count, or every repo reads active, or
#   * hot-memory.md already over its byte cap (HOUSEKEEPING_HOT_MAX_BYTES, 8000) —
#     an over-cap file is cut on every injection, active or not.
# The "last run" stamp is written only on success, so a failed run (routine
# outages are common) retries the next day instead of a week later.
# Force with HOUSEKEEPING_FORCE=1. Opt out at the orchestrator: SDD_SKIP_HOUSEKEEPING=1.
# Race-safe via mkdir lock (portable; flock is Linux-only).

set -u

REPO_DIR="$(pwd -P)"
REPO_NAME="$(basename "$REPO_DIR")"
MEMORY_DIR=".claude/memory"
COMMAND_FILE=".claude/commands/kiro/housekeeping.md"
HOT_MEMORY="$MEMORY_DIR/hot-memory.md"
STATE_FILE="$MEMORY_DIR/.last-housekeeping"
LOCK_DIR="$MEMORY_DIR/.housekeeping.lock"
MIN_GAP_DAYS="${HOUSEKEEPING_GAP_DAYS:-7}"
ACTIVE_DAYS="${HOUSEKEEPING_ACTIVE_DAYS:-14}"
HOT_MAX_BYTES="${HOUSEKEEPING_HOT_MAX_BYTES:-8000}"
CLAUDE_PROJECTS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
TIMESTAMP="$(date -Iseconds)"
TODAY="$(date +%Y-%m-%d)"

log() { echo "[$TIMESTAMP] $REPO_NAME housekeeping: $*" >&2; }

# --- Guards ---
if [ ! -d "$MEMORY_DIR" ]; then
  log "memory-not-bootstrapped, skipping"
  exit 0
fi
if [ ! -f "$COMMAND_FILE" ]; then
  log "command file missing ($COMMAND_FILE), skipping"
  exit 0
fi

# --- Cadence guard: skip if the last successful run was < MIN_GAP_DAYS ago ---
if [ "${HOUSEKEEPING_FORCE:-0}" != "1" ] && [ -s "$STATE_FILE" ]; then
  LAST_RAW="$(cat "$STATE_FILE")"
  # fromisoformat reads the `date -Iseconds` stamp ("+02:00") on any OS. The old
  # `date -j -f ...%z` only accepts "+0200", so on macOS every parse failed, read as
  # epoch 0, and the gap guard never skipped (weekly runners ran daily; 2026-11-18).
  LAST_EPOCH="$(python3 -c 'import sys, datetime; print(int(datetime.datetime.fromisoformat(sys.argv[1]).timestamp()))' "$LAST_RAW" 2>/dev/null || echo 0)"
  if [ "$LAST_EPOCH" -gt 0 ]; then
    GAP_DAYS=$(( ($(date +%s) - LAST_EPOCH) / 86400 ))
    if [ "$GAP_DAYS" -lt "$MIN_GAP_DAYS" ]; then
      log "last run ${GAP_DAYS}d ago (< ${MIN_GAP_DAYS}d), skipping"
      exit 0
    fi
  fi
fi

# --- Activity guard: why this repo needs housekeeping now (empty = it doesn't) ---
REASON="$(REPO_DIR="$REPO_DIR" HOT_MEMORY="$HOT_MEMORY" HOT_MAX_BYTES="$HOT_MAX_BYTES" \
  ACTIVE_DAYS="$ACTIVE_DAYS" CLAUDE_PROJECTS_DIR="$CLAUDE_PROJECTS_DIR" python3 - <<'PY' 2>/dev/null
import os, subprocess, time
from pathlib import Path

repo = os.environ["REPO_DIR"]
days = int(os.environ["ACTIVE_DAYS"])
cutoff = time.time() - days * 86400

hot = Path(repo) / os.environ["HOT_MEMORY"]
cap = int(os.environ["HOT_MAX_BYTES"])
if hot.is_file() and hot.stat().st_size > cap:
    print(f"hot-memory {hot.stat().st_size} bytes > {cap} cap")
    raise SystemExit

r = subprocess.run(["git", "-C", repo, "log", f"--since={days}.days", "-1", "--format=%h"],
                   capture_output=True, text=True)
if r.returncode == 0 and r.stdout.strip():
    print(f"commit {r.stdout.strip()} within {days}d")
    raise SystemExit

# Claude Code names the transcript dir after the repo path, with every
# non-alphanumeric character replaced by "-". (No apostrophes in this heredoc:
# bash 3.2 still scans for quotes inside $( ... <<'PY' ) and fails to parse.)
slug = "".join(c if c.isalnum() or c == "-" else "-" for c in repo)
tdir = Path(os.environ["CLAUDE_PROJECTS_DIR"]) / slug
def interactive(path):
    # "sdk-cli" marks a headless claude --print run. Anything else, including a
    # transcript with no entrypoint field, counts: an extra weekly housekeeping
    # costs less than memory going stale unseen.
    import json
    with path.open(errors="replace") as fh:
        for i, line in enumerate(fh):
            if i > 40:
                break
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if "entrypoint" in rec:
                return rec["entrypoint"] != "sdk-cli"
    return True

if tdir.is_dir() and any(f.stat().st_mtime >= cutoff and interactive(f) for f in tdir.glob("*.jsonl")):
    print(f"interactive Claude session within {days}d")
PY
)"
if [ "${HOUSEKEEPING_FORCE:-0}" != "1" ] && [ -z "$REASON" ]; then
  log "inactive (no commit or session in ${ACTIVE_DAYS}d, hot-memory within cap), skipping"
  exit 0
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
  log "another housekeeping run active, skipping"
  exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

# --- Pre-flight: claude CLI must be available ---
if ! command -v claude >/dev/null 2>&1; then
  log "claude CLI not on PATH, aborting"
  exit 1
fi

log "starting (${REASON:-forced})"

PROMPT="Read and follow the instructions in $COMMAND_FILE to run memory housekeeping for this repository ($REPO_DIR) only. Enforce every cap, including hot-memory.md under 50 lines AND under $HOT_MAX_BYTES bytes. Verify each hot-memory entry is still current against this repo (git log, file existence, specs/) before keeping it; archive rather than delete. Do not commit. Today is $TODAY."

echo "$PROMPT" | SDD_HEADLESS=1 claude --print --output-format text --permission-mode bypassPermissions
EXIT=$?

if [ "$EXIT" -eq 0 ]; then
  echo "$TIMESTAMP" > "$STATE_FILE"
fi
log "completed exit=$EXIT"
exit $EXIT
