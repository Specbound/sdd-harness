#!/usr/bin/env bash
# runner-cadence.test.sh — every routine runner must be able to read its own stamp.
#
# Run: bash scripts/routines/runner-cadence.test.sh
#
# Runners write their last-run stamp with `date -Iseconds` ("...+02:00") and gate
# on it with MIN_GAP_DAYS. Eight runners parsed it with BSD `date -j -f ...%z`,
# which rejects the colon; on macOS every parse fell back to epoch 0 and the gate
# never skipped, so weekly sweeps ran daily. skill-curator found and fixed this in
# 2026-08 for itself only. This checks every runner — present and future — at once:
# its LAST_EPOCH line, run against a fresh stamp, must give a time within a minute
# of now. A new runner copying the old pattern fails here.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PASS=0
FAIL=0
STAMP="$(date -Iseconds)"
NOW="$(date +%s)"

for runner in "$__here"/*-runner.sh; do
  name="$(basename "$runner")"
  line="$(grep -m1 '^ *LAST_EPOCH=' "$runner" || true)"
  [ -n "$line" ] || continue   # no cadence gate in this runner
  epoch="$(LAST_RAW="$STAMP" bash -c "$line"'; echo "$LAST_EPOCH"' 2>/dev/null)"
  if [ -n "$epoch" ] && [ "$epoch" -gt 0 ] && [ $(( NOW - epoch )) -lt 60 ] && [ $(( epoch - NOW )) -lt 60 ]; then
    printf '  ok   %s parses "%s"\n' "$name" "$STAMP"; PASS=$((PASS + 1))
  else
    printf '  FAIL %s :: LAST_EPOCH=%s for stamp %s\n' "$name" "${epoch:-empty}" "$STAMP"; FAIL=$((FAIL + 1))
  fi
done

echo
echo "$PASS passed, $FAIL failed"
[ "$PASS" -gt 0 ] && [ "$FAIL" -eq 0 ]
