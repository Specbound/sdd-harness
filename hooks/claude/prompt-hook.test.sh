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

echo "=== 7. size budget ==="
HM="$ROOT/.claude/memory/hot-memory.md"
# run_once <session> -> full hook stdout for a first prompt (always injects)
run_once() {
  printf '{"session_id":"%s","transcript_path":"%s"}' "$1" "$TRANSCRIPT" \
    | (cd "$ROOT" && bash "$HOOK" 2>/dev/null)
}
printf '# Hot Memory\n\n## Current Priorities\n1. small file\n' > "$HM"
run_once b1 > "$ROOT/small.out"
{ echo "--- Active Context (hot-memory) ---"; cat "$HM"; echo "--- End Active Context ---"; } > "$ROOT/small.want"
if cmp -s "$ROOT/small.out" "$ROOT/small.want"; then ok "small file injected whole, byte-identical"; else bad "small file changed"; fi

python3 -c '
import sys
lines = ["# Hot Memory", "", "## Current Priorities"]
lines += [f"{i}. " + "priority text " * 20 for i in range(1, 200)]
open(sys.argv[1], "w").write("\n".join(lines) + "\n")
' "$HM"
run_once b2 > "$ROOT/big.out"
size=$(wc -c < "$ROOT/big.out" | tr -d ' ')
[ "$size" -le 9000 ] && ok "oversized file stays under 9000 bytes ($size)" || bad "oversized output is $size bytes"
grep -qF "[hot-memory truncated: showing" "$ROOT/big.out" && ok "truncation notice present" || bad "no truncation notice"
grep -qF -- "--- End Active Context ---" "$ROOT/big.out" && ok "footer kept after truncation" || bad "footer missing"
python3 -c '
import sys
out = open(sys.argv[1]).read().split("\n")
body = [l for l in out if l and not l.startswith("---") and not l.startswith("[hot-memory truncated")]
src = set(open(sys.argv[2]).read().split("\n"))
sys.exit(0 if all(l in src for l in body) else 1)
' "$ROOT/big.out" "$HM" && ok "cut only at line boundaries" || bad "a line was cut mid-way"
check "starts with the top of the file" "# Hot Memory" "$(sed -n 2p "$ROOT/big.out")"

small=$(printf '{"session_id":"b3","transcript_path":"%s"}' "$TRANSCRIPT" \
  | (cd "$ROOT" && SDD_HOT_MEMORY_MAX_BYTES=2000 bash "$HOOK" 2>/dev/null) | wc -c | tr -d ' ')
[ "$small" -le 2000 ] && ok "SDD_HOT_MEMORY_MAX_BYTES respected ($small)" || bad "budget override ignored ($small)"

python3 -c 'import sys; open(sys.argv[1], "w").write("x" * 20000 + "\n")' "$HM"
run_once b4 > "$ROOT/one.out"
size=$(wc -c < "$ROOT/one.out" | tr -d ' ')
[ "$size" -le 9000 ] && grep -qF "[hot-memory truncated" "$ROOT/one.out" \
  && ok "single giant line: notice only, under budget" || bad "single giant line ($size bytes)"

echo "=== 6. empty hot-memory -> nothing ==="
: > "$ROOT/.claude/memory/hot-memory.md"
check "empty file"           "0" "$(prompt s5)"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
rm -rf "$ROOT"
[ "$FAIL" -eq 0 ]
