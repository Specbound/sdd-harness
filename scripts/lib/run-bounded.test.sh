#!/usr/bin/env bash
# run-bounded.test.sh — prove run_bounded passes a healthy step through untouched
# and kills a hung one, children included.
#
# Run: bash scripts/lib/run-bounded.test.sh   (~15s — two cases wait out a 1s budget
# and one waits out the 10s TERM→KILL grace)
#
# The child-process case is the one that matters: a hung step is a `claude --print`
# under a runner's bash, and killing only the bash would leave it running.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/run-bounded.sh"

PASS=0
FAIL=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf '  ok    %-46s %s\n' "$label" "$actual"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %-46s got [%s] want [%s]\n' "$label" "$actual" "$expected"
    FAIL=$((FAIL + 1))
  fi
}

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

echo "passthrough"
check "stdout" "$(run_bounded echo hello)" "hello"
check "stdin" "$(echo piped | run_bounded cat)" "piped"
# The orchestrator copies a failed step's stderr into orchestrator-errors.log, so any
# noise from the wrapper itself would sit on top of every real error.
check "healthy step stderr is silent" "$(run_bounded true 2>&1)" ""
run_bounded bash -c 'exit 3'
check "exit status" "$?" "3"
run_bounded bash -c 'kill -9 $$'
check "signal death is 128+N" "$?" "137"
run_bounded /nonexistent/cmd 2>/dev/null
check "missing command" "$?" "127"

echo "budget"
start=$(date +%s)
SDD_STEP_BUDGET_S=1 run_bounded bash -c 'sleep 30' 2>"$T/err"
rc=$?
check "expiry exits 124" "$rc" "124"
check "expiry is prompt" "$([ $(( $(date +%s) - start )) -lt 8 ] && echo yes || echo no)" "yes"
case "$(cat "$T/err")" in *"exceeded 1s budget"*) said=yes ;; *) said=no ;; esac
check "expiry says so on stderr" "$said" "yes"

# The runner's bash backgrounds a long child and waits on it — the hung-claude shape.
SDD_STEP_BUDGET_S=1 run_bounded bash -c 'sleep 300 & echo $! > "$1"; wait' _ "$T/child" 2>/dev/null
sleep 1
check "child process killed too" "$(kill -0 "$(cat "$T/child")" 2>/dev/null && echo alive || echo dead)" "dead"

start=$(date +%s)
SDD_STEP_BUDGET_S=1 run_bounded perl -e '$SIG{TERM} = "IGNORE"; sleep 300' 2>/dev/null
rc=$?
check "TERM-ignoring step gets KILL" "$rc" "124"
check "KILL follows within grace" "$([ $(( $(date +%s) - start )) -lt 20 ] && echo yes || echo no)" "yes"

echo "config"
check "off runs unbounded" "$(SDD_STEP_BUDGET_S=off run_bounded echo x)" "x"
SDD_STEP_BUDGET_S=2h run_bounded true 2>/dev/null
check "non-integer budget refused" "$?" "2"
SDD_STEP_BUDGET_S=0 run_bounded true 2>/dev/null
check "zero budget refused" "$?" "2"

echo ""
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
