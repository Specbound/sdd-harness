#!/bin/bash
# Functional tests for prompt-hook.sh — hot-memory injection cadence.
#
#   bash hooks/claude/prompt-hook.test.sh
#
# Exits non-zero on any failure.
set -u

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$SCRIPT_DIR/prompt-hook.sh"
ROOT="$(mktemp -d)"
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want=$2 got=$3)"; fi }

mkdir -p "$ROOT/.claude/memory"
echo "# Hot Memory" > "$ROOT/.claude/memory/hot-memory.md"
TRANSCRIPT="$ROOT/t.jsonl"
: > "$TRANSCRIPT"

# prompt <session_id> -> "1" when hot-memory was injected, "0" otherwise
prompt() {
  printf '{"session_id":"%s","transcript_path":"%s"}' "$1" "$TRANSCRIPT" \
    | (cd "$ROOT" && bash "$HOOK" 2>/dev/null) | grep -cF -- '--- Active Context (hot-memory) ---'
}

echo "=== 1. default cadence: prompts 1 and 11 inject, 2-10 skip ==="
seq_out=""
for _ in $(seq 1 12); do seq_out="$seq_out$(prompt s1)"; done
check "1st..12th"            "100000000010" "$seq_out"

echo "=== 2. new session starts its own cadence ==="
check "other session 1st"    "1" "$(prompt s2)"
check "other session 2nd"    "0" "$(prompt s2)"

echo "=== 3. compaction resets the cadence ==="
echo '{"type":"system","subtype":"compact_boundary"}' >> "$TRANSCRIPT"
check "1st after compact"    "1" "$(prompt s1)"
check "2nd after compact"    "0" "$(prompt s1)"

echo "=== 4. SDD_HOT_MEMORY_EVERY ==="
seq_out=""
for _ in 1 2 3 4; do seq_out="$seq_out$(SDD_HOT_MEMORY_EVERY=2 prompt s3)"; done
check "every 2"              "1010" "$seq_out"
check "invalid -> inject"    "1" "$(SDD_HOT_MEMORY_EVERY=x prompt s3)"

echo "=== 5. failures inject ==="
check "malformed event"      "1" "$(echo 'not json' | (cd "$ROOT" && bash "$HOOK" 2>/dev/null) | grep -cF -- '--- Active Context')"
check "no session_id"        "1" "$(echo '{}' | (cd "$ROOT" && bash "$HOOK" 2>/dev/null) | grep -cF -- '--- Active Context')"
echo 'garbage' > "$ROOT/.claude/memory/.prompt-hook/s4.json"
check "corrupt counter 1st"  "1" "$(prompt s4)"
check "corrupt counter 2nd"  "0" "$(prompt s4)"

echo "=== 6. empty hot-memory -> nothing ==="
: > "$ROOT/.claude/memory/hot-memory.md"
check "empty file"           "0" "$(prompt s5)"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
rm -rf "$ROOT"
[ "$FAIL" -eq 0 ]
