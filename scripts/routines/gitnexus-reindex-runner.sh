#!/bin/bash
# gitnexus-reindex-runner.sh — weekly GitNexus catch-up reindex for indexed repos.
#
# Deterministic (no LLM call). The post-commit hook reindexes on every commit, but
# only in worktrees with hooks.autopilot.enabled, and only when gitnexus/npx is on
# PATH — which it is not under launchd (node comes from mise shims, activated by
# interactive shells only). So indexes drift behind HEAD silently. This runner
# closes that gap once a week.
#
# Applies only to repos that already have .gitnexus/ (never creates an index —
# that is /kiro:gitnexus-setup's job). Skips the analyze when .gitnexus/meta.json
# lastCommit already equals HEAD. Self-paces to weekly via a state-file guard, so
# calling it daily from the orchestrator is a cheap no-op between runs.
#
# Usage:
#   gitnexus-reindex-runner.sh            — current repo (cwd), respecting cadence
#   gitnexus-reindex-runner.sh --force    — ignore cadence guard, run now
# Env:
#   SDD_SKIP_GITNEXUS_REINDEX=1           — opt out entirely
#   GITNEXUS_REINDEX_GAP_DAYS=<days>      — cadence override (default 7)
#   GITNEXUS_BIN=<path>                   — gitnexus executable override

set -u

[ "${SDD_SKIP_GITNEXUS_REINDEX:-0}" = "1" ] && exit 0

REPO="$(pwd)"
FORCE=false
[ "${1:-}" = "--force" ] && FORCE=true

[ -d "$REPO/.claude" ] || exit 0
[ -f "$REPO/.gitnexus/meta.json" ] || exit 0

MIN_GAP_DAYS="${GITNEXUS_REINDEX_GAP_DAYS:-7}"
STATE_FILE="$REPO/.claude/memory/.last-gitnexus-reindex"

if [ "$FORCE" = false ] && [ -f "$STATE_FILE" ]; then
  last_day="$(cut -dT -f1 "$STATE_FILE" 2>/dev/null | head -1)"
  if [ -n "$last_day" ]; then
    gap="$(python3 -c "
import datetime
print((datetime.date.today() - datetime.date.fromisoformat('$last_day')).days)
" 2>/dev/null || echo "")"
    if [ -n "$gap" ] && [ "$gap" -lt "$MIN_GAP_DAYS" ] 2>/dev/null; then
      exit 0
    fi
  fi
fi

command -v python3 >/dev/null 2>&1 || { echo "gitnexus-reindex: python3 not found" >&2; exit 1; }

head_sha="$(git -C "$REPO" rev-parse HEAD 2>/dev/null)" || { echo "gitnexus-reindex: $REPO is not a git repo" >&2; exit 1; }
indexed_sha="$(python3 -c "
import json, sys
print(json.load(open(sys.argv[1])).get('lastCommit', ''))
" "$REPO/.gitnexus/meta.json" 2>/dev/null || echo "")"

if [ "$indexed_sha" = "$head_sha" ]; then
  date -Iseconds > "$STATE_FILE"
  exit 0
fi

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$SCRIPT_DIR/../lib/tool-paths.sh"

BIN="${GITNEXUS_BIN:-}"
[ -n "$BIN" ] || BIN="$(find_tool gitnexus 2>/dev/null || true)"
if [ -z "$BIN" ]; then
  cand="$(mise_shims_dir)/gitnexus"
  [ -x "$cand" ] && BIN="$cand"
fi
[ -n "$BIN" ] || { echo "gitnexus-reindex: gitnexus not found on PATH, tool dirs, or mise shims" >&2; exit 1; }

# Not stamped on failure: tomorrow's tick retries. --index-only: a plain analyze
# rewrites the gitnexus block in CLAUDE.md/AGENTS.md (undoing gitnexus-reconcile.sh's
# compact block) and the installed gitnexus skills, dirtying every repo weekly.
# No embedding flag: since gitnexus 1.6 embeddings are off by default and existing
# ones are preserved (the old --skip-embeddings is now an unknown option).
errbuf="$(mktemp)"
if ! (cd "$REPO" && "$BIN" analyze --index-only > /dev/null 2>"$errbuf" < /dev/null); then
  echo "gitnexus-reindex: analyze failed (index at ${indexed_sha:0:7}, HEAD ${head_sha:0:7}):" >&2
  tail -20 "$errbuf" >&2
  rm -f "$errbuf"
  exit 1
fi
rm -f "$errbuf"

echo "gitnexus-reindex: ${indexed_sha:0:7} -> ${head_sha:0:7}" >&2
date -Iseconds > "$STATE_FILE"
exit 0
