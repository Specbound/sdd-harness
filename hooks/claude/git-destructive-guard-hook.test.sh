#!/usr/bin/env bash
# git-destructive-guard-hook.test.sh — prove the guard blocks destructive git/gh
# operations and does NOT block benign ones.
#
# Run: bash hooks/claude/git-destructive-guard-hook.test.sh
#
# The bypass cases below are the point of this file. The pre-2026-08 hook
# regex-stripped quotes and grepped the remaining text; every case in the
# "regex-era bypasses" block defeated it while remaining a real force-push.
# If a future edit reintroduces string matching, those cases fail first.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/git-destructive-guard-hook.sh"

PASS=0
FAIL=0

# Feed a command to the hook as a PreToolUse Bash event; echo its exit code.
run_hook() {
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
' "$1" | bash "$HOOK" >/dev/null 2>&1
  echo $?
}

blocks() {
  local label="$1" cmd="$2"
  local rc
  rc=$(run_hook "$cmd")
  if [ "$rc" = "2" ]; then
    printf '  ok    BLOCK  %-44s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  BLOCK  %-44s got exit %s, want 2 :: %s\n' "$label" "$rc" "$cmd"
    FAIL=$((FAIL + 1))
  fi
}

allows() {
  local label="$1" cmd="$2"
  local rc
  rc=$(run_hook "$cmd")
  if [ "$rc" = "0" ]; then
    printf '  ok    ALLOW  %-44s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  ALLOW  %-44s got exit %s, want 0 :: %s\n' "$label" "$rc" "$cmd"
    FAIL=$((FAIL + 1))
  fi
}

echo "== baseline blocks =="
blocks "plain force push"            'git push --force'
blocks "short -f"                    'git push -f origin main'
blocks "force-with-lease"            'git push --force-with-lease'
blocks "force-if-includes"           'git push --force-if-includes origin main'
blocks "force-with-lease w/ value"   'git push --force-with-lease=main origin'
blocks "short bundle -fu"            'git push -fu origin main'
blocks "remote delete --delete"      'git push --delete origin feature'
blocks "remote delete -d"            'git push -d origin feature'
blocks "mirror push"                 'git push --mirror origin'
blocks "empty refspec"               'git push origin :feature'
blocks "branch -D"                   'git branch -D feature'
blocks "branch --delete --force"     'git branch --delete --force feature'
blocks "gh repo delete"              'gh repo delete owner/repo'
blocks "git rebase"                  'git rebase main'
blocks "git rebase -i"               'git rebase -i HEAD~3'

echo
echo "== regex-era bypasses (each defeated the previous implementation) =="
blocks "variable-expanded flag"      'F=--force; git push $F'
blocks "bash -c wrapper"             "bash -c 'git push --force'"
blocks "sh -c wrapper"               "sh -c 'git push --force origin main'"
blocks "quote-split token"           'git push --fo""rce'
blocks "compound after cd"           'cd sub && git push --force'
blocks "compound with semicolon"     'echo hi; git push --force'
blocks "pipeline segment"            'true | git push --force'
blocks "git -C prefix"               'git -C /tmp/repo push --force'
blocks "git -c config prefix"        'git -c core.pager=cat push --force'
blocks "alias injection"             "git -c alias.p='push --force' p"
blocks "env prefix"                  'GIT_DIR=.git git push --force'
blocks "unresolved push expansion"   'git push $ARGS'
blocks "unresolved branch expansion" 'git branch $FLAG feature'
blocks "command substitution"        'git push $(cat flags.txt)'
blocks "nested bash -c compound"     "bash -c 'cd x && git push -f'"

echo
echo "== must NOT block (false-positive guard) =="
allows "normal push"                 'git push origin main'
allows "push -u"                     'git push -u origin feature'
allows "push no args"                'git push'
allows "commit msg mentions --force" 'git commit -m "document git push --force risks"'
allows "commit msg mentions -D"      'git commit -m "explain git branch -D behaviour"'
allows "commit body heredoc-ish"     'git commit -m "add --force-with-lease note"'
allows "safe branch delete"          'git branch -d merged-feature'
allows "branch list"                 'git branch -a'
allows "git status"                  'git status'
allows "git log with grep"           'git log --grep="Co-Authored-By: Claude"'
allows "gh repo view"                'gh repo view owner/repo'
allows "gh repo list"                'gh repo list'
allows "gh pr create"                'gh pr create --title "force push guard"'
allows "unrelated binary"            'rsync -f rules src dst'
allows "echo with force text"        'echo "never use git push --force here"'
allows "push with branch var"        'git push origin main --set-upstream'

echo
printf 'passed %d, failed %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
