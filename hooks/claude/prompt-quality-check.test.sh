#!/usr/bin/env bash
# prompt-quality-check.test.sh — anti-pattern detection and the literal matcher.
#
# The hook matches phrases on word boundaries without regex. These cases pin the
# boundary behaviour the regex version had (a phrase inside a longer word does
# not match; a hyphenated "double-check" does) and the two think-instruction
# checks added from the Opus 5.5 prompting guidance.
#
# Run: bash hooks/claude/prompt-quality-check.test.sh

set -uo pipefail

HERE="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOOK="$HERE/prompt-quality-check.sh"
PASS=0
FAIL=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The hook appends to ~/.code-insights/pq-log.jsonl — keep that in the throwaway tree.
run() {
  jq -n --arg p "$1" '{tool_input: {prompt: $p}}' | HOME="$WORK" bash "$HOOK"
}

has() {
  local label="$1" out="$2" needle="$3"
  if [[ "$out" == *"$needle"* ]]; then
    echo "  ok    $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $label — missing '$needle'"; FAIL=$((FAIL + 1))
  fi
}

lacks() {
  local label="$1" out="$2" needle="$3"
  if [[ "$out" != *"$needle"* ]]; then
    echo "  ok    $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $label — unexpected '$needle'"; FAIL=$((FAIL + 1))
  fi
}

echo "prompt-quality-check"

OUT="$(run "Think carefully about the parse function in foo.py and fix it.")"
has   "flags think-carefully" "$OUT" "think-instruction"

OUT="$(run "Please think step by step in a scratchpad about the parse function.")"
has   "scratchpad phrasing is mandatory-scratchpad" "$OUT" "mandatory-scratchpad"
lacks "scratchpad phrasing is not double-flagged as think-instruction" "$OUT" "think-instruction"

OUT="$(run "Implement the parse function in foo.py. Show your reasoning.")"
has   "flags show-your-reasoning" "$OUT" "show-reasoning-request"

OUT="$(run "Rethinking hardware is out of scope. Implement the parse function in foo.py.")"
lacks "phrase inside a longer word does not match" "$OUT" "think-instruction"

OUT="$(run "Update the loader. Verify it, double-check it, then triple-check the output.")"
has   "hyphenated double-check counts toward verification-ritual" "$OUT" "verification-ritual"

OUT="$(run "Refactor the parse function in foo.py. Only touch foo.py; report a diff.")"
has   "action verb + named target scores specificity 4" "$OUT" "request_specificity: 4/5"
has   "scope words score scope 5" "$OUT" "scope_management: 5/5"
lacks "clean prompt has no anti-patterns" "$OUT" "Anti-patterns"

# >=10 words, so the short-prompt penalty does not mask the check under test.
OUT="$(run "Refactor the reflect-agent prompt in foo.py so that it returns early.")"
has   "hyphenated middle word is not 'the <word> <noun>'" "$OUT" "request_specificity: 3/5"

run "Implement the parse function in foo.py." >/dev/null
has   "writes a log entry" "$(cat "$WORK/.code-insights/pq-log.jsonl" 2>/dev/null)" '"prompt_hash"'

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
