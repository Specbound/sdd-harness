#!/bin/bash
# Functional tests for skill-library-resolver.sh. Throwaway HOME + project.
#   bash hooks/claude/skill-library-resolver.test.sh
set -u
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$SCRIPT_DIR/skill-library-resolver.sh"
ROOT="$(mktemp -d)"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS: $1"; }
bad(){ FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want=$2 got=$3)"; fi }

export HOME="$ROOT/home"
export CLAUDE_PROJECT_DIR="$ROOT/proj"
for d in "$HOME/.claude/skills/listed-one" "$HOME/.claude/skill-library/lib-one" \
         "$CLAUDE_PROJECT_DIR/.claude/skills/proj-one" "$HOME/.claude/skill-library/proj-one"; do
  mkdir -p "$d"; echo body > "$d/SKILL.md"
done

run(){ printf '{"tool_name":"%s","tool_input":{"skill":"%s"}}' "$1" "$2" | bash "$HOOK" 2>"$ROOT/err"; echo $?; }

check "listed skill allowed"          "0" "$(run Skill listed-one)"
check "library skill blocked"         "2" "$(run Skill lib-one)"
run Skill lib-one >/dev/null
check "block names the library path"  "1" "$(grep -c "skill-library/lib-one/SKILL.md" "$ROOT/err")"
check "project-listed wins over lib"  "0" "$(run Skill proj-one)"
check "unknown skill passes through"  "0" "$(run Skill nope)"
check "plugin skill passes through"   "0" "$(run Skill engineering:debug)"
check "non-Skill tool ignored"        "0" "$(run Read lib-one)"
check "malformed input ignored"       "0" "$(echo 'not json' | bash "$HOOK" 2>/dev/null; echo $?)"
check "path traversal ignored"        "0" "$(run Skill ../skill-library/lib-one)"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
rm -rf "$ROOT"
[ "$FAIL" -eq 0 ]
