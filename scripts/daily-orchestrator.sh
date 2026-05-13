#!/bin/bash
# Global daily maintenance orchestrator.
# Reads ~/.claude/sdd-harness/projects.txt and dispatches each repo's
# .claude/scripts/daily-runner.sh. Per-repo failures are isolated and logged;
# the loop never aborts midway.
#
# Usage:
#   daily-orchestrator.sh             — run all repos
#   daily-orchestrator.sh --dry-run   — print what would happen
#   daily-orchestrator.sh --repo PATH — run only the given repo

set -u

HARNESS_DIR="$HOME/.claude/sdd-harness"
PROJECTS_FILE="$HARNESS_DIR/projects.txt"
LOG_FILE="$HARNESS_DIR/logs/orchestrator.log"
mkdir -p "$(dirname "$LOG_FILE")"

DRY_RUN=false
SINGLE_REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --repo)    shift; SINGLE_REPO="$1" ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

run_one() {
  local repo="$1"
  local ts="$(date -Iseconds)"

  if [ ! -d "$repo/.claude" ]; then
    echo "$ts [orphan] $repo — not installed" >> "$LOG_FILE"
    [ "$DRY_RUN" = true ] && echo "[orphan] $repo"
    return 0
  fi

  local state="$repo/.claude/memory/.last-routine-run"
  local last="never"
  [ -f "$state" ] && last="$(cat "$state")"

  if [ "$DRY_RUN" = true ]; then
    echo "[would-run] $repo (last=$last)"
    return 0
  fi

  local start=$(date +%s)
  (cd "$repo" && bash .claude/scripts/daily-runner.sh) > /dev/null 2>&1
  local exit_code=$?
  local duration=$(($(date +%s) - start))

  echo "$ts $repo exit=$exit_code duration=${duration}s" >> "$LOG_FILE"
}

if [ -n "$SINGLE_REPO" ]; then
  run_one "$SINGLE_REPO"
else
  if [ ! -f "$PROJECTS_FILE" ]; then
    echo "projects.txt missing at $PROJECTS_FILE" >&2
    exit 1
  fi
  while IFS= read -r repo; do
    [ -z "$repo" ] && continue
    [ "${repo:0:1}" = "#" ] && continue   # allow comments
    run_one "$repo"
  done < "$PROJECTS_FILE"
fi
