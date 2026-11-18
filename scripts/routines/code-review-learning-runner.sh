#!/bin/bash
# Self-improving code-review learning runner — learns from review activity on every
# recently merged PR: what reviewers (human or bot) raised, and how it was resolved. When
# pr-babysit also logged a review for the PR, that log is compared against the reviewers
# too. Low-risk findings go to memory; higher-risk methodology changes are reported for
# human approval.
# Invoke from the repo's working directory:
#   cd <repo> && bash .claude/scripts/routines/code-review-learning-runner.sh
#
# Invoked once per day by the daily orchestrator (per repo). Cheaply no-ops unless a
# PR merged in the last CODE_REVIEW_LEARNING_LOOKBACK_DAYS has review activity from
# someone other than its author and has not been processed. PRs with none are settled
# without an LLM run. At most CODE_REVIEW_LEARNING_MAX_PRS go to one sweep; the rest
# wait for the next. Self-paces to weekly (MIN_GAP_DAYS=7) once there IS something.
# Race-safe via mkdir lock (portable; flock is Linux-only). Applies to any repo with
# a pr-reviews log, not just the harness. Override cadence with
# CODE_REVIEW_LEARNING_GAP_DAYS; force a run with CODE_REVIEW_LEARNING_FORCE=1.
# Opt out with SDD_SKIP_CODE_REVIEW_LEARNING=1 (checked by the caller, not here).

set -u

REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
MEMORY_DIR=".claude/memory"
REVIEW_DIR="$MEMORY_DIR/pr-reviews"
PROCESSED_LEDGER="$MEMORY_DIR/.code-review-learning-processed"
PROMPT_TEMPLATE=".claude/scripts/routines/code-review-learning-prompt.md"
STATE_FILE="$MEMORY_DIR/.last-code-review-learning-run"
LOCK_DIR="$MEMORY_DIR/.code-review-learning.lock"
MIN_GAP_DAYS="${CODE_REVIEW_LEARNING_GAP_DAYS:-7}"
MAX_PRS="${CODE_REVIEW_LEARNING_MAX_PRS:-10}"
LOOKBACK_DAYS="${CODE_REVIEW_LEARNING_LOOKBACK_DAYS:-90}"
TIMESTAMP="$(date -Iseconds)"
TODAY="$(date +%Y-%m-%d)"

log() { echo "[$TIMESTAMP] $REPO_NAME code-review-learning: $*" >&2; }
# Record why a guard no-opped so the dashboard can tell "idle" from "never fired".
SKIP_FILE="$MEMORY_DIR/.skip-reason-code-review-learning"
skip() {
  printf '%s|%s\n' "$TIMESTAMP" "${1%, skipping}" > "$SKIP_FILE" 2>/dev/null
  log "$1"
  exit 0
}

# --- Guards ---
if [ ! -d "$MEMORY_DIR" ]; then
  skip "memory-not-bootstrapped, skipping"
fi
if [ ! -f "$PROMPT_TEMPLATE" ]; then
  skip "prompt template missing ($PROMPT_TEMPLATE), skipping"
fi
if ! command -v gh >/dev/null 2>&1; then
  skip "gh CLI not found, skipping"
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  skip "not a git repo, skipping"
fi

# --- Discover PRs to learn from: recently merged, not yet processed ---
# A pr-babysit review log is optional context, not a precondition: PRs opened by hand,
# from the web UI or via `gh` never get one, and the sweep still has to learn from them.
# Output lines: PR|<n>|<1 if a babysit log exists> · NOSIGNAL|<n> · ERROR|<message>
DISCOVERY="$(REVIEW_DIR="$REVIEW_DIR" PROCESSED_LEDGER="$PROCESSED_LEDGER" MAX_PRS="$MAX_PRS" LOOKBACK_DAYS="$LOOKBACK_DAYS" python3 - <<'PY' 2>&1
import json, os, subprocess, sys
from datetime import datetime, timedelta, timezone

review_dir = os.environ["REVIEW_DIR"]
ledger_path = os.environ["PROCESSED_LEDGER"]
max_prs = int(os.environ["MAX_PRS"])
cutoff = datetime.now(timezone.utc) - timedelta(days=int(os.environ["LOOKBACK_DAYS"]))
GH_FAILURES = (RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError)


def gh_json(args):
    out = subprocess.run(["gh", *args], capture_output=True, text=True, timeout=30)
    if out.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:2])}: {out.stderr.strip()[:120]}")
    return json.loads(out.stdout)


def merged_at(pr):
    return datetime.fromisoformat(pr["mergedAt"].replace("Z", "+00:00"))


def has_outside_signal(pr):
    """True if someone other than the PR's author reviewed it or discussed it.

    Inline comments and reviews count from anyone (a bot review is a review). Plain
    conversation comments count only from humans: bots post deploy previews and CI
    status there, which is noise, not review.
    """
    n = pr["number"]
    author = (pr.get("author") or {}).get("login")
    for endpoint, bots_count in (("pulls/%d/comments", True), ("pulls/%d/reviews", True),
                                 ("issues/%d/comments", False)):
        items = gh_json(["api", "repos/{owner}/{repo}/" + (endpoint % n) + "?per_page=100"])
        for item in items:
            user = item.get("user") or {}
            if item.get("state") == "PENDING" or user.get("login") == author:
                continue
            if bots_count or user.get("type") != "Bot":
                return True
    return False


processed = set()
if os.path.isfile(ledger_path):
    with open(ledger_path) as f:
        processed = {line.strip() for line in f if line.strip()}

try:
    merged = gh_json(["pr", "list", "--state", "merged", "--limit", "100",
                      "--json", "number,mergedAt,author"])
except GH_FAILURES as exc:
    print(f"ERROR|{exc}")
    sys.exit(0)

recent = sorted((pr for pr in merged
                 if str(pr["number"]) not in processed and merged_at(pr) >= cutoff),
                key=merged_at, reverse=True)

picked = 0
for pr in recent:
    if picked >= max_prs:
        break
    try:
        signal = has_outside_signal(pr)
    except GH_FAILURES as exc:
        print(f"ERROR|PR #{pr['number']}: {exc}")  # left unprocessed — retried next sweep
        continue
    if signal:
        logged = os.path.isfile(os.path.join(review_dir, f"pr-{pr['number']}.md"))
        print(f"PR|{pr['number']}|{1 if logged else 0}")
        picked += 1
    else:
        print(f"NOSIGNAL|{pr['number']}")
PY
)"

DISCOVERY_RC=$?
PROMOTABLE_PRS=""; LOGGED_PRS=""; NOSIGNAL_PRS=""; DISCOVERY_ERROR=""
while IFS='|' read -r KIND PR_N LOGGED_FLAG; do
  case "$KIND" in
    ERROR)    DISCOVERY_ERROR="$PR_N${LOGGED_FLAG:+|$LOGGED_FLAG}" ;;
    NOSIGNAL) NOSIGNAL_PRS="$NOSIGNAL_PRS $PR_N" ;;
    PR)       PROMOTABLE_PRS="${PROMOTABLE_PRS:+$PROMOTABLE_PRS,}$PR_N"
              if [ "$LOGGED_FLAG" = "1" ]; then LOGGED_PRS="${LOGGED_PRS:+$LOGGED_PRS,}$PR_N"; fi ;;
  esac
done <<< "$DISCOVERY"

# PRs nobody but their author touched have nothing to learn from — settle them now,
# without an LLM run, so they are not re-scanned every day.
for N in $NOSIGNAL_PRS; do echo "$N" >> "$PROCESSED_LEDGER"; done

if [ -z "$PROMOTABLE_PRS" ]; then
  if [ "$DISCOVERY_RC" -ne 0 ]; then
    skip "PR discovery script crashed (exit $DISCOVERY_RC), skipping"
  fi
  if [ -n "$DISCOVERY_ERROR" ]; then
    skip "PR discovery failed: $DISCOVERY_ERROR, skipping"
  fi
  skip "no merged PRs (last ${LOOKBACK_DAYS}d) with outside review activity, skipping"
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
  skip "another sweep active, skipping"
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

# --- Cadence guard: skip if last run was < MIN_GAP_DAYS ago (unless forced) ---
if [ "${CODE_REVIEW_LEARNING_FORCE:-0}" != "1" ] && [ -s "$STATE_FILE" ]; then
  LAST_RAW="$(cat "$STATE_FILE")"
  # fromisoformat reads the `date -Iseconds` stamp ("+02:00") on any OS. The old
  # `date -j -f ...%z` only accepts "+0200", so on macOS every parse failed, read as
  # epoch 0, and the gap guard never skipped (weekly runners ran daily; 2026-11-18).
  LAST_EPOCH="$(python3 -c 'import sys, datetime; print(int(datetime.datetime.fromisoformat(sys.argv[1]).timestamp()))' "$LAST_RAW" 2>/dev/null || echo 0)"
  if [ "$LAST_EPOCH" -gt 0 ]; then
    GAP_DAYS=$(( ($(date +%s) - LAST_EPOCH) / 86400 ))
    if [ "$GAP_DAYS" -lt "$MIN_GAP_DAYS" ]; then
      skip "last sweep ${GAP_DAYS}d ago (< ${MIN_GAP_DAYS}d), skipping"
    fi
  fi
fi

# --- Pre-flight: claude CLI must be available ---
if ! command -v claude >/dev/null 2>&1; then
  log "claude CLI not on PATH, aborting"
  exit 1
fi

# --- Substitute placeholders into prompt ---
PROMPT="$(sed -e "s|TODAY_PLACEHOLDER|$TODAY|g" -e "s|PROMOTABLE_PRS_PLACEHOLDER|$PROMOTABLE_PRS|g" -e "s|LOGGED_PRS_PLACEHOLDER|${LOGGED_PRS:-none}|g" "$PROMPT_TEMPLATE")"

# --- Mark started ---
echo "$TIMESTAMP" > "$STATE_FILE"
rm -f "$SKIP_FILE"
log "starting sweep (PRs: $PROMOTABLE_PRS)"

# --- Invoke claude ---
echo "$PROMPT" | SDD_HEADLESS=1 claude --print --output-format text --permission-mode bypassPermissions
EXIT=$?

if [ "$EXIT" -eq 0 ]; then
  printf '%s\n' "${PROMOTABLE_PRS//,/$'\n'}" >> "$PROCESSED_LEDGER"
fi

log "completed exit=$EXIT"
exit $EXIT
