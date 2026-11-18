#!/usr/bin/env bash
# headless-envelope-hook.test.sh — prove the envelope fires ONLY for unattended runs.
#
# Run: bash hooks/claude/headless-envelope-hook.test.sh
#
# The hook is advisory (SessionStart stdout becomes context), so exit code is always 0.
# The observable is whether it printed. "emits" asserts output containing the banner;
# "silent" asserts zero bytes.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/headless-envelope-hook.sh"

PASS=0
FAIL=0

# Run the hook with a SessionStart-shaped payload on stdin and the given env.
# Usage: run_hook <label> [VAR=VAL ...]
run_hook() {
  printf '%s' '{"hook_event_name":"SessionStart","source":"startup","session_id":"t"}' \
    | env "$@" bash "$HOOK" 2>/dev/null
}

emits() {
  local label="$1"; shift
  local out
  out=$(run_hook "$@")
  if printf '%s' "$out" | grep -q 'UNATTENDED RUN'; then
    printf '  ok   EMIT    %-46s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL EMIT    %-46s :: no envelope in output\n' "$label"
    FAIL=$((FAIL + 1))
  fi
}

silent() {
  local label="$1"; shift
  local out
  out=$(run_hook "$@")
  if [ -z "$out" ]; then
    printf '  ok   SILENT  %-46s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL SILENT  %-46s :: printed %s bytes\n' "$label" "${#out}"
    FAIL=$((FAIL + 1))
  fi
}

contains() {
  local label="$1" needle="$2"; shift 2
  local out
  out=$(run_hook "$@")
  if printf '%s' "$out" | grep -qF "$needle"; then
    printf '  ok   RULE    %-46s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL RULE    %-46s :: missing %s\n' "$label" "$needle"
    FAIL=$((FAIL + 1))
  fi
}

echo "headless-envelope-hook — gate"

# --- Fires: the real unattended configuration -------------------------------
emits  "SDD_HEADLESS=1"                          SDD_HEADLESS=1
emits  "SDD_HEADLESS=1 + unrelated env"          SDD_HEADLESS=1 FOO=bar

# --- Silent: every interactive shape ----------------------------------------
silent "unset (normal interactive session)"      SDD_UNRELATED=1
silent "SDD_HEADLESS=0"                          SDD_HEADLESS=0
silent "SDD_HEADLESS empty"                      SDD_HEADLESS=
silent "SDD_HEADLESS=true (not the sentinel)"    SDD_HEADLESS=true
silent "SDD_HEADLESS=11 (no prefix match)"       SDD_HEADLESS=11

# --- Opt-out ----------------------------------------------------------------
silent "headless + explicit opt-out"             SDD_HEADLESS=1 SDD_SKIP_HEADLESS_ENVELOPE=1
emits  "opt-out=0 does not opt out"              SDD_HEADLESS=1 SDD_SKIP_HEADLESS_ENVELOPE=0

echo "headless-envelope-hook — envelope content"

contains "rule 1 present (one unit of work)"  "ONE UNIT OF WORK"          SDD_HEADLESS=1
contains "rule 2 present (no push/rewrite)"   "NO HISTORY-REWRITING"      SDD_HEADLESS=1
contains "rule 3 present (write lane)"        "WRITES STAY IN THE ROUTINE" SDD_HEADLESS=1
# Regression guard: harness-health-prompt.md tells the agent to rewrite SKILL.md files
# and daily-maintenance Step E drafts BEHAVIOR.md specs. Rule 3 must not contradict a
# routine's own explicit instruction, or the envelope breaks working routines.
contains "rule 3 defers to explicit prompt"   "UNLESS the routine prompt explicitly" SDD_HEADLESS=1
contains "rule 4 present (loop guard)"        "TWO-STRIKE LOOP GUARD"     SDD_HEADLESS=1
contains "rule 5 present (honest report)"     "REPORT HONESTLY"           SDD_HEADLESS=1
contains "rule 6 present (no new deps)"       "NO NEW DEPENDENCIES"       SDD_HEADLESS=1
contains "escalation framed as success"       "Escalating is a successful outcome" SDD_HEADLESS=1

echo "headless-envelope-hook — exit code"

# Must never block a session, in either mode.
printf '%s' '{}' | env SDD_HEADLESS=1 bash "$HOOK" >/dev/null 2>&1
rc_headless=$?
printf '%s' '{}' | env SDD_HEADLESS= bash "$HOOK" >/dev/null 2>&1
rc_interactive=$?
if [ "$rc_headless" -eq 0 ] && [ "$rc_interactive" -eq 0 ]; then
  printf '  ok   EXIT    %-46s\n' "exits 0 in both modes"
  PASS=$((PASS + 1))
else
  printf '  FAIL EXIT    %-46s :: headless=%s interactive=%s\n' \
    "exits 0 in both modes" "$rc_headless" "$rc_interactive"
  FAIL=$((FAIL + 1))
fi

# Stdin must be drained so a caller writing a large payload never blocks.
if head -c 200000 /dev/zero | env SDD_HEADLESS= bash "$HOOK" >/dev/null 2>&1; then
  printf '  ok   STDIN   %-46s\n' "drains large stdin without hanging"
  PASS=$((PASS + 1))
else
  printf '  FAIL STDIN   %-46s\n' "drains large stdin without hanging"
  FAIL=$((FAIL + 1))
fi

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
