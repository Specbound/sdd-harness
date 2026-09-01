#!/usr/bin/env bash
# subagent-context-hook.test.sh — prove the SubagentStart hook emits valid
# additionalContext JSON and can never stall a subagent spawn.
#
# Run: bash hooks/claude/subagent-context-hook.test.sh
#
# The stall case is the important one. ponytail hit exactly this (their #443):
# a SubagentStart hook that waits on stdin hangs the spawn when the wrapper
# never closes the pipe. The hook must always terminate, even with a stdin that
# is open and silent, so case 5 runs it against a pipe nothing is written to.
#
# The other cases guard the mechanism itself: plain stdout is NOT injected for
# this event, so if a future edit replaces the jq output with `cat << RULES`,
# the JSON-shape cases fail first and say why.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/subagent-context-hook.sh"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s%s\n' "$1" "${2:+ — $2}"; }

check() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then ok "$label"
  else bad "$label" "expected '$expected', got '$actual'"; fi
}

echo "subagent-context-hook"

# ── 1. Valid JSON on stdout ───────────────────────────────────────────────────
OUT="$(printf '{"hook_event_name":"SubagentStart","agent_type":"Explore"}' | bash "$HOOK" 2>/dev/null)"
if printf '%s' "$OUT" | jq -e . >/dev/null 2>&1; then
  ok "emits parseable JSON"
else
  bad "emits parseable JSON" "got: $(printf '%s' "$OUT" | head -c 120)"
fi

# ── 2. Correct output shape ───────────────────────────────────────────────────
check "hookEventName is SubagentStart" \
  "SubagentStart" \
  "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName // "MISSING"')"

HAS_CTX="$(printf '%s' "$OUT" | jq -r 'if (.hookSpecificOutput.additionalContext // "" | length) > 200 then "yes" else "no" end')"
check "additionalContext is populated" "yes" "$HAS_CTX"

# ── 3. Load-bearing rules actually present ────────────────────────────────────
CTX="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext')"
for needle in "ctx_read" "serena" "gitnexus" "regex" "Husband"; do
  if printf '%s' "$CTX" | grep -qi -- "$needle"; then
    ok "injects rule mentioning '$needle'"
  else
    bad "injects rule mentioning '$needle'" "absent from additionalContext"
  fi
done

# ── 4. agent_type is echoed when supplied, absent when not ────────────────────
if printf '%s' "$CTX" | grep -q "subagent: Explore"; then
  ok "tags context with agent_type when present"
else
  bad "tags context with agent_type when present"
fi

OUT_NOAGENT="$(printf '{"hook_event_name":"SubagentStart"}' | bash "$HOOK" 2>/dev/null)"
CTX_NOAGENT="$(printf '%s' "$OUT_NOAGENT" | jq -r '.hookSpecificOutput.additionalContext // ""')"
if printf '%s' "$CTX_NOAGENT" | grep -q "subagent: "; then
  bad "omits the agent tag when agent_type is absent"
else
  ok "omits the agent tag when agent_type is absent"
fi

# ── 5. Never stalls on an open, silent stdin ──────────────────────────────────
# A FIFO that is held open and never written to. If the hook blocks on read,
# this case hangs forever, which is the failure it exists to catch — so it is
# bounded from outside by a background killer rather than by trusting the hook.
FIFO="$(mktemp -u)"
mkfifo "$FIFO"
sleep 10 > "$FIFO" &      # holds the write end open, sends nothing
HOLDER=$!
bash "$HOOK" < "$FIFO" > /dev/null 2>&1 &
HOOKPID=$!
STALLED=yes
for _ in $(seq 1 12); do
  if ! kill -0 "$HOOKPID" 2>/dev/null; then STALLED=no; break; fi
  sleep 0.5
done
if [ "$STALLED" = "yes" ]; then
  kill -9 "$HOOKPID" 2>/dev/null || true
  bad "terminates on an open, silent stdin" "still running after 6s — would stall the spawn"
else
  ok "terminates on an open, silent stdin"
fi
kill "$HOLDER" 2>/dev/null || true
wait "$HOLDER" 2>/dev/null || true
rm -f "$FIFO"

# ── 6. Malformed stdin degrades, never crashes ────────────────────────────────
OUT_BAD="$(printf 'not json at all' | bash "$HOOK" 2>/dev/null)"; RC=$?
check "exit 0 on malformed stdin" "0" "$RC"
if printf '%s' "$OUT_BAD" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
  ok "still injects context on malformed stdin"
else
  bad "still injects context on malformed stdin"
fi

# ── 7. Opt-out honoured ───────────────────────────────────────────────────────
OUT_OFF="$(printf '{"agent_type":"Explore"}' | SDD_SKIP_SUBAGENT_CONTEXT=1 bash "$HOOK" 2>/dev/null)"
check "SDD_SKIP_SUBAGENT_CONTEXT=1 emits nothing" "" "$OUT_OFF"

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
