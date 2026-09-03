#!/usr/bin/env bash
# todo-focus-hook.test.sh — prove the single-active-todo gate fires on 2+
# in_progress entries and stays silent otherwise.
#
# Run: bash hooks/claude/todo-focus-hook.test.sh
#
# The exit code is the contract, not the text. PostToolUse hooks that exit 0
# have their stderr swallowed into the debug log, so a nudge on exit 0 would be
# invisible to Claude — a hook that looks like it works and does nothing. Case
# "warns on 2 in_progress" therefore asserts exit 2 specifically; if a future
# edit softens it to exit 0, that case fails first and says why.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/todo-focus-hook.sh"
PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s%s\n' "$1" "${2:+ — $2}"; }

# $1=label $2=expected exit $3=json payload
expect_rc() {
  local label="$1" want="$2" payload="$3" rc
  printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq "$want" ]; then ok "$label"
  else bad "$label" "expected exit $want, got $rc"; fi
}

todo() { printf '{"content":"%s","status":"%s","activeForm":"doing %s"}' "$1" "$2" "$1"; }
payload() { printf '{"tool_name":"TodoWrite","tool_input":{"todos":[%s]}}' "$1"; }

echo "todo-focus-hook"

ONE="$(todo A in_progress),$(todo B pending),$(todo C completed)"
TWO="$(todo A in_progress),$(todo B in_progress),$(todo C pending)"
THREE="$(todo A in_progress),$(todo B in_progress),$(todo C in_progress)"
NONE="$(todo A pending),$(todo B completed)"

expect_rc "silent on exactly 1 in_progress"  0 "$(payload "$ONE")"
expect_rc "silent on 0 in_progress"          0 "$(payload "$NONE")"
expect_rc "silent on an empty todo list"     0 '{"tool_name":"TodoWrite","tool_input":{"todos":[]}}'
expect_rc "warns on 2 in_progress (exit 2)"  2 "$(payload "$TWO")"
expect_rc "warns on 3 in_progress (exit 2)"  2 "$(payload "$THREE")"

# ── Message names the competing items ─────────────────────────────────────────
ERR="$(printf '%s' "$(payload "$TWO")" | bash "$HOOK" 2>&1 >/dev/null)"
for needle in "A" "B" "todo-focus"; do
  if printf '%s' "$ERR" | grep -q -- "$needle"; then
    ok "message mentions '$needle'"
  else
    bad "message mentions '$needle'" "stderr was: $(printf '%s' "$ERR" | head -c 100)"
  fi
done
if printf '%s' "$ERR" | grep -q "C"; then
  bad "message lists only in_progress items" "pending item C leaked into the warning"
else
  ok "message lists only in_progress items"
fi

# ── Inert outside its matcher and on junk ─────────────────────────────────────
expect_rc "inert on a non-TodoWrite tool" 0 \
  '{"tool_name":"Bash","tool_input":{"todos":[{"content":"A","status":"in_progress"},{"content":"B","status":"in_progress"}]}}'
expect_rc "inert on malformed JSON"       0 'not json at all'
expect_rc "inert on empty stdin"          0 ''
expect_rc "inert when todos key is absent" 0 '{"tool_name":"TodoWrite","tool_input":{}}'

# ── Opt-out ───────────────────────────────────────────────────────────────────
printf '%s' "$(payload "$TWO")" | SDD_SKIP_TODO_FOCUS=1 bash "$HOOK" >/dev/null 2>&1
if [ $? -eq 0 ]; then ok "SDD_SKIP_TODO_FOCUS=1 disables the gate"
else bad "SDD_SKIP_TODO_FOCUS=1 disables the gate"; fi

# ── Never stalls on an open, silent stdin ─────────────────────────────────────
FIFO="$(mktemp -u)"
mkfifo "$FIFO"
sleep 10 > "$FIFO" &
HOLDER=$!
bash "$HOOK" < "$FIFO" >/dev/null 2>&1 &
HOOKPID=$!
STALLED=yes
for _ in $(seq 1 12); do
  if ! kill -0 "$HOOKPID" 2>/dev/null; then STALLED=no; break; fi
  sleep 0.5
done
if [ "$STALLED" = "yes" ]; then
  kill -9 "$HOOKPID" 2>/dev/null || true
  bad "terminates on an open, silent stdin"
else
  ok "terminates on an open, silent stdin"
fi
kill "$HOLDER" 2>/dev/null || true
wait "$HOLDER" 2>/dev/null || true
rm -f "$FIFO"

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
