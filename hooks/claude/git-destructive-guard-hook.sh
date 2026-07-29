#!/bin/bash
# Hard block on destructive git/gh operations, independent of settings.json's
# declarative allow/deny list — that list has been observed to NOT reliably block
# `git push --force` in some sessions even with an explicit deny entry present.
# This hook inspects the literal Bash command text and exits 2 (hard block, tool
# call is prevented) on any match. Soft nudges (protected-path-hook.sh) only warn;
# this hook is the one place in the harness that actually refuses to run.
#
# Blocks:
#   - any force-push variant: --force, --force-with-lease, --force-if-includes, -f
#   - remote branch deletion via push: --delete, or `git push origin :branch`
#   - mirror push (can delete/overwrite arbitrary remote refs)
#   - local force branch delete: git branch -D / --delete --force
#   - repo deletion: gh repo delete

EVENT=$(cat)
COMMAND=$(echo "$EVENT" | python3 -c "
import json, sys
try:
    e = json.load(sys.stdin)
    print(e.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

[ -z "$COMMAND" ] && exit 0

block() {
  echo "BLOCKED: destructive git/gh operation refused by git-destructive-guard-hook.sh" >&2
  echo "Reason: $1" >&2
  echo "Command: $COMMAND" >&2
  echo "If this is genuinely needed, ask the user to run it manually in their own shell." >&2
  exit 2
}

if echo "$COMMAND" | grep -qE 'git[[:space:]]+push' ; then
  if echo "$COMMAND" | grep -qE -- '--force-with-lease|--force-if-includes|--force\b|[[:space:]]-f([[:space:]]|$)'; then
    block "force-push variant detected"
  fi
  if echo "$COMMAND" | grep -qE -- '--delete|--mirror' ; then
    block "remote branch deletion or mirror-push detected"
  fi
  if echo "$COMMAND" | grep -qE ':[A-Za-z0-9._/-]+([[:space:]]|$)' && echo "$COMMAND" | grep -qE 'push[[:space:]]+[A-Za-z0-9._/-]+[[:space:]]+:[A-Za-z0-9._/-]*([[:space:]]|$)'; then
    block "empty-refspec remote branch deletion detected"
  fi
fi

if echo "$COMMAND" | grep -qE 'git[[:space:]]+branch[[:space:]]+.*(-D\b|--delete[[:space:]]+--force|--force[[:space:]]+--delete)'; then
  block "force local branch delete detected"
fi

if echo "$COMMAND" | grep -qE 'gh[[:space:]]+repo[[:space:]]+delete'; then
  block "repo deletion via gh CLI detected"
fi

exit 0
