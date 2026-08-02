#!/bin/bash
# Global daily maintenance orchestrator.
# Reads ~/.claude/sdd-harness/projects.txt and dispatches each repo's
# .claude/scripts/orchestration/daily-runner.sh. Per-repo failures are isolated and logged;
# the loop never aborts midway.
#
# Usage:
#   daily-orchestrator.sh             — run all repos
#   daily-orchestrator.sh --dry-run   — print what would happen
#   daily-orchestrator.sh --repo PATH — run only the given repo

set -u

# Self-locate the harness root (no hardcoded paths — see scripts/lib/resolve-harness-dir.sh)
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/../lib/resolve-harness-dir.sh"
PROJECTS_FILE="$HARNESS_DIR/projects.txt"
LOG_FILE="$HARNESS_DIR/logs/orchestrator.log"
ERR_LOG="$HARNESS_DIR/logs/orchestrator-errors.log"
mkdir -p "$(dirname "$LOG_FILE")"

DRY_RUN=false
SINGLE_REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --repo)
      [ $# -lt 2 ] && { echo "--repo requires a path argument" >&2; echo "$(date -Iseconds) orchestrator: --repo requires a path argument" >> "$ERR_LOG"; exit 2; }
      shift
      SINGLE_REPO="$1"
      ;;
    *) echo "unknown arg: $1" >&2; echo "$(date -Iseconds) orchestrator: unknown arg: $1" >> "$ERR_LOG"; exit 2 ;;
  esac
  shift
done

# --- Fail-loud instrumentation ---
# A run that dies before the repo loop (bad env, resolve-harness-dir.sh failure,
# missing projects.txt) must never look identical to a zero-work success. Every
# real invocation logs a start line and, via the EXIT trap, an end line — so a
# silent zero-byte run becomes structurally visible (either both lines appear,
# or the crash happened before the trap installed, which the ERR_LOG catches
# below).
PROCESSED=0
if [ "$DRY_RUN" = false ]; then
  MODE="${SINGLE_REPO:+repo:$SINGLE_REPO}"
  MODE="${MODE:-fleet}"
  echo "$(date -Iseconds) orchestrator: run started (mode=$MODE)" >> "$LOG_FILE"
  trap '__ec=$?; echo "$(date -Iseconds) orchestrator: run finished exit=$__ec repos=$PROCESSED" >> "$LOG_FILE"' EXIT
fi

run_one() {
  local repo="$1"
  local ts="$(date -Iseconds)"

  [ "$DRY_RUN" = false ] && PROCESSED=$((PROCESSED + 1))

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

  # Only call daily-runner.sh if it hasn't run today — avoids "exit 0 · 0s" audit
  # clutter when session-start hook already fired it earlier. Sub-runners below still
  # execute on their own schedules regardless.
  local today="$(date +%Y-%m-%d)"
  local last_day="$(cut -dT -f1 "$state" 2>/dev/null || echo "")"
  if [ "$last_day" != "$today" ]; then
    local start=$(date +%s)
    local dm_errbuf; dm_errbuf=$(mktemp)
    (cd "$repo" && bash .claude/scripts/orchestration/daily-runner.sh) > /dev/null 2>"$dm_errbuf"
    local exit_code=$?
    local duration=$(($(date +%s) - start))
    echo "$ts $repo exit=$exit_code duration=${duration}s" >> "$LOG_FILE"
    if [ "$exit_code" -ne 0 ] && [ -s "$dm_errbuf" ]; then
      { echo "--- $ts $repo daily-maintenance (exit=$exit_code) ---"; cat "$dm_errbuf"; } >> "$ERR_LOG"
    fi
    rm -f "$dm_errbuf"
  fi

  # Macro-eval sweep — self-paces to ~twice a week via its own MIN_GAP_DAYS guard,
  # so calling it daily is cheap (it no-ops between runs). Failure-isolated; the
  # sweep's own Step-0 preflight handles an unreachable Raindrop MCP. Opt out with
  # SDD_SKIP_MACRO_EVAL=1.
  if [ "${SDD_SKIP_MACRO_EVAL:-0}" != "1" ] && [ -f "$repo/.claude/scripts/routines/macro-eval-runner.sh" ]; then
    local me_start=$(date +%s)
    local me_errbuf; me_errbuf=$(mktemp)
    (cd "$repo" && bash .claude/scripts/routines/macro-eval-runner.sh) > /dev/null 2>"$me_errbuf"
    local me_exit=$?
    echo "$ts $repo macro-eval exit=$me_exit duration=$(($(date +%s) - me_start))s" >> "$LOG_FILE"
    if [ "$me_exit" -ne 0 ] && [ -s "$me_errbuf" ]; then
      { echo "--- $ts $repo macro-eval (exit=$me_exit) ---"; cat "$me_errbuf"; } >> "$ERR_LOG"
    fi
    rm -f "$me_errbuf"
  fi

  # Skill-curator sweep — self-paces to weekly (MIN_GAP_DAYS=7). Harness-only;
  # non-harness repos exit 0 immediately. Opt out with SDD_SKIP_SKILL_CURATOR=1.
  if [ "${SDD_SKIP_SKILL_CURATOR:-0}" != "1" ] && [ -f "$repo/.claude/scripts/routines/skill-curator-runner.sh" ]; then
    local sc_start=$(date +%s)
    local sc_errbuf; sc_errbuf=$(mktemp)
    (cd "$repo" && bash .claude/scripts/routines/skill-curator-runner.sh) > /dev/null 2>"$sc_errbuf"
    local sc_exit=$?
    echo "$ts $repo skill-curator exit=$sc_exit duration=$(($(date +%s) - sc_start))s" >> "$LOG_FILE"
    if [ "$sc_exit" -ne 0 ] && [ -s "$sc_errbuf" ]; then
      { echo "--- $ts $repo skill-curator (exit=$sc_exit) ---"; cat "$sc_errbuf"; } >> "$ERR_LOG"
    fi
    rm -f "$sc_errbuf"
  fi

  # Harness-health sweep — self-paces to bi-weekly (MIN_GAP_DAYS=13). Harness-only;
  # non-harness repos exit 0 immediately. Opt out with SDD_SKIP_HARNESS_HEALTH=1.
  if [ "${SDD_SKIP_HARNESS_HEALTH:-0}" != "1" ] && [ -f "$repo/.claude/scripts/routines/harness-health-runner.sh" ]; then
    local hh_start=$(date +%s)
    local hh_errbuf; hh_errbuf=$(mktemp)
    (cd "$repo" && bash .claude/scripts/routines/harness-health-runner.sh) > /dev/null 2>"$hh_errbuf"
    local hh_exit=$?
    echo "$ts $repo harness-health exit=$hh_exit duration=$(($(date +%s) - hh_start))s" >> "$LOG_FILE"
    if [ "$hh_exit" -ne 0 ] && [ -s "$hh_errbuf" ]; then
      { echo "--- $ts $repo harness-health (exit=$hh_exit) ---"; cat "$hh_errbuf"; } >> "$ERR_LOG"
    fi
    rm -f "$hh_errbuf"
  fi

  # Tool-failure review — promotes recurring Bash/MCP failures into memory so the
  # system learns from its mistakes. Self-paces to ~twice a week (MIN_GAP_DAYS=3)
  # and no-ops unless the ledger has a promotable entry, so calling it daily is
  # cheap. Applies to every repo. Opt out with SDD_SKIP_TOOL_FAILURE_REVIEW=1.
  if [ "${SDD_SKIP_TOOL_FAILURE_REVIEW:-0}" != "1" ] && [ -f "$repo/.claude/scripts/routines/tool-failure-review-runner.sh" ]; then
    local tf_start=$(date +%s)
    local tf_errbuf; tf_errbuf=$(mktemp)
    (cd "$repo" && bash .claude/scripts/routines/tool-failure-review-runner.sh) > /dev/null 2>"$tf_errbuf"
    local tf_exit=$?
    echo "$ts $repo tool-failure-review exit=$tf_exit duration=$(($(date +%s) - tf_start))s" >> "$LOG_FILE"
    if [ "$tf_exit" -ne 0 ] && [ -s "$tf_errbuf" ]; then
      { echo "--- $ts $repo tool-failure-review (exit=$tf_exit) ---"; cat "$tf_errbuf"; } >> "$ERR_LOG"
    fi
    rm -f "$tf_errbuf"
  fi

  # Code-review learning sweep — compares pr-babysit's logged reviews against real
  # human review activity on merged PRs, promotes low-risk findings into memory, and
  # reports higher-risk methodology changes for human approval. Cheaply no-ops unless
  # there's a merged+logged PR not yet processed; self-paces to weekly (MIN_GAP_DAYS=7)
  # once there is. Applies to any repo. Opt out with SDD_SKIP_CODE_REVIEW_LEARNING=1.
  if [ "${SDD_SKIP_CODE_REVIEW_LEARNING:-0}" != "1" ] && [ -f "$repo/.claude/scripts/routines/code-review-learning-runner.sh" ]; then
    local crl_start=$(date +%s)
    local crl_errbuf; crl_errbuf=$(mktemp)
    (cd "$repo" && bash .claude/scripts/routines/code-review-learning-runner.sh) > /dev/null 2>"$crl_errbuf"
    local crl_exit=$?
    echo "$ts $repo code-review-learning exit=$crl_exit duration=$(($(date +%s) - crl_start))s" >> "$LOG_FILE"
    if [ "$crl_exit" -ne 0 ] && [ -s "$crl_errbuf" ]; then
      { echo "--- $ts $repo code-review-learning (exit=$crl_exit) ---"; cat "$crl_errbuf"; } >> "$ERR_LOG"
    fi
    rm -f "$crl_errbuf"
  fi

  # Security report — daily static security scan of recent git changes. Writes a
  # safety report to .claude/reports/security/<date>-security-report.md. Self-paces
  # to daily (MIN_GAP_DAYS=1). Applies to every repo.
  # Opt out with SDD_SKIP_SECURITY_REPORT=1.
  if [ "${SDD_SKIP_SECURITY_REPORT:-0}" != "1" ] && [ -f "$repo/.claude/scripts/routines/security-report-runner.sh" ]; then
    local sr_start=$(date +%s)
    local sr_errbuf; sr_errbuf=$(mktemp)
    (cd "$repo" && bash .claude/scripts/routines/security-report-runner.sh) > /dev/null 2>"$sr_errbuf"
    local sr_exit=$?
    echo "$ts $repo security-report exit=$sr_exit duration=$(($(date +%s) - sr_start))s" >> "$LOG_FILE"
    if [ "$sr_exit" -ne 0 ] && [ -s "$sr_errbuf" ]; then
      { echo "--- $ts $repo security-report (exit=$sr_exit) ---"; cat "$sr_errbuf"; } >> "$ERR_LOG"
    fi
    rm -f "$sr_errbuf"
  fi

  # Startup-payload audit — deterministic (no LLM). Measures the fixed per-session
  # token tax (CLAUDE.md + @imports + .claude/rules + auto-loaded MEMORY.md) that
  # RTK/lean-ctx/Headroom don't cover, and writes a JSON the dashboard's Context Health
  # tab reads. Self-paces to daily via its own state-file guard, so calling it daily is
  # cheap. Applies to every repo. Opt out with SDD_SKIP_STARTUP_AUDIT=1.
  if [ "${SDD_SKIP_STARTUP_AUDIT:-0}" != "1" ] && [ -f "$repo/.claude/scripts/routines/startup-payload-audit.sh" ]; then
    local sp_start=$(date +%s)
    local sp_errbuf; sp_errbuf=$(mktemp)
    (cd "$repo" && bash .claude/scripts/routines/startup-payload-audit.sh) > /dev/null 2>"$sp_errbuf"
    local sp_exit=$?
    echo "$ts $repo startup-payload exit=$sp_exit duration=$(($(date +%s) - sp_start))s" >> "$LOG_FILE"
    if [ "$sp_exit" -ne 0 ] && [ -s "$sp_errbuf" ]; then
      { echo "--- $ts $repo startup-payload (exit=$sp_exit) ---"; cat "$sp_errbuf"; } >> "$ERR_LOG"
    fi
    rm -f "$sp_errbuf"
  fi
}

if [ -n "$SINGLE_REPO" ]; then
  run_one "$SINGLE_REPO"
else
  if [ ! -f "$PROJECTS_FILE" ]; then
    echo "projects.txt missing at $PROJECTS_FILE" >&2
    echo "$(date -Iseconds) orchestrator: projects.txt missing at $PROJECTS_FILE" >> "$ERR_LOG"
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
    drift_errbuf=$(mktemp)
    echo "Use the repo-drift-review skill to sweep the SDD harness for drift. Auto-fix what you can. Write the summary to $HARNESS_DIR/docs/drift-review-report.md" | \
      claude --print --output-format text --permission-mode bypassPermissions > /dev/null 2>"$drift_errbuf"
    drift_exit=$?
    echo "$ts harness: drift review exit=$drift_exit" >> "$LOG_FILE"
    if [ "$drift_exit" -ne 0 ] && [ -s "$drift_errbuf" ]; then
      { echo "--- $ts harness drift-review (exit=$drift_exit) ---"; cat "$drift_errbuf"; } >> "$ERR_LOG"
    fi
    rm -f "$drift_errbuf"
  fi
fi
