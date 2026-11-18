#!/bin/bash
# Throwaway-tree test for code-review-learning-runner.sh PR discovery. `gh` and `claude`
# are stubbed, so no network and no LLM run. Run: bash scripts/routines/code-review-learning-runner.test.sh

set -u
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/../lib/resolve-harness-dir.sh" || exit 1
RUNNER="$HARNESS_DIR/scripts/routines/code-review-learning-runner.sh"
PROMPT="$HARNESS_DIR/scripts/routines/code-review-learning-prompt.md"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/crl-test.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT

FAILS=0
check() { # check <name> <condition-exit-code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}

mkdir -p "$ROOT/bin" "$ROOT/repo/.claude/memory" "$ROOT/repo/.claude/scripts/routines"
cp "$PROMPT" "$ROOT/repo/.claude/scripts/routines/"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$ROOT/bin/gh" <<STUB
#!/bin/bash
case "\$*" in
  "pr list "*) cat "$ROOT/prlist.json" ;;
  "api "*pulls/11/comments*) echo '[{"user":{"login":"bob"}}]' ;;
  "api "*pulls/12/comments*) echo '[]' ;;
  "api "*issues/12/comments*) echo '[{"user":{"login":"alice"}}]' ;;
  "api "*issues/15/comments*) echo '[{"user":{"login":"vercel[bot]","type":"Bot"}}]' ;;
  "api "*pulls/16/reviews*) echo '[{"user":{"login":"claude[bot]","type":"Bot"},"state":"COMMENTED"}]' ;;
  "api "*) echo '[]' ;;
  *) exit 1 ;;
esac
STUB
cat > "$ROOT/bin/claude" <<STUB
#!/bin/bash
cat > "$ROOT/claude-prompt.txt"
STUB
chmod +x "$ROOT/bin/gh" "$ROOT/bin/claude"

cat > "$ROOT/prlist.json" <<JSON
[{"number":11,"mergedAt":"$NOW","author":{"login":"alice"}},
 {"number":12,"mergedAt":"$NOW","author":{"login":"alice"}},
 {"number":13,"mergedAt":"2020-01-01T00:00:00Z","author":{"login":"alice"}},
 {"number":14,"mergedAt":"$NOW","author":{"login":"alice"}},
 {"number":15,"mergedAt":"$NOW","author":{"login":"alice"}},
 {"number":16,"mergedAt":"$NOW","author":{"login":"alice"}}]
JSON
echo 14 > "$ROOT/repo/.claude/memory/.code-review-learning-processed"

run_runner() { (cd "$ROOT/repo" && PATH="$ROOT/bin:$PATH" bash "$RUNNER" 2>/dev/null); }

# 1. a PR with no babysit log but a reviewer other than its author is learned from
git -C "$ROOT/repo" init -q
run_runner
check "exit 0" $?
PROMPT_SENT="$(cat "$ROOT/claude-prompt.txt" 2>/dev/null)"
case "$PROMPT_SENT" in *"processed by this sweep): 11"*) r=0 ;; *) r=1 ;; esac
check "PR 11 (outside reviewer, no log) reaches the prompt" $r
case "$PROMPT_SENT" in *"outside the auto-PR path and have no log): none"*) r=0 ;; *) r=1 ;; esac
check "logged subset is 'none' without a babysit log" $r
case "$PROMPT_SENT" in *"processed by this sweep): 11,16"$'\n'*) r=0 ;; *) r=1 ;; esac
check "only PRs 11 and 16 are sent (author-only 12 and deploy-bot-only 15 are not)" $r
LEDGER="$ROOT/repo/.claude/memory/.code-review-learning-processed"
grep -qx 11 "$LEDGER"; check "PR 11 marked processed after a successful run" $?
grep -qx 12 "$LEDGER"; check "PR 12 settled without an LLM run" $?
grep -qx 15 "$LEDGER"; check "PR 15 (deploy-preview bot comment only) settled without an LLM run" $?
grep -qx 16 "$LEDGER"; check "PR 16 (bot review) marked processed after the run" $?
grep -qx 13 "$LEDGER"; [ $? -ne 0 ]; check "PR 13 (older than the lookback) left alone" $?

# 2. nothing left to learn from: skip with a reason, no claude call
rm -f "$ROOT/claude-prompt.txt" "$ROOT/repo/.claude/memory/.last-code-review-learning-run"
run_runner
[ ! -f "$ROOT/claude-prompt.txt" ]; check "second run makes no claude call" $?
grep -q "outside review activity" "$ROOT/repo/.claude/memory/.skip-reason-code-review-learning"
check "skip reason recorded for the dashboard" $?

[ "$FAILS" -eq 0 ] && echo "all passed" || { echo "$FAILS failed"; exit 1; }
