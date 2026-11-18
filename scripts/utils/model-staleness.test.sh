#!/bin/bash
# Functional tests for model-staleness.py. Builds a throwaway harness tree and a
# fixture live page, so no network is touched.
#   bash scripts/utils/model-staleness.test.sh
set -u
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CHECK="$SCRIPT_DIR/model-staleness.py"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS: $1"; }
bad(){ FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want=$2 got=$3)"; fi }

LIVE="$ROOT/live.md"
cat > "$LIVE" << 'EOF'
| Feature | Claude Fable 5.2 | Claude Opus 5.5 | Claude Sonnet 5.5 | Claude Haiku 5.5 |
| :--- | :--- | :--- | :--- | :--- |
| Claude API ID | `claude-fable-5-2` | `claude-opus-5-5` | `claude-sonnet-5-5` | `claude-haiku-5-5` |
EOF

TREE="$ROOT/repo"
mkdir -p "$TREE/skills/a" "$TREE/hooks" "$TREE/scripts/utils" "$TREE/docs"

run_exit(){ python3 "$CHECK" "$TREE" --live-file "$LIVE" --json > "$ROOT/out.json" 2>/dev/null; echo $?; }
field(){ jq -r "$1" "$ROOT/out.json"; }
reset(){ rm -f "$TREE/skills/a/"* "$TREE/hooks/"* "$TREE/docs/"* "$TREE/scripts/utils/"*.txt; }

printf 'Use `opus` (claude-opus-5-5); Sonnet 5.5 for scoped work.\n' > "$TREE/skills/a/SKILL.md"
check "current-only tree is clean"            "0" "$(run_exit)"

printf 'MODEL = "claude-haiku-4-5-20251001"\n' > "$TREE/hooks/x.sh"
check "pinned old ID fails"                    "1" "$(run_exit)"
check "  ...reported as stale"                 "claude-haiku-4-5-20251001" "$(field '.stale[0].mention')"
check "  ...with the current replacement"      "claude-haiku-5-5" "$(field '.stale[0].current')"
check "  ...on the right line"                 "1" "$(field '.stale[0].line')"; reset

printf 'Opus 4.8 was the old default.\n' > "$TREE/skills/a/SKILL.md"
check "prose mention of old version fails"     "opus 4.8" "$(run_exit >/dev/null; field '.stale[0].mention')"; reset

printf 'model: claude-3-5-sonnet-20241022\n' > "$TREE/skills/a/SKILL.md"
check "legacy version-first ID parsed"         "claude-3-5-sonnet-20241022" "$(run_exit >/dev/null; field '.stale[0].mention')"; reset

printf 'Try claude-opus-6-0 next.\n' > "$TREE/skills/a/SKILL.md"
check "ID newer than live is flagged newer"    "claude-opus-6-0" "$(run_exit >/dev/null; field '.newer[0].mention')"; reset

printf 'see claude-code docs; opus 0.98 accuracy; Claude Mythos 5.1 program\n' > "$TREE/skills/a/SKILL.md"
check "non-models and unlisted families pass"  "0" "$(run_exit)"; reset

printf 'Sonnet 4.6 history\n' > "$TREE/docs/history.md"
check "docs/ is out of scope"                  "0" "$(run_exit)"; reset

printf 'Sonnet 4.6 benchmark\n' > "$TREE/skills/a/SKILL.md"
printf 'skills/a/SKILL.md sonnet 4.6  # quoted result\n' > "$TREE/scripts/utils/model-mention-allow.txt"
check "allowlisted mention passes"             "0" "$(run_exit)"; reset

printf 'claude-sonnet-4-6\nOpus 4.8\n' > "$TREE/hooks/fixture.test.sh"
printf 'hooks/fixture.test.sh *\n' > "$TREE/scripts/utils/model-mention-allow.txt"
check "whole-file allowlist passes"            "0" "$(run_exit)"; reset

printf 'claude-sonnet-4-6\n' > "$TREE/skills/a/SKILL.md"
printf 'skills/a/SKILL.md claude-sonnet-4-6\nskills/gone/SKILL.md opus 4.8\n' > "$TREE/scripts/utils/model-mention-debt.txt"
check "debt mention is not a new finding"      "0" "$(run_exit)"
check "  ...but is counted"                    "1" "$(field '.debt_count')"
check "  ...and paid-down lines are listed"    "skills/gone/SKILL.md opus 4.8" "$(field '.debt_cleared[0]')"; reset

printf '| Feature | nothing |\n' > "$ROOT/broken.md"
python3 "$CHECK" "$TREE" --live-file "$ROOT/broken.md" > /dev/null 2>&1
check "unreadable live page exits 2, not clean" "2" "$?"

echo "---"
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
