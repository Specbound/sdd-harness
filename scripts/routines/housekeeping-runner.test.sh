#!/usr/bin/env bash
# housekeeping-runner.test.sh — prove weekly housekeeping runs only where it should.
#
# Run: bash scripts/routines/housekeeping-runner.test.sh
#
# `claude` is stubbed on PATH: it records that it ran (and its prompt) and exits
# with $STUB_EXIT, so no session is started and nothing is spent.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
RUNNER="$__here/housekeeping-runner.sh"

PASS=0
FAIL=0
ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL %s :: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/housekeeping-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/claude-config/projects"
cat > "$TMP/bin/claude" <<'STUB'
#!/bin/bash
cat > "$STUB_LOG"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$TMP/bin/claude"

# new_repo <name> <days-ago-of-only-commit> — a repo with memory, the command
# file, and one commit dated that many days ago.
new_repo() {
  local r="$TMP/$1"
  mkdir -p "$r/.claude/memory" "$r/.claude/commands/kiro"
  echo "# housekeeping" > "$r/.claude/commands/kiro/housekeeping.md"
  echo "# Hot Memory" > "$r/.claude/memory/hot-memory.md"
  local when
  when="$(python3 -c 'import sys,time; print(time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(time.time()-int(sys.argv[1])*86400)))' "$2")"
  (cd "$r" && git init -q && git config user.email t@t && git config user.name t \
    && echo x > f && git add f \
    && GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git commit -qm init)
  echo "$r"
}

# run <repo> [VAR=VAL ...] — run the runner; sets RAN=1 when claude was invoked
run() {
  local r="$1"; shift
  rm -f "$TMP/stub.log"
  (cd "$r" && env PATH="$TMP/bin:$PATH" CLAUDE_CONFIG_DIR="$TMP/claude-config" \
     STUB_LOG="$TMP/stub.log" "$@" bash "$RUNNER") > /dev/null 2>"$TMP/err.log"
  RC=$?
  RAN=0; [ -f "$TMP/stub.log" ] && RAN=1
}

echo "== activity"
R="$(new_repo active 2)"
run "$R"
[ "$RAN" = 1 ] && [ "$RC" = 0 ] && ok "recent commit → runs" || fail "recent commit" "ran=$RAN rc=$RC $(cat "$TMP/err.log")"
[ -s "$R/.claude/memory/.last-housekeeping" ] && ok "success writes the last-run stamp" || fail "stamp" "missing"
grep -qF "$(cd "$R" && pwd -P)" "$TMP/stub.log" && grep -qF "8000 bytes" "$TMP/stub.log" \
  && ok "prompt names this repo and the byte cap" || fail "prompt" "$(cat "$TMP/stub.log")"

R2="$(new_repo idle 40)"
run "$R2"
[ "$RAN" = 0 ] && [ "$RC" = 0 ] && grep -q "inactive" "$TMP/err.log" \
  && ok "no commit or session in 14d → skipped" || fail "inactive skip" "ran=$RAN"

slug="$(cd "$R2" && pwd -P | python3 -c 'import sys; print("".join(c if c.isalnum() or c=="-" else "-" for c in sys.stdin.read().strip()))')"
mkdir -p "$TMP/claude-config/projects/$slug"
echo '{"type":"user","entrypoint":"sdk-cli"}' > "$TMP/claude-config/projects/$slug/routine.jsonl"
run "$R2"
[ "$RAN" = 0 ] && ok "headless routine session (sdk-cli) does not count as activity" || fail "sdk-cli counted" "ran=$RAN"
echo '{"type":"user","entrypoint":"claude-vscode"}' > "$TMP/claude-config/projects/$slug/real.jsonl"
run "$R2"
[ "$RAN" = 1 ] && ok "interactive session → runs" || fail "session activity" "$(cat "$TMP/err.log")"

R3="$(new_repo bloated 40)"
python3 -c 'import sys; open(sys.argv[1], "w").write("x" * 9000)' "$R3/.claude/memory/hot-memory.md"
run "$R3"
[ "$RAN" = 1 ] && ok "hot-memory over byte cap → runs even when idle" || fail "over cap" "$(cat "$TMP/err.log")"

echo "== cadence"
run "$R"
[ "$RAN" = 0 ] && grep -q "skipping" "$TMP/err.log" && ok "second run within 7d → skipped" || fail "cadence" "ran=$RAN"
run "$R" HOUSEKEEPING_FORCE=1
[ "$RAN" = 1 ] && ok "HOUSEKEEPING_FORCE=1 overrides cadence" || fail "force" "ran=$RAN"
python3 -c 'import time; print(time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(time.time()-8*86400)))' \
  > "$R/.claude/memory/.last-housekeeping"
run "$R"
[ "$RAN" = 1 ] && ok "last run 8d ago → runs" || fail "8d gap" "$(cat "$TMP/err.log")"

echo "== failure and safety"
R4="$(new_repo failing 1)"
run "$R4" STUB_EXIT=1
[ "$RC" = 1 ] && [ ! -f "$R4/.claude/memory/.last-housekeeping" ] \
  && ok "failed run → exit 1, no stamp (retries tomorrow)" || fail "failure stamp" "rc=$RC"
run "$R4"
[ "$RAN" = 1 ] && ok "next day's tick retries it" || fail "retry" "ran=$RAN"

R5="$(new_repo locked 1)"; mkdir "$R5/.claude/memory/.housekeeping.lock"
run "$R5"
[ "$RAN" = 0 ] && grep -q "another housekeeping run active" "$TMP/err.log" \
  && ok "held lock → skipped" || fail "lock" "ran=$RAN"

R6="$TMP/bare"; mkdir -p "$R6"
run "$R6"
[ "$RAN" = 0 ] && [ "$RC" = 0 ] && ok "no .claude/memory → skipped" || fail "bare repo" "rc=$RC"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
