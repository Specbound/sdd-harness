#!/bin/bash
# test-integrity-guard — PostToolUse soft gate (Write/Edit/MultiEdit).
# Pattern from Addy Osmani, "Agentic Code Review": agents take the cheapest path
# to green — weakening tests or CI instead of fixing the code ("gradient descent
# to green"). This watches the gate itself: when a test file or CI/coverage config
# is edited, it flags weakening signals (added skips, stubbed assertions, lowered
# thresholds, removed asserts) and asks Claude to confirm it's a real spec change.
# Does NOT block — outputs a reminder; Claude/user decides. Exits 0 always.
set -euo pipefail

EVENT=$(cat)

python3 -c '
import json, sys, re, os

try:
    e = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = e.get("tool_name", "")
if tool not in ("Write", "Edit", "MultiEdit"):
    sys.exit(0)

inp = e.get("tool_input", {}) or {}
path = inp.get("file_path", inp.get("path", "")) or ""
if not path:
    sys.exit(0)

base = os.path.basename(path)
low = path.replace("\\", "/").lower()

# --- Is this a test file or a CI/coverage config? ---
TEST_FILE = bool(
    re.search(r"(^|/)test_[^/]+$", low) or
    re.search(r"_test\.[a-z0-9]+$", low) or
    re.search(r"\.(spec|test)\.[a-z0-9]+$", low) or
    re.search(r"(^|/)(tests?|__tests__|spec)/", low)
)
CONFIG_FILE = base in (
    "pytest.ini", "tox.ini", "setup.cfg", "pyproject.toml",
    ".coveragerc", "jest.config.js", "jest.config.ts",
    "vitest.config.js", "vitest.config.ts",
) or bool(re.search(r"\.github/workflows/.*\.ya?ml$", low)) or low.endswith((".gitlab-ci.yml",))

if not (TEST_FILE or CONFIG_FILE):
    sys.exit(0)

# --- Gather the NEW text introduced by this edit, plus OLD text when available ---
new_text, old_text = "", ""
if tool == "Write":
    new_text = inp.get("content", "") or ""
elif tool == "Edit":
    new_text = inp.get("new_string", "") or ""
    old_text = inp.get("old_string", "") or ""
elif tool == "MultiEdit":
    for ed in (inp.get("edits", []) or []):
        new_text += (ed.get("new_string", "") or "") + "\n"
        old_text += (ed.get("old_string", "") or "") + "\n"

if not new_text.strip():
    sys.exit(0)

signals = []

# 1. Added skip / xfail / disabled markers (python, js/ts, go, junit)
SKIP_PATS = [
    (r"@pytest\.mark\.(skip|xfail)", "pytest skip/xfail marker"),
    (r"pytest\.skip\(", "pytest.skip() call"),
    (r"@unittest\.skip", "unittest skip decorator"),
    (r"\b(xit|xdescribe)\s*\(", "disabled JS test (xit/xdescribe)"),
    (r"\b(it|test|describe)\.(skip|todo)\s*\(", "JS test .skip/.todo"),
    (r"\bt\.Skip\(", "Go t.Skip()"),
    (r"@Disabled", "JUnit @Disabled"),
    (r"@Ignore", "JUnit @Ignore"),
]
for pat, label in SKIP_PATS:
    if re.search(pat, new_text) and not re.search(pat, old_text):
        signals.append("added " + label)

# 2. Stubbed / tautological assertions
STUB_PATS = [
    (r"assert\s+True\b", "assert True"),
    (r"assert\s+1\s*(==\s*1)?\s*$", "assert 1"),
    (r"expect\(\s*true\s*\)\.toBe(Truthy)?\(\s*true?\s*\)", "expect(true).toBe(true)"),
    (r"\bpass\s*#\s*TODO", "pass # TODO stub"),
]
for pat, label in STUB_PATS:
    if re.search(pat, new_text, re.MULTILINE):
        signals.append("tautological/stub assertion (" + label + ")")

# 3. Lowered coverage / threshold knobs (flag any touch — reviewer confirms direction)
COV_PATS = [
    (r"--cov-fail-under", "--cov-fail-under"),
    (r"\bfail_under\b", "fail_under"),
    (r"coverageThreshold", "jest coverageThreshold"),
    (r"\bminimum_coverage\b", "minimum_coverage"),
]
for pat, label in COV_PATS:
    if re.search(pat, new_text):
        signals.append("touched coverage threshold (" + label + ")")

# 4. Removed assertions (Edit/MultiEdit only — compare counts old vs new)
if old_text:
    def asserts(t):
        return len(re.findall(r"\b(assert|expect|assert_that|require\.)", t))
    removed = asserts(old_text) - asserts(new_text)
    if removed > 0:
        signals.append("removed %d assertion(s)" % removed)

if not signals:
    sys.exit(0)

Y = "\033[1;33m"; B = "\033[1m"; R = "\033[0m"
print(B + Y + "⚠  test-integrity-guard — " + base + R)
for s in signals:
    print(Y + "   • " + s + R)
print("")
print(B + "Gradient-descent-to-green check:" + R + " the cheapest path to a passing")
print("build is often to weaken the test, not fix the code. Confirm each change above is")
print("a deliberate spec change — not a shortcut to make a failing test pass. If the code")
print("is wrong, fix the code itself. Never soften the assertion or skip the test.")
' <<< "$EVENT" 2>/dev/null || true

exit 0

# REGISTRATION (settings.json — PostToolUse, matcher "Write|Edit|MultiEdit"):
# {
#   "matcher": "Write|Edit|MultiEdit",
#   "hooks": [
#     { "type": "command", "command": "bash .claude/hooks/test-integrity-guard.sh" }
#   ]
# }
