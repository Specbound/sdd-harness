#!/usr/bin/env bash
# js-quality-gate-hook.test.sh — prove the JS/TS gate selects the right files and
# stays silent everywhere else.
#
# Run: bash hooks/claude/js-quality-gate-hook.test.sh
#
# The hook is advisory, so exit code is always 0. The observable is whether it
# printed. Real linter invocation is exercised via a stub `oxlint` on PATH, so the
# suite passes on a machine with no JS toolchain installed.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$__here/js-quality-gate-hook.sh"

PASS=0
FAIL=0

TMP=$(mktemp -d)
STUBS="$TMP/stubs"
mkdir -p "$STUBS"
trap 'rm -rf "$TMP"' EXIT

# --- Stub linters -----------------------------------------------------------
# dirty: always reports a finding. clean: reports the "no problems" summary line.
make_stub() {
  local name="$1" body="$2"
  printf '#!/bin/bash\n%s\n' "$body" > "$STUBS/$name"
  chmod +x "$STUBS/$name"
}
stub_dirty()  { make_stub oxlint 'echo "$1:3:9: error: no-unknown-parameters — parameter typed as unknown"; exit 1'; }
stub_clean()  { make_stub oxlint 'echo "Found 0 warnings and 0 errors."; exit 0'; }
stub_plain()  { make_stub oxlint 'echo "$1:1:1: warning: no-console"; exit 1'; }
no_stub()     { rm -f "$STUBS/oxlint" "$STUBS/eslint"; }

# run_hook <tool_name> <file_path>  — PATH is stubs-only so a real oxlint/eslint on
# the developer's machine can never leak into the result.
run_hook() {
  python3 -c '
import json, sys
print(json.dumps({"tool_name": sys.argv[1], "tool_input": {"file_path": sys.argv[2]}}))
' "$1" "$2" | PATH="$STUBS:/usr/bin:/bin" bash "$HOOK" 2>/dev/null
}

touch_file() {
  local p="$TMP/$1"
  mkdir -p "$(dirname "$p")"
  printf 'export const x = 1;\n' > "$p"
  printf '%s' "$p"
}

warns() {
  local label="$1" tool="$2" rel="$3"
  local out; out=$(run_hook "$tool" "$(touch_file "$rel")")
  if [ -n "$out" ]; then
    printf '  ok   WARN    %-48s\n' "$label"; PASS=$((PASS + 1))
  else
    printf '  FAIL WARN    %-48s :: no output\n' "$label"; FAIL=$((FAIL + 1))
  fi
}

silent() {
  local label="$1" tool="$2" rel="$3"
  local out; out=$(run_hook "$tool" "$(touch_file "$rel")")
  if [ -z "$out" ]; then
    printf '  ok   SILENT  %-48s\n' "$label"; PASS=$((PASS + 1))
  else
    printf '  FAIL SILENT  %-48s :: printed %s bytes\n' "$label" "${#out}"; FAIL=$((FAIL + 1))
  fi
}

echo "js-quality-gate — extensions (linter present, findings exist)"
stub_dirty
warns  ".ts"                        Write     "a.ts"
warns  ".tsx"                       Edit      "a.tsx"
warns  ".js"                        MultiEdit "a.js"
warns  ".jsx"                       Write     "a.jsx"
warns  ".mts"                       Write     "a.mts"
warns  ".cjs"                       Write     "a.cjs"

echo "js-quality-gate — non-targets"
silent ".py (ruff hook's job)"      Write     "a.py"
silent ".md"                        Write     "a.md"
silent ".d.ts declaration file"     Write     "a.d.ts"
silent "node_modules/"              Write     "node_modules/pkg/a.ts"
silent "dist/"                      Write     "dist/a.js"
silent "coverage/"                  Write     "coverage/a.js"

echo "js-quality-gate — wrong tool"
silent "Read is not a write"        Read      "a.ts"
silent "Bash is not a write"        Bash      "a.ts"

echo "js-quality-gate — linter state"
stub_clean
silent "clean file (0 problems summary)" Write "a.ts"
no_stub
silent "no linter installed"             Write "a.ts"

echo "js-quality-gate — missing file"
no_stub
stub_dirty
out=$(run_hook Write "$TMP/does-not-exist.ts")
if [ -z "$out" ]; then
  printf '  ok   SILENT  %-48s\n' "file does not exist on disk"; PASS=$((PASS + 1))
else
  printf '  FAIL SILENT  %-48s\n' "file does not exist on disk"; FAIL=$((FAIL + 1))
fi

echo "js-quality-gate — anti-slop callout"
stub_dirty
out=$(run_hook Write "$(touch_file "b.ts")")
if printf '%s' "$out" | grep -q 'anti-slop rule hit'; then
  printf '  ok   RULE    %-48s\n' "anti-slop finding gets the extra callout"; PASS=$((PASS + 1))
else
  printf '  FAIL RULE    %-48s\n' "anti-slop finding gets the extra callout"; FAIL=$((FAIL + 1))
fi
stub_plain
out=$(run_hook Write "$(touch_file "c.ts")")
if printf '%s' "$out" | grep -q 'anti-slop rule hit'; then
  printf '  FAIL RULE    %-48s :: callout on a non-anti-slop rule\n' "generic finding stays generic"; FAIL=$((FAIL + 1))
else
  printf '  ok   RULE    %-48s\n' "generic finding stays generic"; PASS=$((PASS + 1))
fi

echo "js-quality-gate — exit code"
stub_dirty
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"'"$TMP/a.ts"'"}}' \
  | PATH="$STUBS:/usr/bin:/bin" bash "$HOOK" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  printf '  ok   EXIT    %-48s\n' "never blocks (exit 0 with findings)"; PASS=$((PASS + 1))
else
  printf '  FAIL EXIT    %-48s :: rc=%s\n' "never blocks (exit 0 with findings)" "$rc"; FAIL=$((FAIL + 1))
fi

printf '%s' 'not json at all' | PATH="$STUBS:/usr/bin:/bin" bash "$HOOK" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  printf '  ok   EXIT    %-48s\n' "malformed event does not error"; PASS=$((PASS + 1))
else
  printf '  FAIL EXIT    %-48s :: rc=%s\n' "malformed event does not error" "$rc"; FAIL=$((FAIL + 1))
fi

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
