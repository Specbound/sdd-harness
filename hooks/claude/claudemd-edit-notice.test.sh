#!/usr/bin/env bash
# claudemd-edit-notice.test.sh — prove the stale-instruction-file notice fires
# on CLAUDE.md / AGENTS.md writes and stays silent on everything else.
#
# Run: bash hooks/claude/claudemd-edit-notice.test.sh
#
# The exit code is the contract, not the text. PostToolUse hooks that exit 0
# have their stderr swallowed into the debug log, so a notice on exit 0 would be
# invisible to Claude — a hook that looks like it works and does nothing. The
# firing cases therefore assert exit 2 specifically; if a future edit softens
# them to exit 0, those cases fail first and say why.
#
# Basename matching is the whole gate, so the silent cases deliberately include
# near-misses (CLAUDE.md.template, claude.md, README.md in a dir named CLAUDE.md)
# that a substring match would wrongly fire on.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/claudemd-edit-notice.sh"
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

# $1=tool $2=path
payload() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2"; }

echo "claudemd-edit-notice"

# ── Fires ─────────────────────────────────────────────────────────────────────
# Every path here is a synthetic root (/repo, /user-home), never a real machine
# path. The hook reads only the basename, so the leading directories carry no
# assertion — and a literal /Users/... or /home/... would fail
# scripts/utils/check-no-hardcoded-paths.sh in pre-commit for no gain.
expect_rc "warns on project CLAUDE.md (exit 2)"  2 "$(payload Write /repo/CLAUDE.md)"
expect_rc "warns on user CLAUDE.md (exit 2)"     2 "$(payload Edit /user-home/.claude/CLAUDE.md)"
expect_rc "warns on AGENTS.md (exit 2)"          2 "$(payload Write /repo/AGENTS.md)"
expect_rc "warns on CLAUDE.local.md (exit 2)"    2 "$(payload MultiEdit /repo/CLAUDE.local.md)"
expect_rc "warns on nested CLAUDE.md (exit 2)"   2 "$(payload Edit /repo/packages/api/CLAUDE.md)"
expect_rc "warns via .path field (exit 2)"       2 '{"tool_name":"Write","tool_input":{"path":"/repo/CLAUDE.md"}}'

# ── Silent ────────────────────────────────────────────────────────────────────
expect_rc "silent on a normal .md"        0 "$(payload Write /repo/docs/README.md)"
expect_rc "silent on the template"        0 "$(payload Write /repo/templates/CLAUDE.md.template)"
expect_rc "silent on lowercase claude.md" 0 "$(payload Write /repo/claude.md)"
expect_rc "silent on a code file"         0 "$(payload Edit /repo/scripts/x.py)"
expect_rc "silent on empty file_path"     0 '{"tool_name":"Write","tool_input":{}}'
expect_rc "silent on malformed json"      0 'not json at all'
expect_rc "silent on empty stdin"         0 ''

# A directory literally named CLAUDE.md — basename is README.md, must not fire.
expect_rc "silent on README.md inside a CLAUDE.md dir" 0 "$(payload Write /repo/CLAUDE.md/README.md)"

# ── Opt-out ───────────────────────────────────────────────────────────────────
printf '%s' "$(payload Write /repo/CLAUDE.md)" | SDD_SKIP_CLAUDEMD_NOTICE=1 bash "$HOOK" >/dev/null 2>&1
if [ $? -eq 0 ]; then ok "SDD_SKIP_CLAUDEMD_NOTICE=1 silences it"
else bad "SDD_SKIP_CLAUDEMD_NOTICE=1 silences it" "expected exit 0"; fi

# ── Message content ───────────────────────────────────────────────────────────
ERR="$(printf '%s' "$(payload Write /repo/CLAUDE.md)" | bash "$HOOK" 2>&1 >/dev/null)"
for needle in "claudemd-edit-notice" "NOT active" "compact"; do
  if printf '%s' "$ERR" | grep -q -- "$needle"; then
    ok "message mentions '$needle'"
  else
    bad "message mentions '$needle'" "stderr was: $(printf '%s' "$ERR" | head -c 120)"
  fi
done

echo
printf '  %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
