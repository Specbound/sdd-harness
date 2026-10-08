#!/usr/bin/env bash
# jeff-setup.test.sh — functional tests for jeff-setup.sh in a throwaway tree.
# No network, no real jeff clone, no real model download, no real launchd/
# systemd registration: git/uv/curl/openssl/launchctl/systemctl are stubbed on
# PATH, HOME points at a throwaway dir per scenario.
#
#   bash scripts/setup/jeff-setup.test.sh
#
# What is faked and why (said explicitly, per task instructions):
#   - `git clone`      -> creates a fake .git dir + a minimal pyproject.toml.
#                         A real clone is slow, needs network, and jeff's repo
#                         content is irrelevant to this script's own logic.
#   - `uv sync`         -> no-op. Installing jeff's real dependency tree is
#                         exactly the kind of slow/heavy step this task says is
#                         fine to skip in a throwaway-tree test.
#   - `uv run hf download ...` -> creates the target --local-dir with a marker
#                         file instead of downloading ~1GB of real weights.
#   - `openssl rand`    -> returns a fixed fake value, so the generated-vs-
#                         reused JEFF_API_KEYS assertions are deterministic.
#   - `launchctl` / `systemctl` -> track "installed" state via a marker file
#                         instead of touching the real user's real service
#                         manager.
#   - `curl`            -> returns a controllable fake HTTP code instead of
#                         hitting a real (nonexistent, in this test) jeff
#                         process, so the preflight success AND failure paths
#                         are both exercised without a real server.
#
# What is NOT faked:
#   - `uname` is real by default (exercises the actual host's detect_os()
#     branch — macOS on the machine this was written on). A `uname` stub is
#     also installed so FAKE_UNAME_S can force the linux/gitbash/unknown
#     branches on any host, matching the same idempotency/skip-cleanly
#     contract. The one detect_os() output NOT exercised here is "wsl" — it
#     requires a real /proc/version containing "microsoft", which cannot be
#     faked on a non-Linux test host without root. That branch is code-review
#     only; it reuses the exact same install_service_linux() path as "linux".
set -u

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SETUP="$SCRIPT_DIR/jeff-setup.sh"
ROOT="$(mktemp -d)"
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want=$2 got=$3)"; fi }
check_contains(){ if printf '%s' "$2" | grep -qF "$3"; then ok "$1"; else bad "$1 (missing: $3)"; fi }
check_not_contains(){ if printf '%s' "$2" | grep -qF "$3"; then bad "$1 (should not contain: $3)"; else ok "$1"; fi }

# ── Stub bin dir ─────────────────────────────────────────────────────────────
BIN="$ROOT/bin"; mkdir -p "$BIN"

cat > "$BIN/uname" <<'SH'
#!/bin/bash
if [ "$1" = "-s" ] && [ -n "${FAKE_UNAME_S:-}" ]; then
  echo "$FAKE_UNAME_S"
  exit 0
fi
exec /usr/bin/uname "$@"
SH

cat > "$BIN/git" <<'SH'
#!/bin/bash
echo "git $* (cwd=$PWD)" >> "$CALLS_LOG"
case "$1" in
  clone)
    shift
    [ "$1" = "-q" ] && shift
    dir="$2"
    mkdir -p "$dir/.git"
    cat > "$dir/pyproject.toml" <<'EOF'
[project]
name = "jeff"
requires-python = ">=3.12,<3.13"
EOF
    exit 0 ;;
  checkout) exit 0 ;;
  *) exit 0 ;;
esac
SH

cat > "$BIN/uv" <<'SH'
#!/bin/bash
echo "uv $* (cwd=$PWD)" >> "$CALLS_LOG"
case "$*" in
  "tool dir"|"tool dir --bin")
    echo "$STUB_BIN_SELF"; exit 0 ;;
  "sync --extra onnx")
    exit 0 ;;
  "run hf download "*)
    shift 3
    localdir=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --local-dir) localdir="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$localdir" ] && { mkdir -p "$localdir"; echo '{"fake":true}' > "$localdir/config.json"; }
    exit 0 ;;
  "run python -c "*)
    echo "fakepyhexkey00000000000000000000000000000000000000000000000000"
    exit 0 ;;
  *) exit 0 ;;
esac
SH

cat > "$BIN/openssl" <<'SH'
#!/bin/bash
echo "openssl $*" >> "$CALLS_LOG"
if [ "$1" = "rand" ]; then
  echo "fakeapikey0000000000000000000000000000000000000000000000000000"
  exit 0
fi
exit 1
SH

cat > "$BIN/launchctl" <<'SH'
#!/bin/bash
echo "launchctl $*" >> "$CALLS_LOG"
case "$1" in
  list) [ -f "$LAUNCHD_MARKER" ] && exit 0 || exit 1 ;;
  load) touch "$LAUNCHD_MARKER"; exit 0 ;;
  *) exit 0 ;;
esac
SH

cat > "$BIN/systemctl" <<'SH'
#!/bin/bash
echo "systemctl $*" >> "$CALLS_LOG"
case "$*" in
  "--user is-active --quiet "*) [ -f "$SYSTEMD_MARKER" ] && exit 0 || exit 1 ;;
  "--user daemon-reload") exit 0 ;;
  "--user enable --now "*) touch "$SYSTEMD_MARKER"; exit 0 ;;
  "--user show-environment") exit 0 ;;
  *) exit 0 ;;
esac
SH

cat > "$BIN/curl" <<'SH'
#!/bin/bash
echo "curl $*" >> "$CALLS_LOG"
echo -n "${CURL_HTTP_CODE:-200}"
exit 0
SH

chmod +x "$BIN"/*
export STUB_BIN_SELF="$BIN"

new_home() {
  H="$ROOT/home-$1"
  mkdir -p "$H"
  CALLS_LOG="$H/calls.log"; : > "$CALLS_LOG"
  LAUNCHD_MARKER="$H/.launchd-marker"; rm -f "$LAUNCHD_MARKER"
  SYSTEMD_MARKER="$H/.systemd-marker"; rm -f "$SYSTEMD_MARKER"
  export CALLS_LOG LAUNCHD_MARKER SYSTEMD_MARKER
}

run() {
  HOME="$H" PATH="$BIN:$PATH" CALLS_LOG="$CALLS_LOG" LAUNCHD_MARKER="$LAUNCHD_MARKER" \
    SYSTEMD_MARKER="$SYSTEMD_MARKER" STUB_BIN_SELF="$STUB_BIN_SELF" \
    FAKE_UNAME_S="${FAKE_UNAME_S:-}" CURL_HTTP_CODE="${CURL_HTTP_CODE:-200}" \
    bash "$SETUP" "$@"
}

count_calls() { grep -c "$1" "$CALLS_LOG" 2>/dev/null || true; }

# ──────────────────────────────────────────────────────────────────────────
# Scenario A — macOS (real host OS), idempotency across two runs. This is
# the property the task explicitly requires: "running it twice is a no-op
# on the second run" for clone/download/secret/service-registration.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario A: macOS-path idempotency =="
unset FAKE_UNAME_S
new_home macos

out1="$(run 2>&1)"; rc1=$?
check "run1: exits 0"                  "0" "$rc1"
check "run1: jeff cloned"              "1" "$([ -d "$H/.sdd-router/jeff/.git" ] && echo 1 || echo 0)"
check "run1: pyproject present"        "1" "$([ -f "$H/.sdd-router/jeff/pyproject.toml" ] && echo 1 || echo 0)"
check "run1: model marker present"     "1" "$([ -f "$H/.sdd-router/jeff/models/gliformer-large-v1/config.json" ] && echo 1 || echo 0)"
check "run1: secret env file present"  "1" "$([ -f "$H/.sdd-router/jeff/.jeff-service.env" ] && echo 1 || echo 0)"
check "run1: secret file mode 600"     "600" "$(stat -f '%Lp' "$H/.sdd-router/jeff/.jeff-service.env" 2>/dev/null || stat -c '%a' "$H/.sdd-router/jeff/.jeff-service.env")"
check_contains "run1: secret has JEFF_HOST=127.0.0.1" "$(cat "$H/.sdd-router/jeff/.jeff-service.env")" "JEFF_HOST=127.0.0.1"
check_contains "run1: secret has JEFF_BACKEND=onnx"   "$(cat "$H/.sdd-router/jeff/.jeff-service.env")" "JEFF_BACKEND=onnx"
check_contains "run1: secret has JEFF_QUANT=int8"     "$(cat "$H/.sdd-router/jeff/.jeff-service.env")" "JEFF_QUANT=int8"
check "run1: plist written"            "1" "$([ -f "$H/Library/LaunchAgents/com.sdd.jeff-classifier.plist" ] && echo 1 || echo 0)"
check "run1: plist mode 600 (embeds JEFF_API_KEYS raw, no EnvironmentFile= equivalent on launchd)" "600" "$(stat -f '%Lp' "$H/Library/LaunchAgents/com.sdd.jeff-classifier.plist" 2>/dev/null || stat -c '%a' "$H/Library/LaunchAgents/com.sdd.jeff-classifier.plist")"
PLIST1="$(cat "$H/Library/LaunchAgents/com.sdd.jeff-classifier.plist")"
check_contains "run1: plist has WorkingDirectory" "$PLIST1" "<string>$H/.sdd-router/jeff</string>"
check_contains "run1: plist ProgramArguments use absolute uv" "$PLIST1" "<string>$BIN/uv</string>"
check_contains "run1: plist has JEFF_HOST=127.0.0.1" "$PLIST1" "<key>JEFF_HOST</key><string>127.0.0.1</string>"
check "run1: git clone called once"    "1" "$(count_calls '^git clone')"
check "run1: hf download called once"  "1" "$(count_calls 'run hf download')"
check "run1: launchctl load called once" "1" "$(count_calls '^launchctl load')"
check_contains "run1: preflight passed" "$out1" "Preflight passed"
check_contains "run1: licence line is mixed, not MIT alone" "$out1" "jeff: MIT; gliformer-large-v1 weights: Apache-2.0"

KEY1="$(grep '^JEFF_API_KEYS=' "$H/.sdd-router/jeff/.jeff-service.env" | cut -d= -f2-)"
check "run1: API key generated (non-empty)" "1" "$([ -n "$KEY1" ] && echo 1 || echo 0)"

: > "$CALLS_LOG"   # isolate run2's own call log; state/markers are kept
out2="$(run 2>&1)"; rc2=$?
check "run2: exits 0"                  "0" "$rc2"
check "run2: git clone NOT called"     "0" "$(count_calls '^git clone')"
check "run2: hf download NOT called"   "0" "$(count_calls 'run hf download')"
check "run2: launchctl load NOT called (already loaded)" "0" "$(count_calls '^launchctl load')"
KEY2="$(grep '^JEFF_API_KEYS=' "$H/.sdd-router/jeff/.jeff-service.env" | cut -d= -f2-)"
check "run2: API key reused, not regenerated" "$KEY1" "$KEY2"
PLIST2="$(cat "$H/Library/LaunchAgents/com.sdd.jeff-classifier.plist")"
check "run2: plist unchanged (no duplicate registration)" "$PLIST1" "$PLIST2"
check_contains "run2: preflight still runs and passes" "$out2" "Preflight passed"

# ──────────────────────────────────────────────────────────────────────────
# Scenario B — Linux branch (forced via FAKE_UNAME_S; /proc/version is not
# faked, so this exercises "linux", not "wsl" — see header note).
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario B: linux branch =="
new_home linux
FAKE_UNAME_S="Linux"
outB="$(run 2>&1)"; rcB=$?
check "linux: exits 0" "0" "$rcB"
UNIT_PATH="$H/.config/systemd/user/sdd-jeff-classifier.service"
check "linux: unit file written" "1" "$([ -f "$UNIT_PATH" ] && echo 1 || echo 0)"
UNIT="$(cat "$UNIT_PATH" 2>/dev/null)"
check_contains "linux: unit has correct WorkingDirectory" "$UNIT" "WorkingDirectory=$H/.sdd-router/jeff"
check_contains "linux: unit ExecStart uses absolute uv" "$UNIT" "ExecStart=$BIN/uv run jeff"
check_contains "linux: unit references secret EnvironmentFile" "$UNIT" "EnvironmentFile=$H/.sdd-router/jeff/.jeff-service.env"
check "linux: systemctl enable --now called" "1" "$(count_calls '\-\-user enable --now sdd-jeff-classifier.service')"
check_contains "linux: preflight passed" "$outB" "Preflight passed"

# ──────────────────────────────────────────────────────────────────────────
# Scenario C — Git Bash: must skip the service install cleanly (no error)
# and skip the preflight (nothing was started to preflight against).
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario C: gitbash branch skips cleanly =="
new_home gitbash
FAKE_UNAME_S="MINGW64_NT-10.0-22631"
outC="$(run 2>&1)"; rcC=$?
check "gitbash: exits 0 (no error)" "0" "$rcC"
check_contains "gitbash: skip message present" "$outC" "Skipping persistent service: Git Bash"
check_contains "gitbash: preflight explicitly skipped" "$outC" "skipping preflight"
check_not_contains "gitbash: no false preflight-passed claim" "$outC" "Preflight passed"
check "gitbash: no plist written" "0" "$([ -f "$H/Library/LaunchAgents/com.sdd.jeff-classifier.plist" ] && echo 1 || echo 0)"
check "gitbash: no systemd unit written" "0" "$([ -f "$H/.config/systemd/user/sdd-jeff-classifier.service" ] && echo 1 || echo 0)"
check_contains "gitbash: licence line still printed" "$outC" "jeff: MIT; gliformer-large-v1 weights: Apache-2.0"

# ──────────────────────────────────────────────────────────────────────────
# Scenario D — unrecognized OS: same clean-skip contract as gitbash.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario D: unknown OS skips cleanly =="
new_home unknown
FAKE_UNAME_S="Plan9"
outD="$(run 2>&1)"; rcD=$?
check "unknown: exits 0 (no error)" "0" "$rcD"
check_contains "unknown: skip message present" "$outD" "Skipping persistent service: unrecognized OS"
check_not_contains "unknown: no false preflight-passed claim" "$outD" "Preflight passed"

# ──────────────────────────────────────────────────────────────────────────
# Scenario E — preflight failure must exit 1 with a clear message (macOS
# path; curl stub forced to return a non-200 code).
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario E: preflight failure exits 1 =="
new_home preflight-fail
unset FAKE_UNAME_S
CURL_HTTP_CODE="000"
outE="$(run 2>&1)"; rcE=$?
check "preflight-fail: exits 1" "1" "$rcE"
check_contains "preflight-fail: clear error message" "$outE" "preflight failed"
unset CURL_HTTP_CODE

# ──────────────────────────────────────────────────────────────────────────
# Scenario F — uv genuinely unresolvable: dies loudly, touches nothing.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario F: uv not found =="
new_home no-uv
unset FAKE_UNAME_S
BIN_NO_UV="$ROOT/bin-no-uv"; mkdir -p "$BIN_NO_UV"
for f in git openssl launchctl systemctl curl uname; do cp "$BIN/$f" "$BIN_NO_UV/$f"; done
outF="$(HOME="$H" PATH="$BIN_NO_UV:/usr/bin:/bin" CALLS_LOG="$CALLS_LOG" \
  LAUNCHD_MARKER="$LAUNCHD_MARKER" SYSTEMD_MARKER="$SYSTEMD_MARKER" \
  STUB_BIN_SELF="$STUB_BIN_SELF" bash "$SETUP" 2>&1)"; rcF=$?
check "no-uv: exits 1" "1" "$rcF"
check_contains "no-uv: clear error message" "$outF" "uv not found"
check "no-uv: did not clone jeff" "0" "$([ -e "$H/.sdd-router" ] && echo 1 || echo 0)"

echo ""
echo "$PASS passed, $FAIL failed"
rm -rf "$ROOT"
[ "$FAIL" -eq 0 ]
