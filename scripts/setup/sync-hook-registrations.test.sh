#!/usr/bin/env bash
# sync-hook-registrations.test.sh — prove projects gain hooks added to the template,
# keep their own, and keep hooks they removed removed.
#
# Run: bash scripts/setup/sync-hook-registrations.test.sh

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SCRIPT="$__here/sync-hook-registrations.py"

PASS=0
FAIL=0
ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL %s :: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sync-hooks-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
TPL="$TMP/template.json"

cmd() { printf 'bash \\"${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/%s\\"' "$1"; }

write_template() {  # write_template <extra Stop hook script or "">
  local extra=""
  [ -n "${1:-}" ] && extra=", { \"type\": \"command\", \"command\": \"$(cmd "$1")\" }"
  cat > "$TPL" <<JSON
{
  "permissions": { "allow": ["Bash(ls:*)"] },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "$(cmd a-hook.sh)" },
        { "type": "command", "command": "$(cmd b-hook.sh)", "timeout": 5 }
      ] }
    ],
    "PostToolUse": [
      { "matcher": "Write|Edit", "hooks": [ { "type": "command", "command": "$(cmd d-hook.sh)" } ] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [ { "type": "command", "command": "$(cmd c-hook.sh)" }${extra} ] }
    ]
  }
}
JSON
}

# A project installed from an older template: only a-hook (wrapped, as update.sh
# leaves it) plus a hook of its own, and every hook file already copied in.
new_project() {
  local p="$1"
  mkdir -p "$p/.claude/hooks"
  for h in a-hook.sh b-hook.sh c-hook.sh d-hook.sh e-hook.sh custom.sh; do
    printf '#!/bin/bash\nexit 0\n' > "$p/.claude/hooks/$h"
  done
  cat > "$p/.claude/settings.json" <<JSON
{
  "permissions": { "allow": ["Bash(git:*)"] },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "bash \\"\${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/_run-hook.sh\\" $(cmd a-hook.sh)" },
        { "type": "command", "command": "$(cmd custom.sh)" }
      ] }
    ]
  }
}
JSON
}

# hooks_of <settings> — "event|matcher|script" per registration, sorted
hooks_of() {
  python3 - "$1" <<'PY'
import json, sys
from pathlib import Path
d = json.load(open(sys.argv[1]))
rows = []
for ev, groups in (d.get("hooks") or {}).items():
    for g in groups:
        for h in g.get("hooks", []):
            rows.append(f"{ev}|{g.get('matcher') or ''}|{h['command'].rstrip(chr(34)).rsplit('/', 1)[-1]}")
print("\n".join(sorted(rows)))
PY
}
has()   { hooks_of "$1" | grep -qxF "$2"; }
count() { hooks_of "$1" | grep -cxF "$2"; }
sync()  { python3 "$SCRIPT" --template "$TPL" "$@"; }

write_template ""
P="$TMP/proj"; new_project "$P"; S="$P/.claude/settings.json"

echo "== first sync"
sync "$P" > "$TMP/r1.txt"; rc=$?
[ "$rc" -eq 0 ] && ok "exits 0" || fail "exits 0" "rc=$rc"
has "$S" "PreToolUse|Bash|b-hook.sh" && ok "missing hook added to existing matcher group" || fail "b-hook added" "$(hooks_of "$S")"
has "$S" "Stop||c-hook.sh"           && ok "missing hook added under a new event"        || fail "c-hook added" ""
has "$S" "PostToolUse|Write|Edit|d-hook.sh" && ok "missing hook added under a new matcher" || fail "d-hook added" ""
[ "$(count "$S" "PreToolUse|Bash|a-hook.sh")" = "1" ] && ok "wrapped existing hook not duplicated" || fail "a-hook dup" "$(count "$S" "PreToolUse|Bash|a-hook.sh")"
has "$S" "PreToolUse|Bash|custom.sh" && ok "project's own hook kept" || fail "custom kept" ""
python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
assert d["permissions"]["allow"] == ["Bash(git:*)"]
bash = d["hooks"]["PreToolUse"][0]["hooks"]
assert "custom.sh" in bash[1]["command"], "order changed"
b = [h for h in bash if "b-hook.sh" in h["command"]][0]
assert b.get("timeout") == 5, "template entry not copied whole"
' "$S" && ok "permissions, order and template fields (timeout) preserved" || fail "preserved" "see assert"
grep -q "first sync" "$TMP/r1.txt" && ok "report flags first sync" || fail "report" "$(cat "$TMP/r1.txt")"

echo "== idempotent"
cp "$S" "$TMP/s1.json"; cp "$P/.claude/.hook-offers.json" "$TMP/o1.json"
sync "$P" > "$TMP/r2.txt"
cmp -s "$S" "$TMP/s1.json" && cmp -s "$P/.claude/.hook-offers.json" "$TMP/o1.json" && grep -q "^OK" "$TMP/r2.txt" \
  && ok "second sync changes nothing" || fail "idempotent" "$(cat "$TMP/r2.txt")"

echo "== removal sticks"
python3 -c '
import json, sys
p = sys.argv[1]; d = json.load(open(p))
del d["hooks"]["Stop"]
json.dump(d, open(p, "w"), indent=2)
' "$S"
sync "$P" > "$TMP/r3.txt"
! has "$S" "Stop||c-hook.sh" && grep -q "held" "$TMP/r3.txt" \
  && ok "hook the project removed is not re-added" || fail "removal sticks" "$(cat "$TMP/r3.txt")"

echo "== later template hook still arrives"
write_template e-hook.sh
sync "$P" > /dev/null
has "$S" "Stop||e-hook.sh" && ok "hook added to template later reaches the project" || fail "e-hook added" "$(hooks_of "$S")"
! has "$S" "Stop||c-hook.sh" && ok "removed hook still not re-added" || fail "c-hook stays removed" ""

echo "== hook file not there yet"
write_template f-hook.sh
sync "$P" > "$TMP/r4.txt"
! has "$S" "Stop||f-hook.sh" && grep -q "not added" "$TMP/r4.txt" \
  && ok "no hook file → not registered" || fail "missing file" "$(cat "$TMP/r4.txt")"
printf '#!/bin/bash\nexit 0\n' > "$P/.claude/hooks/f-hook.sh"
sync "$P" > /dev/null
has "$S" "Stop||f-hook.sh" && ok "registered on the next sync once the file lands" || fail "file landed" ""

echo "== matcher drift"
P9="$TMP/drift"; new_project "$P9"
python3 -c '
import json, sys
p = sys.argv[1]; d = json.load(open(p))
q = chr(34)
d["hooks"]["PostToolUse"] = [{"matcher": "Write", "hooks": [{"type": "command",
    "command": "bash " + q + "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/d-hook.sh" + q}]}]
json.dump(d, open(p, "w"), indent=2)
' "$P9/.claude/settings.json"
sync "$P9" > "$TMP/r9.txt"
[ "$(hooks_of "$P9/.claude/settings.json" | grep -c 'd-hook.sh')" = "1" ] && grep -q "kept project matcher" "$TMP/r9.txt" \
  && ok "same event, other matcher → not added twice, reported" || fail "matcher drift" "$(hooks_of "$P9/.claude/settings.json" | grep d-hook)"

echo "== no settings.json"
P2="$TMP/fresh"; new_project "$P2"; rm "$P2/.claude/settings.json"
sync "$P2" > "$TMP/r5.txt"
python3 -c '
import json, sys
a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
sys.exit(0 if a == b else 1)
' "$P2/.claude/settings.json" "$TPL" && grep -q "^CREATED" "$TMP/r5.txt" \
  && ok "missing settings.json created from template" || fail "create" "$(cat "$TMP/r5.txt")"

echo "== safety"
P3="$TMP/local"; new_project "$P3"; printf '{"hooks":{}}\n' > "$P3/.claude/settings.local.json"
cp "$P3/.claude/settings.local.json" "$TMP/local.json"
sync "$P3" > /dev/null
cmp -s "$P3/.claude/settings.local.json" "$TMP/local.json" && ok "settings.local.json untouched" || fail "local" "changed"

P4="$TMP/bad"; new_project "$P4"; printf '{ "hooks": ' > "$P4/.claude/settings.json"
cp "$P4/.claude/settings.json" "$TMP/bad.json"
sync "$P4" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && cmp -s "$P4/.claude/settings.json" "$TMP/bad.json" && [ ! -f "$P4/.claude/.hook-offers.json" ] \
  && ok "invalid settings → exit 1, nothing written" || fail "invalid settings" "rc=$rc"

P5="$TMP/badoffers"; new_project "$P5"; printf 'garbage' > "$P5/.claude/.hook-offers.json"
cp "$P5/.claude/settings.json" "$TMP/p5.json"
sync "$P5" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && cmp -s "$P5/.claude/settings.json" "$TMP/p5.json" \
  && ok "corrupt offers record → exit 1, settings untouched (would otherwise re-add removals)" \
  || fail "corrupt offers" "rc=$rc"

P6="$TMP/dry"; new_project "$P6"; cp "$P6/.claude/settings.json" "$TMP/p6.json"
sync --dry-run "$P6" | grep -q "^WOULD" && cmp -s "$P6/.claude/settings.json" "$TMP/p6.json" \
  && [ ! -f "$P6/.claude/.hook-offers.json" ] && ok "--dry-run reports without writing" || fail "dry-run" "wrote"

P7="$TMP/both"; new_project "$P7"; P8="$TMP/both-bad"; new_project "$P8"; printf 'x' > "$P8/.claude/settings.json"
sync "$P8" "$P7" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && has "$P7/.claude/settings.json" "Stop||c-hook.sh" \
  && ok "one broken project does not stop the others" || fail "isolation" "rc=$rc"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
