#!/usr/bin/env bash
# check-harness-deps.test.sh — functional tests for the model-router classifier
# row added to check-harness-deps.sh (task 8.2), run in a throwaway tree.
#
#   bash scripts/setup/check-harness-deps.test.sh
#
# What this exercises: check-harness-deps.sh is sourced (not executed) with
# SDD_HARNESS_DEPS_SOURCE_ONLY=1, which defines every function (report,
# jeff_listen_addr, check_classifier, ...) and returns before section 1's real
# .venv-tools work, section 2's real per-repo scan of this machine's real
# projects.txt, or section 3's real headroom probe. check_classifier() is then
# called directly against a throwaway $HOME.
#
# What is faked and why:
#   - `lsof`  -> echoes a controllable fake LISTEN line (FAKE_LISTEN_ADDR), or
#                nothing at all, instead of inspecting this machine's real
#                open sockets.
#   - `curl`  -> echoes a controllable fake HTTP code (FAKE_CURL_CODE) instead
#                of hitting a real (nonexistent, in this test) jeff process.
#
# What is NOT faked:
#   - `python3`/tomllib: router.toml is parsed with a real Python 3.11+
#     interpreter (resolved once, below) — parsing TOML correctly is part of
#     what this row verifies, so faking the parser would test nothing.
set -u

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SETUP="$SCRIPT_DIR/check-harness-deps.sh"
ROOT="$(mktemp -d)"
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want=$2 got=$3)"; fi }
check_contains(){ if printf '%s' "$2" | grep -qF "$3"; then ok "$1"; else bad "$1 (missing: $3)"; fi }
check_not_contains(){ if printf '%s' "$2" | grep -qF "$3"; then bad "$1 (should not contain: $3)"; else ok "$1"; fi }

# A real Python 3.11+ interpreter is required for tomllib — resolve once,
# mirroring what the real script's own venv_tools_ensure() would hand
# check_classifier() as $VPY in a healthy install.
REAL_PY=""
for cand in python3.13 python3.12 python3.11 python3; do
  if command -v "$cand" >/dev/null 2>&1 \
     && "$cand" -c 'import tomllib' >/dev/null 2>&1; then
    REAL_PY="$(command -v "$cand")"
    break
  fi
done
if [ -z "$REAL_PY" ]; then
  echo "SKIP: no Python 3.11+ with tomllib available on this machine — cannot test check_classifier()"
  exit 0
fi

# ── Stub bin dir ─────────────────────────────────────────────────────────────
BIN="$ROOT/bin"; mkdir -p "$BIN"

cat > "$BIN/lsof" <<'SH'
#!/bin/bash
echo "lsof $*" >> "${CALLS_LOG:-/dev/null}"
if [ -z "${FAKE_LISTEN_ADDR:-}" ]; then
  exit 1
fi
echo "COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME"
echo "jeff    12345 user    5u  IPv4 0x123        0t0  TCP ${FAKE_LISTEN_ADDR} (LISTEN)"
exit 0
SH

cat > "$BIN/curl" <<'SH'
#!/bin/bash
echo "curl $*" >> "${CALLS_LOG:-/dev/null}"
echo -n "${FAKE_CURL_CODE:-200}"
exit 0
SH

chmod +x "$BIN"/*

# Runner script (not `bash -c`, per lean-ctx inline-exec policy): sources
# check-harness-deps.sh in function-only mode, calls check_classifier(), and
# reports the resulting FAILURES count on a sentinel line the test can parse.
RUNNER="$ROOT/run_classifier.sh"
cat > "$RUNNER" <<'SH'
#!/usr/bin/env bash
set -u
. "$1"
check_classifier
echo "@@FAILURES=$FAILURES"
SH
chmod +x "$RUNNER"

new_home() {
  H="$ROOT/home-$1"
  mkdir -p "$H"
  CALLS_LOG="$H/calls.log"; : > "$CALLS_LOG"
  export CALLS_LOG
}

write_router_toml() {
  # write_router_toml <backend> <base_url> <api_key_env>
  mkdir -p "$H/.sdd-router"
  cat > "$H/.sdd-router/router.toml" <<EOF
schema_version = 1

[router]
port = 8799
upstream = ""

[classifier]
backend     = "$1"
base_url    = "$2"
api_key_env = "$3"
EOF
}

write_model() {
  local dir="$H/.sdd-router/jeff/models/gliformer-large-v1"
  mkdir -p "$dir"
  echo '{"fake":true}' > "$dir/config.json"
}

run_classifier() {
  HOME="$H" PATH="$BIN:$PATH" VPY="$REAL_PY" SDD_HARNESS_DEPS_SOURCE_ONLY=1 \
    CALLS_LOG="$CALLS_LOG" \
    FAKE_LISTEN_ADDR="${FAKE_LISTEN_ADDR:-}" FAKE_CURL_CODE="${FAKE_CURL_CODE:-200}" \
    JEFF_API_KEY="${JEFF_API_KEY:-}" \
    bash "$RUNNER" "$SETUP" 2>&1
}

failures_from() { printf '%s\n' "$1" | grep '^@@FAILURES=' | cut -d= -f2; }

# ──────────────────────────────────────────────────────────────────────────
# Scenario A — backend=jeff, model present, loopback-bound, 200 -> all ok.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario A: all healthy =="
new_home a
write_router_toml "jeff" "http://127.0.0.1:8000" "JEFF_API_KEY"
write_model
FAKE_LISTEN_ADDR="127.0.0.1:8000"
FAKE_CURL_CODE="200"
outA="$(run_classifier)"
check "A: FAILURES is 0" "0" "$(failures_from "$outA")"
check_contains "A: jeff model ok" "$outA" "jeff model"
check_contains "A: jeff model reported ok" "$outA" "ok"
check_contains "A: jeff bind ok (loopback)" "$outA" "jeff bind"
check_contains "A: jeff bind reports 127.0.0.1" "$outA" "ok (127.0.0.1)"
check_contains "A: jeff classify ok" "$outA" "jeff classify"
check_contains "A: jeff classify reports HTTP 200" "$outA" "ok (HTTP 200)"

# ──────────────────────────────────────────────────────────────────────────
# Scenario B — backend=jeff, wildcard-bound -> FAILED (R2.1 violation), even
# though the service still answers the 127.0.0.1 classify probe.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario B: wildcard-bound =="
new_home b
write_router_toml "jeff" "http://127.0.0.1:8000" "JEFF_API_KEY"
write_model
FAKE_LISTEN_ADDR="*:8000"
FAKE_CURL_CODE="200"
outB="$(run_classifier)"
check "B: FAILURES is 1 (bind only)" "1" "$(failures_from "$outB")"
check_contains "B: jeff bind FAILED" "$outB" "jeff bind"
check_contains "B: wildcard-bound reported" "$outB" "FAILED (wildcard-bound: *:8000"
check_contains "B: classify still ok (wildcard answers loopback probe)" "$outB" "ok (HTTP 200)"

# ──────────────────────────────────────────────────────────────────────────
# Scenario C — backend=jeff, nothing listening -> FAILED (dead classifier),
# not a skip; no separate "jeff bind" row (point 4: not a bind-address case).
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario C: nothing listening =="
new_home c
write_router_toml "jeff" "http://127.0.0.1:8000" "JEFF_API_KEY"
write_model
unset FAKE_LISTEN_ADDR
FAKE_CURL_CODE="000"
outC="$(run_classifier)"
check "C: FAILURES is 1 (classify only)" "1" "$(failures_from "$outC")"
check_not_contains "C: no jeff bind row when nothing listening" "$outC" "jeff bind"
check_contains "C: jeff classify FAILED" "$outC" "jeff classify"
check_contains "C: classify failure shows HTTP code" "$outC" "FAILED (HTTP 000)"

# ──────────────────────────────────────────────────────────────────────────
# Scenario D — backend != jeff -> skipped, not failed.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario D: backend=julia1 skipped =="
new_home d
write_router_toml "julia1" "http://127.0.0.1:8001" ""
outD="$(run_classifier)"
check "D: FAILURES is 0" "0" "$(failures_from "$outD")"
check_contains "D: classifier row skipped" "$outD" "skipped (backend=julia1, not jeff)"
check_not_contains "D: no jeff model row" "$outD" "jeff model"

echo "== Scenario D2: backend=none skipped =="
new_home d2
write_router_toml "none" "http://127.0.0.1:8002" ""
outD2="$(run_classifier)"
check "D2: FAILURES is 0" "0" "$(failures_from "$outD2")"
check_contains "D2: classifier row skipped" "$outD2" "skipped (backend=none, not jeff)"

# ──────────────────────────────────────────────────────────────────────────
# Scenario E — no router.toml at all -> skipped (router-setup.sh, task 9.1,
# has simply not run yet on this machine; not a broken install).
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario E: no router.toml =="
new_home e
outE="$(run_classifier)"
check "E: FAILURES is 0" "0" "$(failures_from "$outE")"
check_contains "E: classifier row skipped" "$outE" "skipped (no router.toml / classifier config yet)"

# ──────────────────────────────────────────────────────────────────────────
# Scenario F — backend=jeff, model directory missing -> FAILED, independent
# of bind/classify (which both still pass in this scenario).
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario F: model directory missing =="
new_home f
write_router_toml "jeff" "http://127.0.0.1:8000" "JEFF_API_KEY"
# deliberately do NOT write_model
FAKE_LISTEN_ADDR="127.0.0.1:8000"
FAKE_CURL_CODE="200"
outF="$(run_classifier)"
check "F: FAILURES is 1 (model only)" "1" "$(failures_from "$outF")"
check_contains "F: jeff model FAILED" "$outF" "jeff model"
check_contains "F: model-not-found message" "$outF" "FAILED (not found at"
check_contains "F: bind still ok" "$outF" "ok (127.0.0.1)"
check_contains "F: classify still ok" "$outF" "ok (HTTP 200)"

# ──────────────────────────────────────────────────────────────────────────
# Scenario G — api_key_env is honoured: the env var it NAMES is read at call
# time and sent as a bearer token; when unset, no Authorization header is
# sent at all (auth-disabled jeff is a valid config, not an error).
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario G: api_key_env mechanism =="
new_home g
write_router_toml "jeff" "http://127.0.0.1:8000" "JEFF_API_KEY"
write_model
FAKE_LISTEN_ADDR="127.0.0.1:8000"
FAKE_CURL_CODE="200"
JEFF_API_KEY="supersecret-token"
outG="$(run_classifier)"
check "G: FAILURES is 0" "0" "$(failures_from "$outG")"
check_contains "G: Authorization header sent with bearer value" "$(cat "$CALLS_LOG")" "Authorization: Bearer supersecret-token"
JEFF_API_KEY=""
: > "$CALLS_LOG"
outG2="$(run_classifier)"
check_not_contains "G: no Authorization header when env var unset/empty" "$(cat "$CALLS_LOG")" "Authorization:"

echo ""
echo "$PASS passed, $FAIL failed"
rm -rf "$ROOT"
[ "$FAIL" -eq 0 ]
