#!/usr/bin/env bash
# wrap-hook-commands.test.sh — prove the settings migration wraps only what it safely can,
# that a wrapped command still runs the original hook, and that --unwrap restores it.
#
# Run: bash scripts/setup/wrap-hook-commands.test.sh

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SCRIPT="$__here/wrap-hook-commands.py"
WRAPPER_SRC="$__here/../../hooks/claude/_run-hook.sh"

PASS=0
FAIL=0
ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL %s :: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/wrap-hooks-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# new_project <dir> — a project with the wrapper, two hooks and a settings.json
# covering every case the migration must tell apart.
new_project() {
  local p="$1"
  mkdir -p "$p/.claude/hooks"
  cp "$WRAPPER_SRC" "$p/.claude/hooks/_run-hook.sh"
  printf '#!/bin/bash\ncat >/dev/null\necho sh-hook-ran\n' > "$p/.claude/hooks/a-hook.sh"
  printf 'import sys\nsys.stdin.read()\nprint("py-hook-ran")\n' > "$p/.claude/hooks/b-hook.py"
  cat > "$p/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "allow": ["Bash(ls:*)"]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/a-hook.sh\"" },
          { "type": "command", "command": "python3 \"${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/b-hook.py\"" },
          { "type": "command", "command": "bash x.sh | tee out.log" },
          { "type": "command", "command": "bash x.sh 2>/dev/null" },
          { "type": "command", "command": "test -f x && bash x.sh" },
          { "type": "command", "command": "FOO=1 bash x.sh" },
          { "type": "command", "command": "bash $(pwd)/x.sh" },
          { "type": "prompt", "prompt": "not a command hook" }
        ]
      }
    ]
  }
}
JSON
}

cmd_at() {  # cmd_at <settings> <index> — command string of hook <index>
  python3 -c '
import json, sys
h = json.load(open(sys.argv[1]))["hooks"]["PreToolUse"][0]["hooks"][int(sys.argv[2])]
print(h.get("command") or h.get("prompt"))
' "$1" "$2"
}

PROJ="$TMP/proj"
new_project "$PROJ"
cp "$PROJ/.claude/settings.json" "$TMP/original.json"
S="$PROJ/.claude/settings.json"

echo "== wrap"
python3 "$SCRIPT" "$PROJ" > "$TMP/report.txt"; rc=$?
[ "$rc" -eq 0 ] && ok "exits 0" || fail "exits 0" "rc=$rc"

case "$(cmd_at "$S" 0)" in
  'bash "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/_run-hook.sh" bash "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/a-hook.sh"')
    ok "bash hook wrapped" ;;
  *) fail "bash hook wrapped" "$(cmd_at "$S" 0)" ;;
esac
case "$(cmd_at "$S" 1)" in
  *_run-hook.sh\"\ python3\ *) ok "python hook wrapped (interpreter kept)" ;;
  *) fail "python hook wrapped" "$(cmd_at "$S" 1)" ;;
esac
for i in 2 3 4 5 6; do
  orig="$(cmd_at "$TMP/original.json" "$i")"
  [ "$(cmd_at "$S" "$i")" = "$orig" ] && ok "left alone: $orig" || fail "left alone: $orig" "$(cmd_at "$S" "$i")"
done
[ "$(cmd_at "$S" 7)" = "not a command hook" ] && ok "non-command hook untouched" || fail "prompt hook" "changed"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["permissions"]["allow"]==["Bash(ls:*)"]' "$S" \
  && ok "rest of settings.json preserved" || fail "rest preserved" "permissions changed"
grep -q "skipped 5" "$TMP/report.txt" && ok "report counts 5 skipped" || fail "report" "$(cat "$TMP/report.txt")"

echo "== wrapped commands still run the hook"
for i in 0 1; do
  cmd="$(cmd_at "$S" "$i")"
  out="$(cd "$TMP" && printf '{"hook_event_name":"PreToolUse","session_id":"w%s"}' "$i" \
        | CLAUDE_PROJECT_DIR="$PROJ" sh -c "$cmd")"
  want=$([ "$i" -eq 0 ] && echo sh-hook-ran || echo py-hook-ran)
  [ "$out" = "$want" ] && ok "hook $i runs through wrapper from another cwd" || fail "hook $i runs" "got '$out'"
done

echo "== idempotent"
cp "$S" "$TMP/once.json"
python3 "$SCRIPT" "$PROJ" > /dev/null
cmp -s "$S" "$TMP/once.json" && ok "second run changes nothing" || fail "idempotent" "file changed"

echo "== unwrap"
python3 "$SCRIPT" --unwrap "$PROJ" > /dev/null
python3 -c '
import json, sys
a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
sys.exit(0 if a == b else 1)
' "$S" "$TMP/original.json" && ok "--unwrap restores every original command" || fail "unwrap" "differs from original"

echo "== settings.local.json"
cp "$TMP/original.json" "$PROJ/.claude/settings.local.json"
python3 "$SCRIPT" "$PROJ" > /dev/null
case "$(cmd_at "$PROJ/.claude/settings.local.json" 0)" in
  *_run-hook.sh*) ok "settings.local.json wrapped too" ;;
  *) fail "settings.local.json" "not wrapped" ;;
esac

echo "== safety"
P2="$TMP/nowrapper"; new_project "$P2"; rm "$P2/.claude/hooks/_run-hook.sh"
cp "$P2/.claude/settings.json" "$TMP/p2.json"
python3 "$SCRIPT" "$P2" > "$TMP/r2.txt"
cmp -s "$P2/.claude/settings.json" "$TMP/p2.json" && grep -q "^SKIP" "$TMP/r2.txt" \
  && ok "wrapper missing → nothing wrapped" || fail "wrapper missing" "file changed"

P3="$TMP/badjson"; new_project "$P3"; printf '{ "hooks": ' > "$P3/.claude/settings.json"
cp "$P3/.claude/settings.json" "$TMP/p3.json"
python3 "$SCRIPT" "$P3" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && cmp -s "$P3/.claude/settings.json" "$TMP/p3.json" \
  && ok "invalid JSON → exit 1, file untouched" || fail "invalid JSON" "rc=$rc"

P4="$TMP/dry"; new_project "$P4"; cp "$P4/.claude/settings.json" "$TMP/p4.json"
python3 "$SCRIPT" --dry-run "$P4" | grep -q "^WOULD" && cmp -s "$P4/.claude/settings.json" "$TMP/p4.json" \
  && ok "--dry-run reports without writing" || fail "dry-run" "wrote or did not report"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
