#!/usr/bin/env bash
# hook-replay.test.sh — plant recorded calls, replay them through two stub hooks,
# and check that exactly the flipped verdicts are reported.
#
# Run: bash skills/hook-design/resources/hook-replay.test.sh

set -uo pipefail

HERE="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TOOL="$HERE/hook-replay.py"
PASS=0
FAIL=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PROJ="$WORK/.claude/projects/fake-repo"
mkdir -p "$PROJ"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Four Bash calls (one duplicated, so 3 unique) and one Read call the --tool filter must skip.
for cmd in "ls -la" "rm -rf build" "git push --force" "ls -la"; do
  jq -cn --arg c "$cmd" --arg ts "$NOW" \
    '{type:"assistant",timestamp:$ts,message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}}'
done > "$PROJ/s.jsonl"
jq -cn --arg ts "$NOW" \
  '{type:"assistant",timestamp:$ts,message:{content:[{type:"tool_use",name:"Read",input:{file_path:"/x"}}]}}' \
  >> "$PROJ/s.jsonl"

# Old hook blocks `rm -rf` by exit 2. New hook stops blocking rm -rf and instead
# denies `--force` through JSON output — one newly allowed, one newly blocked.
cat > "$WORK/old.sh" <<'EOF'
#!/bin/bash
cmd=$(jq -r '.tool_input.command')
[[ "$cmd" == *"rm -rf"* ]] && exit 2
exit 0
EOF
cat > "$WORK/new.sh" <<'EOF'
#!/bin/bash
cmd=$(jq -r '.tool_input.command')
if [[ "$cmd" == *"--force"* ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"}}'
fi
exit 0
EOF

OUT="$(HOME="$WORK" python3 "$TOOL" --old "$WORK/old.sh" --new "$WORK/new.sh" --tool Bash --days 0 --json)"

check() {
  local label="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    echo "  ok    $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $label — wanted '$want', got '$got'"; FAIL=$((FAIL + 1))
  fi
}

echo "hook-replay"
check "dedups calls and filters by tool" "3" "$(jq -r '.calls' <<<"$OUT")"
check "JSON deny counts as newly blocked" "1" "$(jq -r '.newly_blocked' <<<"$OUT")"
check "exit-2 block lifted counts as newly allowed" "1" "$(jq -r '.newly_allowed' <<<"$OUT")"
check "no spurious errors" "0" "$(jq -r '.new_errors' <<<"$OUT")"

HOME="$WORK" python3 "$TOOL" --old "$WORK/old.sh" --new "$WORK/new.sh" --tool Bash --days 0 --fail-on-change >/dev/null
check "--fail-on-change exits 1 when verdicts flip" "1" "$?"

HOME="$WORK" python3 "$TOOL" --old "$WORK/old.sh" --new "$WORK/old.sh" --tool Bash --days 0 --fail-on-change >/dev/null
check "identical hooks exit 0" "0" "$?"

TEXT="$(HOME="$WORK" python3 "$TOOL" --old "$WORK/old.sh" --new "$WORK/new.sh" --tool Bash --days 0)"
check "call contents hidden without --samples" "no" "$([[ "$TEXT" == *"git push"* ]] && echo yes || echo no)"

HOME="$WORK" python3 "$TOOL" --old "$WORK/old.sh" --new "$WORK/new.sh" --tool Edit --days 0 >/dev/null 2>&1
check "no recorded calls is an error, not a pass" "2" "$?"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
