#!/usr/bin/env bash
# ledger-append-only.test.sh — prove hook blocks Write/Edit/MultiEdit on the
# five protected measurement ledgers, allows everything else, and honors the
# SDD_LEDGER_ROTATE=1 escape hatch.
#
# Run: bash hooks/claude/ledger-append-only.test.sh

set -u
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/ledger-append-only.sh"

PASS=0
FAIL=0

# Feed the hook a PreToolUse event; echo its exit code.
run_hook() {
    local tool="$1" path="$2"
    python3 -c '
import json, sys
print(json.dumps({"tool_name": sys.argv[1], "tool_input": {"file_path": sys.argv[2]}}))
' "$tool" "$path" | env -u SDD_LEDGER_ROTATE bash "$HOOK" >/dev/null 2>&1
    echo $?
}

run_hook_rotate() {
    local tool="$1" path="$2"
    python3 -c '
import json, sys
print(json.dumps({"tool_name": sys.argv[1], "tool_input": {"file_path": sys.argv[2]}}))
' "$tool" "$path" 2>/dev/null | SDD_LEDGER_ROTATE=1 bash "$HOOK" >/dev/null 2>&1
    echo $?
}

blocks() {
    local label="$1" tool="$2" path="$3" rc
    rc=$(run_hook "$tool" "$path")
    if [ "$rc" = "2" ]; then
        printf '  ok    BLOCK %-44s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  FAIL  BLOCK %-44s got exit %s, want 2 :: %s %s\n' "$label" "$rc" "$tool" "$path"
        FAIL=$((FAIL + 1))
    fi
}

allows() {
    local label="$1" tool="$2" path="$3" rc
    rc=$(run_hook "$tool" "$path")
    if [ "$rc" = "0" ]; then
        printf '  ok    ALLOW %-44s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  FAIL  ALLOW %-44s got exit %s, want 0 :: %s %s\n' "$label" "$rc" "$tool" "$path"
        FAIL=$((FAIL + 1))
    fi
}

allows_rotate() {
    local label="$1" tool="$2" path="$3" rc
    rc=$(run_hook_rotate "$tool" "$path")
    if [ "$rc" = "0" ]; then
        printf '  ok    ROTATE %-43s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  FAIL  ROTATE %-43s got exit %s, want 0 :: %s %s\n' "$label" "$rc" "$tool" "$path"
        FAIL=$((FAIL + 1))
    fi
}

echo "== ledger-append-only.sh =="

blocks "Write trust-score.jsonl"     "Write"     ".claude/memory/trust-score.jsonl"
blocks "Edit metrics.jsonl"          "Edit"      ".claude/memory/metrics.jsonl"
blocks "MultiEdit caveman-savings"   "MultiEdit" ".claude/memory/caveman-savings.jsonl"
blocks "Write learnings.jsonl"       "Write"     ".claude/memory/learnings.jsonl"
blocks "Edit observations.md"        "Edit"      ".claude/memory/observations.md"
blocks "absolute repo path"          "Write"     "$__here/../../.claude/memory/trust-score.jsonl"

allows "Write unrelated memory file" "Write"     ".claude/memory/hot-memory.md"
allows "Write outside .claude"       "Write"     "scripts/utils/rtk-net-effect.py"
allows "Edit non-ledger jsonl"       "Edit"      ".claude/memory/rtk-net-effect.json"
allows "Bash tool ignored"           "Bash"      ".claude/memory/trust-score.jsonl"
allows "no file_path"                "Write"     ""

allows_rotate "rotate bypasses block" "Write" ".claude/memory/trust-score.jsonl"

echo
echo "== $PASS passed, $FAIL failed =="
[ "$FAIL" = "0" ]
