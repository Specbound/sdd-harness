#!/usr/bin/env bash
# agent-commit-attribution-hook.test.sh — prove the attribution nudge fires on
# untrailered agent commits and stays silent everywhere else.
#
# Run: bash hooks/claude/agent-commit-attribution-hook.test.sh
#
# The hook is advisory, so exit code is always 0. The observable is whether it
# printed. "warns" asserts output; "silent" asserts none.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/agent-commit-attribution-hook.sh"

PASS=0
FAIL=0

run_hook() {
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
' "$1" | bash "$HOOK" 2>/dev/null
}

warns() {
  local label="$1" cmd="$2" out
  out=$(run_hook "$cmd")
  if [ -n "$out" ]; then
    printf '  ok      WARN    %-40s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL    WARN    %-40s no output :: %s\n' "$label" "$cmd"
    FAIL=$((FAIL + 1))
  fi
}

silent() {
  local label="$1" cmd="$2" out
  out=$(run_hook "$cmd")
  if [ -z "$out" ]; then
    printf '  ok      SILENT  %-40s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL    SILENT  %-40s unexpected output :: %s\n' "$label" "$cmd"
    FAIL=$((FAIL + 1))
  fi
}

TRAILER='Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>'

echo "== should warn (untrailered agent commit) =="
warns  "plain -m"                'git commit -m "fix auth timeout"'
warns  "-m with body -m"         'git commit -m "subject" -m "longer body text"'
warns  "--message="              'git commit --message="fix auth timeout"'
warns  "-mmsg attached form"     'git commit -mfix'
warns  "with -a"                 'git commit -am "fix auth timeout"'
warns  "amend with new message"  'git commit --amend -m "reworded subject"'
warns  "after cd"                'cd sub && git commit -m "fix"'
warns  "git -C prefix"           'git -C /tmp/r commit -m "fix"'
warns  "chained after add"       'git add -A && git commit -m "fix"'

echo
echo "== should stay silent =="
silent "trailer present"         "git commit -m \"fix auth timeout\" -m \"$TRAILER\""
silent "trailer in one -m"       "git commit -m \"fix
$TRAILER\""
silent "trailer lowercase key"   'git commit -m "fix" -m "co-authored-by: Claude <x@y.z>"'
silent "amend --no-edit"         'git commit --amend --no-edit'
silent "squash"                  'git commit --squash HEAD~1'
silent "fixup"                   'git commit --fixup HEAD~1'
silent "reuse message -C"        'git commit -C HEAD@{1}'
silent "editor commit, no -m"    'git commit'
silent "editor commit with -a"   'git commit -a'
silent "not a commit"            'git push origin main'
silent "git log mentions commit" 'git log --oneline -5'
silent "unrelated command"       'echo "git commit -m no trailer"'
silent "gh pr create"            'gh pr create --title "commit hook"'

echo
printf 'passed %d, failed %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
