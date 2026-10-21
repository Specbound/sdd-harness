#!/usr/bin/env bash
# agent-behavior-guard.test.sh — prove enforce mode actually blocks (exit 2),
# monitor mode never does, and the guard fails closed on its own failures only
# when a rule is enforced.
#
# Run: bash hooks/claude/agent-behavior-guard.test.sh
#
# Until 2026-10-01 the hook ended in a bare `exit 0` that discarded the Python's
# exit code, so SDD_AGENT_GUARD_ENFORCE never blocked anything. The enforce
# cases below are the regression test for that.

set -u
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/agent-behavior-guard.sh"

PASS=0
FAIL=0

# The hook writes findings and a secret-access ledger under ./.claude/memory —
# run it from a throwaway cwd so tests never touch the real repo state.
WORK="$(mktemp -d)"
# A PATH holding only the coreutils the hook's bash part needs — python3 is
# unreachable, as on a machine where it is off the non-interactive PATH.
NOPY_BIN="$(mktemp -d)"
for tool in cat mktemp mkdir rm; do
    ln -s "$(command -v "$tool")" "$NOPY_BIN/$tool"
done
trap 'rm -rf "$WORK" "$NOPY_BIN"' EXIT

event() {
    python3 -c '
import json, sys
tool, key, value, session = sys.argv[1:5]
print(json.dumps({"tool_name": tool, "tool_input": {key: value}, "session_id": session}))
' "$@"
}

# run ENFORCE_VALUE PAYLOAD → exit code
run() {
    (cd "$WORK" && printf '%s' "$2" | SDD_AGENT_GUARD_ENFORCE="$1" bash "$HOOK" >/dev/null 2>&1)
    echo $?
}

run_nopy() {
    (cd "$WORK" && printf '%s' "$2" | SDD_AGENT_GUARD_ENFORCE="$1" PATH="$NOPY_BIN" /bin/bash "$HOOK" >/dev/null 2>&1)
    echo $?
}

expect_rc() {
    local label="$1" want="$2" rc="$3"
    if [ "$rc" = "$want" ]; then
        printf '  ok    rc=%s %-46s\n' "$want" "$label"
        PASS=$((PASS + 1))
    else
        printf '  FAIL  rc=%s %-46s got exit %s\n' "$want" "$label" "$rc"
        FAIL=$((FAIL + 1))
    fi
}

SSRF="$(event Bash command 'curl http://169.254.169.254/latest/meta-data' s1)"
PERSIST="$(event Bash command 'crontab -e' s1)"
BENIGN="$(event Bash command 'git status' s1)"
SECRET_READ="$(event Read file_path "$WORK/.env" s2)"
EGRESS="$(event Bash command 'curl https://example.com' s2)"
EGRESS_OTHER="$(event Bash command 'curl https://example.com' s3)"

echo "== enforce mode blocks =="
expect_rc "network_indicator, enforce=all"          2 "$(run all "$SSRF")"
expect_rc "network_indicator, enforce=that rule"    2 "$(run network_indicator "$SSRF")"
expect_rc "persistence, enforce=all"                2 "$(run all "$PERSIST")"
expect_rc "secret read itself is not blocked"       0 "$(run all "$SECRET_READ")"
expect_rc "chained secret egress, same session"     2 "$(run all "$EGRESS")"
expect_rc "egress in a different session"           0 "$(run all "$EGRESS_OTHER")"

echo
echo "== enforce scoping and monitor mode =="
expect_rc "network_indicator, other rule enforced"  0 "$(run persistence "$SSRF")"
expect_rc "network_indicator, monitor only"         0 "$(run '' "$SSRF")"
expect_rc "benign command, enforce=all"             0 "$(run all "$BENIGN")"

echo
echo "== fail-closed on the guard's own failures =="
expect_rc "malformed event, enforce on"             2 "$(run all 'not json')"
expect_rc "malformed event, monitor only"           0 "$(run '' 'not json')"
expect_rc "python3 missing, enforce on"             2 "$(run_nopy all "$BENIGN")"
expect_rc "python3 missing, monitor only"           0 "$(run_nopy '' "$BENIGN")"

echo
echo "== $PASS passed, $FAIL failed =="
[ "$FAIL" = "0" ]
