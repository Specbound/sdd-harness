#!/usr/bin/env bash
# Tests for scripts/utils/check-hook-tests.py.
#
# The guard's value is that it fails on a NEW untested blocking hook and on a
# STALE ledger entry, so most cases plant one and assert a non-zero exit.
#
# Offline; every fixture lives in a temp git repo with its own copy of the
# guard (the ledger path is resolved next to the script), never the real tree.
#     bash scripts/utils/check-hook-tests.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
GUARD_SRC="$SCRIPT_DIR/check-hook-tests.py"

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }

[ -f "$GUARD_SRC" ] || { echo "missing: $GUARD_SRC"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# fresh_repo -> empty repo at $WORK/repo with the guard and an empty ledger
fresh_repo() {
    rm -rf "$WORK/repo"
    mkdir -p "$WORK/repo/hooks/claude" "$WORK/repo/scripts/utils"
    git -C "$WORK/repo" init -q
    cp "$GUARD_SRC" "$WORK/repo/scripts/utils/check-hook-tests.py"
    : > "$WORK/repo/scripts/utils/hook-test-debt.txt"
}

# hook <name> <content>  -> writes hooks/claude/<name>.sh
hook() { printf '%s\n' "$2" > "$WORK/repo/hooks/claude/$1.sh"; }
# give_test <name>       -> writes hooks/claude/<name>.test.sh
give_test() { printf 'true\n' > "$WORK/repo/hooks/claude/$1.test.sh"; }
# ledger <line>          -> appends to the fixture ledger
ledger() { printf '%s\n' "$1" >> "$WORK/repo/scripts/utils/hook-test-debt.txt"; }

# check <label> <expected_exit>
check() {
    local label="$1" want="$2" out got
    out="$(cd "$WORK/repo" && python3 scripts/utils/check-hook-tests.py 2>&1)"
    got=$?
    if [ "$got" -eq "$want" ]; then
        ok "$label"
    else
        bad "$label" "expected exit $want, got $got — $out"
    fi
}

echo "detection"

fresh_repo
hook advisory 'echo "consider checking X"
exit 0'
check "advisory-only hook needs no test" 0

fresh_repo
hook blocker 'echo nope >&2
exit 2'
check "exit 2 hook without test fails" 1

fresh_repo
hook blocker 'echo nope >&2
exit 2'
give_test blocker
check "exit 2 hook with sibling test passes" 0

fresh_repo
hook denier 'cat <<JSON
{"hookSpecificOutput": {"permissionDecision": "deny"}}
JSON'
check "permissionDecision deny without test fails" 1

fresh_repo
hook asker 'echo {"permissionDecision":"ask"}'
check "permissionDecision ask (no space) without test fails" 1

fresh_repo
hook stopper 'echo {"decision": "block", "reason": "x"}'
check "decision block without test fails" 1

echo "false positives"

fresh_repo
hook commented '# this hook used to exit 2 on failure
exit 0'
check "exit 2 inside a comment is ignored" 0

fresh_repo
hook twenty 'exit 20'
check "exit 20 is not exit 2" 0

fresh_repo
hook blocker 'exit 2'
printf 'exit 2\n' > "$WORK/repo/hooks/claude/blocker-x.test.sh"
give_test blocker
check "*.test.sh files are never treated as hooks" 0

echo "ledger"

fresh_repo
hook blocker 'exit 2'
ledger 'hooks/claude/blocker.sh'
check "untested hook on the ledger is debt, not failure" 0

fresh_repo
hook blocker 'exit 2'
give_test blocker
ledger 'hooks/claude/blocker.sh'
check "ledger entry for a now-tested hook is stale" 1

fresh_repo
hook softened 'exit 0'
ledger 'hooks/claude/softened.sh'
check "ledger entry for a hook that no longer blocks is stale" 1

fresh_repo
ledger '# comment only'
ledger ''
check "comments and blank lines in the ledger are ignored" 0

echo
echo "check-hook-tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
