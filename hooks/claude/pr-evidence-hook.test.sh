#!/usr/bin/env bash
# pr-evidence-hook.test.sh — prove the evidence gate nudges when a PR body has
# no `## Evidence` section, stays silent when it does, and never touches a
# command that is not `gh pr create`.
#
# Run: bash hooks/claude/pr-evidence-hook.test.sh
#
# The hook is a SOFT gate: it always exits 0. So exit code proves nothing here —
# every case asserts on whether the nudge text was emitted. A test that checked
# exit codes would pass no matter what the hook did.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/pr-evidence-hook.sh"

PASS=0
FAIL=0
TMPDIR_T="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_T"' EXIT

# Feed a command to the hook as a PreToolUse Bash event; echo "nudge" or "quiet".
run_hook() {
  local out
  out=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
' "$1" | bash "$HOOK" 2>/dev/null)
  case "$out" in
    *"PR Evidence"*) echo "nudge" ;;
    *)               echo "quiet" ;;
  esac
}

nudges() {
  local label="$1" cmd="$2" got
  got=$(run_hook "$cmd")
  if [ "$got" = "nudge" ]; then
    printf '  ok    NUDGE  %-42s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  NUDGE  %-42s got %s :: %s\n' "$label" "$got" "$cmd"
    FAIL=$((FAIL + 1))
  fi
}

quiet() {
  local label="$1" cmd="$2" got
  got=$(run_hook "$cmd")
  if [ "$got" = "quiet" ]; then
    printf '  ok    QUIET  %-42s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  QUIET  %-42s got %s :: %s\n' "$label" "$got" "$cmd"
    FAIL=$((FAIL + 1))
  fi
}

# Exit code must be 0 on every path — a soft gate that blocks is a bug.
exits_zero() {
  local label="$1" cmd="$2" rc
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
' "$cmd" | bash "$HOOK" >/dev/null 2>&1
  rc=$?
  if [ "$rc" = "0" ]; then
    printf '  ok    EXIT0  %-42s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  EXIT0  %-42s got exit %s :: %s\n' "$label" "$rc" "$cmd"
    FAIL=$((FAIL + 1))
  fi
}

BODY_OK="$TMPDIR_T/body-ok.md"
BODY_BAD="$TMPDIR_T/body-bad.md"
printf 'Fixes the thing\n\n## Evidence\n**Before:** crash\n**After:** ok\n' > "$BODY_OK"
printf 'Fixes the thing\n\nNo proof here.\n' > "$BODY_BAD"

echo "== nudges: body present but no ## Evidence =="
nudges "inline --body"           'gh pr create --title "fix: x" --body "Fixes the thing"'
nudges "short -b"                'gh pr create -t "fix: x" -b "Fixes the thing"'
nudges "--body= form"            'gh pr create --body=Fixes-the-thing'
nudges "--body-file without it"  "gh pr create --body-file $BODY_BAD"
nudges "-F without it"           "gh pr create -F $BODY_BAD"
nudges "heredoc body"            'gh pr create --title "t" --body "$(cat <<EOF
Fixes the thing
EOF
)"'
nudges "draft PR"                'gh pr create --draft --title "t" --body "no proof"'
nudges "after cd"                'cd sub && gh pr create --title "t" --body "no proof"'
nudges "bash -c wrapper"         'bash -c '"'"'gh pr create --title "t" --body "no proof"'"'"''
nudges "env prefix"              'GH_TOKEN=x gh pr create --title "t" --body "no proof"'
nudges "absolute gh path"        '/usr/bin/gh pr create --title "t" --body "no proof"'
nudges "flags before subcommand" 'gh --repo o/r pr create --title "t" --body "no proof"'

echo
echo "== nudges: no inspectable body at all =="
nudges "--fill"                  'gh pr create --fill'
nudges "no body flag"            'gh pr create --title "fix: x"'
nudges "bare create"             'gh pr create'

echo
echo "== quiet: evidence section present =="
quiet "inline with marker"       'gh pr create --title "t" --body "Fix.

## Evidence
**Before:** crash
**After:** ok"'
quiet "--body-file with marker"  "gh pr create --body-file $BODY_OK"
quiet "-F with marker"           "gh pr create -F $BODY_OK"
quiet "heredoc with marker"      'gh pr create --title "t" --body "$(cat <<EOF
Fix.

## Evidence
**Before:** crash
**After:** ok
EOF
)"'
quiet "docs-only escape hatch"   'gh pr create --title "docs" --body "Typo.

## Evidence
None — comment-only change, no runtime surface."'

echo
echo "== quiet: not a gh pr create (false-positive guard) =="
quiet "gh pr view"               'gh pr view --json number'
quiet "gh pr edit"               'gh pr edit 12 --body "no proof"'
quiet "gh pr list"               'gh pr list'
quiet "gh repo view"             'gh repo view owner/repo'
quiet "git push"                 'git push origin main'
quiet "git commit"               'git commit -m "add gh pr create note"'
quiet "echo mentioning it"       'echo "run gh pr create --body later"'
quiet "unrelated build"          'npm run build'
quiet "gh pr create in a path"   'cat docs/gh-pr-create-guide.md'
quiet "unreadable --body-file"   "gh pr create --body-file $TMPDIR_T/does-not-exist.md"
quiet "body from stdin"          'gh pr create --body-file -'

echo
echo "== never blocks =="
exits_zero "missing evidence"    'gh pr create --title "t" --body "no proof"'
exits_zero "with evidence"       "gh pr create --body-file $BODY_OK"
exits_zero "unrelated command"   'git status'
exits_zero "unbalanced quotes"   'gh pr create --body "unterminated'
exits_zero "empty command"       ''

echo
printf 'passed %d, failed %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
