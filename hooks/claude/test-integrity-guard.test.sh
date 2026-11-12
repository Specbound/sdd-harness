#!/usr/bin/env bash
# Tests for hooks/claude/test-integrity-guard.sh.
#
# Guards the 2026-09-03 regex removal: every check in that hook used to be a
# regex, and the rewrite to literal-token matching has to preserve which edits
# it flags and which it stays silent on. Silence is the interesting half — a
# guard that fires on ordinary test edits gets ignored, and an ignored guard is
# the same as no guard.
#
# Offline, no network, no repo writes. Run from anywhere:
#     bash hooks/claude/test-integrity-guard.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOOK="$SCRIPT_DIR/test-integrity-guard.sh"

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }

[ -f "$HOOK" ] || { echo "missing: $HOOK"; exit 1; }

# The point of the rewrite: this hook must contain no regex at all.
# Delegated to the repo guard rather than reimplemented here — an inline grep
# for `re\.` matches the literal `require.` in this hook's own token list, which
# is exactly the mis-span the ban exists to prevent.
GUARD="$SCRIPT_DIR/../../scripts/utils/check-no-regex.py"
if [ -f "$GUARD" ]; then
    if OUT="$(python3 "$GUARD" "$HOOK" 2>&1)"; then
        ok "hook contains no regex (per scripts/utils/check-no-regex.py)"
    else
        bad "hook contains no regex" "$OUT"
    fi
else
    bad "no-regex guard is present" "missing: $GUARD"
fi

# It must also not shell out to `python3 -c`, which the lean-ctx allowlist blocks.
if grep -q 'python3 -c' "$HOOK"; then
    bad "hook does not use 'python3 -c'" "found python3 -c"
else
    ok "hook does not use 'python3 -c' (heredoc instead)"
fi

run_hook() { printf '%s' "$1" | bash "$HOOK" 2>&1; }

# expect_signal <label> <json> <needle>
expect_signal() {
    local label="$1" payload="$2" needle="$3" out
    out="$(run_hook "$payload")"
    case "$out" in
        *"$needle"*) ok "$label" ;;
        *) bad "$label" "expected '$needle', got: ${out:-<empty>}" ;;
    esac
}

# expect_silent <label> <json>
expect_silent() {
    local label="$1" payload="$2" out
    out="$(run_hook "$payload")"
    if [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ]; then
        ok "$label"
    else
        bad "$label" "expected no output, got: $out"
    fi
}

w() {  # w <path> <content>  -> Write event JSON
    python3 - "$1" "$2" <<'PY'
import json, sys
print(json.dumps({"tool_name": "Write",
                  "tool_input": {"file_path": sys.argv[1], "content": sys.argv[2]}}))
PY
}

ed() {  # ed <path> <old> <new> -> Edit event JSON
    python3 - "$1" "$2" "$3" <<'PY'
import json, sys
print(json.dumps({"tool_name": "Edit",
                  "tool_input": {"file_path": sys.argv[1],
                                 "old_string": sys.argv[2],
                                 "new_string": sys.argv[3]}}))
PY
}

echo "path classification"
expect_silent "non-test file is ignored entirely"        "$(w 'src/main.py' 'assert True')"
expect_signal "test_ prefix is a test file"              "$(w 'test_thing.py' 'assert True')"      "assert True"
expect_signal "_test suffix is a test file"              "$(w 'thing_test.go' 'assert True')"      "assert True"
expect_signal "foo.test.ts is a test file"               "$(w 'a/foo.test.ts' 'assert True')"      "assert True"
expect_signal "foo.spec.js is a test file"               "$(w 'a/foo.spec.js' 'assert True')"      "assert True"
expect_signal "tests/ directory is a test path"          "$(w 'tests/thing.py' 'assert True')"     "assert True"
expect_signal "__tests__/ directory is a test path"      "$(w '__tests__/a.js' 'assert True')"     "assert True"
expect_signal "github workflow yaml is a config file"    "$(w '.github/workflows/ci.yml' 'fail_under = 10')" "coverage threshold"
expect_signal "pyproject.toml is a config file"          "$(w 'pyproject.toml' 'fail_under = 10')" "coverage threshold"
expect_silent "a stray yaml outside workflows is ignored" "$(w 'deploy/app.yml' 'fail_under = 10')"

echo "skip markers"
expect_signal "pytest skip"        "$(w 'test_a.py' '@pytest.mark.skip
def test_x(): pass')"                   "pytest skip marker"
expect_signal "pytest xfail"       "$(w 'test_a.py' '@pytest.mark.xfail
def test_x(): pass')"                   "pytest xfail marker"
expect_signal "pytest.skip() call" "$(w 'test_a.py' 'pytest.skip("later")')"        "pytest.skip() call"
expect_signal "unittest skip"      "$(w 'test_a.py' '@unittest.skip("x")')"         "unittest skip decorator"
expect_signal "JS it.skip"         "$(w 'a.test.js' 'it.skip("x", () => {})')"      "JS it.skip"
expect_signal "JS describe.skip"   "$(w 'a.test.js' 'describe.skip("x", () => {})')" "JS describe.skip"
expect_signal "JS xit"             "$(w 'a.test.js' 'xit("x", () => {})')"          "disabled JS test (xit)"
expect_signal "JS test.todo"       "$(w 'a.test.js' 'test.todo("x")')"              "JS test.todo"
expect_signal "Go t.Skip"          "$(w 'a_test.go' 't.Skip("flaky")')"             "Go t.Skip()"
# Maven/Gradle put Java tests under src/test/java, which is what classifies the
# file. A bare `FooTest.java` at the repo root is NOT treated as a test file —
# the pre-rewrite regex did not match CamelCase `Test` suffixes either, so this
# is parity, not a gap introduced by dropping regex. Adding a case-insensitive
# "stem ends with test" rule would misfire on `latest.py` and `contest.py`.
expect_signal "JUnit @Disabled in src/test/java" \
    "$(w 'src/test/java/FooTest.java' '@Disabled')" "JUnit @Disabled"
expect_silent "bare FooTest.java outside a test dir is not classified" \
    "$(w 'FooTest.java' '@Disabled')"

# A skip already present in the old text is not an *added* skip.
expect_silent "pre-existing skip is not flagged as added" \
    "$(ed 'test_a.py' '@pytest.mark.skip
def test_x(): assert f()' '@pytest.mark.skip
def test_x(): assert g()')"

echo "stub assertions"
expect_signal "assert True"              "$(w 'test_a.py' 'def test_x(): assert True')"  "assert True"
expect_signal "assert 1 == 1"            "$(w 'test_a.py' 'assert 1 == 1')"              "assert 1 == 1"
expect_signal "expect(true).toBe(true)"  "$(w 'a.test.js' 'expect(true).toBe(true)')"    "expect(true).toBe(true)"
expect_signal "expect(true).toBeTruthy()" "$(w 'a.test.js' 'expect(true).toBeTruthy()')" "expect(true).toBeTruthy()"

echo "coverage knobs"
expect_signal "--cov-fail-under"     "$(w 'pytest.ini' 'addopts = --cov-fail-under=50')" "--cov-fail-under"
expect_signal "coverageThreshold"    "$(w 'jest.config.js' 'coverageThreshold: {}')"     "jest coverageThreshold"

echo "removed assertions"
expect_signal "removing assertions is counted" \
    "$(ed 'test_a.py' 'assert a
assert b
assert c' 'assert a')" "removed 2 assertion(s)"
expect_silent "adding assertions is not flagged" \
    "$(ed 'test_a.py' 'assert a' 'assert a
assert b')"

echo "quiet cases"
expect_silent "ordinary test edit stays silent" \
    "$(w 'test_a.py' 'def test_add():
    result = add(2, 2)
    assert result == 4')"
expect_silent "empty content stays silent"     "$(w 'test_a.py' '')"
expect_silent "unrelated tool is ignored"      '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
expect_silent "missing file_path is ignored"   '{"tool_name":"Write","tool_input":{"content":"assert True"}}'
expect_silent "malformed JSON is ignored"      'not json at all'
expect_silent "empty stdin is ignored"         ''

echo "exit code contract"
printf '%s' "$(w 'test_a.py' 'assert True')" | bash "$HOOK" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    ok "always exits 0 even when signalling (soft gate, never blocks)"
else
    bad "always exits 0 even when signalling" "non-zero exit"
fi

echo
printf 'test-integrity-guard.test.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
