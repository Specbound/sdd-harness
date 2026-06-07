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

# Self-locate the harness root (no hardcoded paths — see scripts/lib/resolve-harness-dir.sh)
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/lib/resolve-harness-dir.sh"
PROJECTS_FILE="$HARNESS_DIR/projects.txt"
LOG_FILE="$HARNESS_DIR/logs/orchestrator.log"
mkdir -p "$(dirname "$LOG_FILE")"

DRY_RUN=false
SINGLE_REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --repo)
      [ $# -lt 2 ] && { echo "--repo requires a path argument" >&2; exit 2; }
      shift
      SINGLE_REPO="$1"
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

run_one() {
  local repo="$1"
  local ts="$(date -Iseconds)"

  if [ ! -d "$repo/.claude" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "[orphan] $repo"
    else
      echo "$ts [orphan] $repo — not installed" >> "$LOG_FILE"
    fi
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

  # Macro-eval sweep — self-paces to ~twice a week via its own MIN_GAP_DAYS guard,
  # so calling it daily is cheap (it no-ops between runs). Failure-isolated; the
  # sweep's own Step-0 preflight handles an unreachable Raindrop MCP. Opt out with
  # SDD_SKIP_MACRO_EVAL=1.
  if [ "${SDD_SKIP_MACRO_EVAL:-0}" != "1" ] && [ -f "$repo/.claude/scripts/macro-eval-runner.sh" ]; then
    local me_start=$(date +%s)
    (cd "$repo" && bash .claude/scripts/macro-eval-runner.sh) > /dev/null 2>&1
    local me_exit=$?
    echo "$ts $repo macro-eval exit=$me_exit duration=$(($(date +%s) - me_start))s" >> "$LOG_FILE"
  fi

  # Skill-curator sweep — self-paces to weekly (MIN_GAP_DAYS=7). Harness-only;
  # non-harness repos exit 0 immediately. Opt out with SDD_SKIP_SKILL_CURATOR=1.
  if [ "${SDD_SKIP_SKILL_CURATOR:-0}" != "1" ] && [ -f "$repo/.claude/scripts/skill-curator-runner.sh" ]; then
    local sc_start=$(date +%s)
    (cd "$repo" && bash .claude/scripts/skill-curator-runner.sh) > /dev/null 2>&1
    local sc_exit=$?
    echo "$ts $repo skill-curator exit=$sc_exit duration=$(($(date +%s) - sc_start))s" >> "$LOG_FILE"
  fi

  # Harness-health sweep — self-paces to bi-weekly (MIN_GAP_DAYS=13). Harness-only;
  # non-harness repos exit 0 immediately. Opt out with SDD_SKIP_HARNESS_HEALTH=1.
  if [ "${SDD_SKIP_HARNESS_HEALTH:-0}" != "1" ] && [ -f "$repo/.claude/scripts/harness-health-runner.sh" ]; then
    local hh_start=$(date +%s)
    (cd "$repo" && bash .claude/scripts/harness-health-runner.sh) > /dev/null 2>&1
    local hh_exit=$?
    echo "$ts $repo harness-health exit=$hh_exit duration=$(($(date +%s) - hh_start))s" >> "$LOG_FILE"
  fi

  # Tool-failure review — promotes recurring Bash/MCP failures into memory so the
  # system learns from its mistakes. Self-paces to ~twice a week (MIN_GAP_DAYS=3)
  # and no-ops unless the ledger has a promotable entry, so calling it daily is
  # cheap. Applies to every repo. Opt out with SDD_SKIP_TOOL_FAILURE_REVIEW=1.
  if [ "${SDD_SKIP_TOOL_FAILURE_REVIEW:-0}" != "1" ] && [ -f "$repo/.claude/scripts/tool-failure-review-runner.sh" ]; then
    local tf_start=$(date +%s)
    (cd "$repo" && bash .claude/scripts/tool-failure-review-runner.sh) > /dev/null 2>&1
    local tf_exit=$?
    echo "$ts $repo tool-failure-review exit=$tf_exit duration=$(($(date +%s) - tf_start))s" >> "$LOG_FILE"
  fi

  # Security report — daily static security scan of recent git changes. Writes a
  # safety report to .claude/reports/security/<date>-security-report.md. Self-paces
  # to daily (MIN_GAP_DAYS=1). Applies to every repo.
  # Opt out with SDD_SKIP_SECURITY_REPORT=1.
  if [ "${SDD_SKIP_SECURITY_REPORT:-0}" != "1" ] && [ -f "$repo/.claude/scripts/security-report-runner.sh" ]; then
    local sr_start=$(date +%s)
    (cd "$repo" && bash .claude/scripts/security-report-runner.sh) > /dev/null 2>&1
    local sr_exit=$?
    echo "$ts $repo security-report exit=$sr_exit duration=$(($(date +%s) - sr_start))s" >> "$LOG_FILE"
  fi
}

if [ -n "$SINGLE_REPO" ]; then
  run_one "$SINGLE_REPO"
else
  if [ ! -f "$PROJECTS_FILE" ]; then
    echo "projects.txt missing at $PROJECTS_FILE" >&2
    exit 1
  fi
  while IFS= read -r repo || [ -n "$repo" ]; do
    [ -z "$repo" ] && continue
    [ "${repo:0:1}" = "#" ] && continue   # allow comments
    run_one "$repo"
  done < "$PROJECTS_FILE"
fi

# --- Harness-level weekly tasks ---
# Wednesday (DOW=3): repo drift review
DRIFT_STATE="$HARNESS_DIR/.last-drift-review"
DRIFT_WEEK="$(date +%Y-W%V)"
DOW="$(date +%u)"

if [ "$DOW" = "3" ] && [ "$DRY_RUN" = false ]; then
  LAST_DRIFT_WEEK="$(cat "$DRIFT_STATE" 2>/dev/null || echo "")"
  if [ "$LAST_DRIFT_WEEK" != "$DRIFT_WEEK" ]; then
    ts="$(date -Iseconds)"
    echo "$ts harness: starting drift review ($DRIFT_WEEK)" >> "$LOG_FILE"
    echo "$DRIFT_WEEK" > "$DRIFT_STATE"
    echo "Use the repo-drift-review skill to sweep the SDD harness for drift. Auto-fix what you can. Write the summary to $HARNESS_DIR/docs/drift-review-report.md" | \
      claude --print --output-format text --permission-mode bypassPermissions > /dev/null 2>&1
    echo "$ts harness: drift review exit=$?" >> "$LOG_FILE"
  fi
fi
