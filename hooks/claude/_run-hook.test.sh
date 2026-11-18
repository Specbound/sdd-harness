#!/usr/bin/env bash
# _run-hook.test.sh — prove the hook wrapper is invisible to Claude Code and logs every run.
#
# Run: bash hooks/claude/_run-hook.test.sh
#
# The wrapper sits in front of every hook, so the bar is "changes nothing":
# stdin, stdout, stderr, exit code and cwd must match a direct run exactly.
# Logging is checked separately, including that a broken log never leaks.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
WRAPPER="$__here/_run-hook.sh"

PASS=0
FAIL=0

ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL %s :: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# A throwaway project: <tmp>/proj/.claude/hooks/ holds the wrapper and fake hooks,
# so the wrapper derives <tmp>/proj as the project root, exactly as when installed.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/run-hook-test.XXXXXX")"
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"
HOOKS="$PROJ/.claude/hooks"
LOG="$PROJ/.claude/logs/hook-runs.jsonl"
mkdir -p "$HOOKS"
cp "$WRAPPER" "$HOOKS/_run-hook.sh"

printf '#!/bin/bash\ncat\n'                                   > "$HOOKS/echo-hook.sh"
printf '#!/bin/bash\ncat >/dev/null\necho "denied" >&2\nexit 2\n' > "$HOOKS/block-hook.sh"
printf '#!/bin/bash\nexit 1\n'                                > "$HOOKS/err-hook.sh"
printf '#!/bin/bash\nexit 0\n'                                > "$HOOKS/silent-hook.sh"
printf '#!/bin/bash\ncat >/dev/null\npwd\n'                   > "$HOOKS/pwd-hook.sh"

PAYLOAD='{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"s1","tool_input":{"command":"ls"}}'

wrap() { bash "$HOOKS/_run-hook.sh" "$@"; }

# The logger runs in the background, so lines from earlier cases can land late
# and in any order. Each logging case therefore uses its own session id and
# finds its line by that id, never by position.
payload_for() { printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"%s"}' "$1"; }

# field <session> <key> — one key from the log line for that session ("" if absent)
field() {
  [ -f "$LOG" ] || return 0
  python3 -c '
import json, sys
for line in open(sys.argv[1], encoding="utf-8"):
    rec = json.loads(line)
    if rec.get("session") == sys.argv[2]:
        v = rec.get(sys.argv[3])
        print("null" if v is None else v)
        break
' "$LOG" "$1" "$2"
}

# wait_for <session> — up to ~3s for that session's line to appear
wait_for() {
  local i=0
  while [ $i -lt 30 ]; do
    [ -n "$(field "$1" hook)" ] && return 0
    sleep 0.1; i=$((i + 1))
  done
  return 1
}

# Count lines whose hook is <name> (opt-out check).
count_hook() {
  [ -f "$LOG" ] || { echo 0; return; }
  python3 -c '
import json, sys
print(sum(1 for l in open(sys.argv[1], encoding="utf-8") if json.loads(l).get("hook") == sys.argv[2]))
' "$LOG" "$1"
}

echo "== passthrough"

# stdout byte-exact, including trailing newlines $(...) would strip
printf '%s\n\n' "$PAYLOAD" | wrap bash "$HOOKS/echo-hook.sh" > "$TMP/out.bin"
printf '%s\n\n' "$PAYLOAD" > "$TMP/want.bin"
if cmp -s "$TMP/out.bin" "$TMP/want.bin"; then ok "stdin reaches hook and stdout returns byte-exact"
else fail "stdin/stdout byte-exact" "output differs from input"; fi

# exit codes
printf '%s' "$PAYLOAD" | wrap bash "$HOOKS/block-hook.sh" >/dev/null 2>"$TMP/err.txt"; rc=$?
[ "$rc" -eq 2 ] && ok "exit 2 (block) passes through" || fail "exit 2 passes through" "got $rc"
[ "$(cat "$TMP/err.txt")" = "denied" ] && ok "stderr passes through unchanged" || fail "stderr passthrough" "got '$(cat "$TMP/err.txt")'"

printf '%s' "$PAYLOAD" | wrap bash "$HOOKS/err-hook.sh" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "exit 1 (error) passes through" || fail "exit 1 passes through" "got $rc"

out="$(printf '%s' "$PAYLOAD" | wrap bash "$HOOKS/silent-hook.sh" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "silent hook stays silent (wrapper prints nothing)" \
  || fail "silent hook stays silent" "rc=$rc, printed ${#out} bytes"

# cwd unchanged
mkdir -p "$TMP/elsewhere"
out="$(cd "$TMP/elsewhere" && printf '%s' "$PAYLOAD" | wrap bash "$HOOKS/pwd-hook.sh")"
[ "$out" = "$(cd "$TMP/elsewhere" && pwd)" ] && ok "hook runs in the caller's cwd" || fail "cwd unchanged" "got $out"

# large payload intact
python3 -c 'import json; print(json.dumps({"hook_event_name":"PostToolUse","tool_input":{"content":"x"*300000}}))' > "$TMP/big.json"
wrap bash "$HOOKS/echo-hook.sh" < "$TMP/big.json" > "$TMP/big.out"
cmp -s "$TMP/big.json" "$TMP/big.out" && ok "300KB payload arrives intact" || fail "large payload" "differs"

# no command → no-op
out="$(printf '%s' "$PAYLOAD" | bash "$HOOKS/_run-hook.sh" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "no command → exit 0, silent" || fail "no command" "rc=$rc out=$out"

echo "== logging"

payload_for log-block | wrap bash "$HOOKS/block-hook.sh" >/dev/null 2>&1
if wait_for log-block; then
  [ "$(field log-block hook)" = "block-hook.sh" ] && ok "log names the hook script" || fail "log hook" "$(field log-block hook)"
  [ "$(field log-block event)" = "PreToolUse" ]   && ok "log records the event"     || fail "log event" "$(field log-block event)"
  [ "$(field log-block tool)" = "Bash" ]          && ok "log records the tool"      || fail "log tool" "$(field log-block tool)"
  [ "$(field log-block exit)" = "2" ]             && ok "log records exit 2"        || fail "log exit" "$(field log-block exit)"
else
  fail "log line written" "no line for session log-block in $LOG"
fi

# a command with no script file keeps its subcommand in the name
payload_for log-binary | wrap true hook observe
wait_for log-binary && [ "$(field log-binary hook)" = "true hook observe" ] \
  && ok "binary hook logged with its subcommand" || fail "binary hook name" "$(field log-binary hook)"

payload_for log-silent | wrap bash "$HOOKS/silent-hook.sh"
wait_for log-silent && [ "$(field log-silent exit)" = "0" ] \
  && ok "silent run is logged (the gap transcripts leave)" || fail "silent run logged" "no line"

# a non-JSON payload is still logged, never fatal
before="$(count_hook err-hook.sh)"
printf 'not json' | wrap bash "$HOOKS/err-hook.sh" >/dev/null 2>&1; rc=$?
i=0; while [ $i -lt 30 ] && [ "$(count_hook err-hook.sh)" = "$before" ]; do sleep 0.1; i=$((i + 1)); done
[ "$rc" -eq 1 ] && [ "$(count_hook err-hook.sh)" -gt "$before" ] \
  && ok "non-JSON payload still logged, exit unchanged" || fail "non-JSON payload" "rc=$rc"

# opt-out: pwd-hook is never run with logging after this point
before="$(count_hook pwd-hook.sh)"
payload_for opt-out | SDD_HOOK_LOG=0 wrap bash "$HOOKS/pwd-hook.sh" >/dev/null
sleep 0.5
[ "$(count_hook pwd-hook.sh)" = "$before" ] && [ -z "$(field opt-out hook)" ] \
  && ok "SDD_HOOK_LOG=0 writes nothing" || fail "opt-out" "log grew"

# unwritable log dir: hook result unchanged, nothing leaks to stdout/stderr
chmod a-w "$PROJ/.claude/logs"
out="$(printf '%s' "$PAYLOAD" | wrap bash "$HOOKS/echo-hook.sh" 2>"$TMP/err2.txt")"; rc=$?
sleep 0.3
chmod u+w "$PROJ/.claude/logs"
if [ "$rc" -eq 0 ] && [ "$out" = "$PAYLOAD" ] && [ ! -s "$TMP/err2.txt" ]; then
  ok "unwritable log: hook output and exit unchanged, nothing leaked"
else
  fail "unwritable log" "rc=$rc stderr=$(cat "$TMP/err2.txt")"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
