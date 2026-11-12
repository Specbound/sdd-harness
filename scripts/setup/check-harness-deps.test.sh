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
# row <group> <label> <status> — the exact formatted line report() emits.
# Used by the router scenarios below to prove sentinel/worker down-states
# render as two distinct rows rather than one combined status, not just
# that the words appear somewhere in the output.
row(){ printf '  %-28s %-18s %s\n' "$1" "$2" "$3"; }

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
# FAKE_LISTEN_MAP (router scenarios only, "port1:addr1,port2:addr2") lets one
# stubbed process answer differently per queried port -- needed because
# check_router() probes two distinct ports (sentinel + worker) in the same
# run. check_classifier()'s original single-port FAKE_LISTEN_ADDR behaviour
# below is left untouched for every existing scenario that never sets the map.
if [ -n "${FAKE_LISTEN_MAP:-}" ]; then
  req_port=""
  for arg in "$@"; do
    case "$arg" in
      -iTCP:*) req_port="${arg#-iTCP:}" ;;
    esac
  done
  addr=""
  IFS=',' read -ra __pairs <<< "$FAKE_LISTEN_MAP"
  for pair in "${__pairs[@]}"; do
    p="${pair%%:*}"
    a="${pair#*:}"
    [ "$p" = "$req_port" ] && addr="$a" && break
  done
  if [ -z "$addr" ]; then
    exit 1
  fi
  echo "COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME"
  echo "proc    12345 user    5u  IPv4 0x123        0t0  TCP ${addr} (LISTEN)"
  exit 0
fi
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

# Second runner (task 9.3): sources check-harness-deps.sh the same
# function-only way, calls check_router() instead of check_classifier().
RUNNER2="$ROOT/run_router.sh"
cat > "$RUNNER2" <<'SH'
#!/usr/bin/env bash
set -u
. "$1"
check_router
echo "@@FAILURES=$FAILURES"
SH
chmod +x "$RUNNER2"

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

# write_router_only_toml <port> <upstream> — minimal router.toml carrying
# only what check_router() reads ([router].port, [router].upstream); empty
# upstream matches router-setup.sh's own templated/not-yet-installed state.
write_router_only_toml() {
  mkdir -p "$H/.sdd-router"
  cat > "$H/.sdd-router/router.toml" <<EOF
schema_version = 1

[router]
port = $1
upstream = "$2"
EOF
}

# write_settings_json <base_url> — ~/.claude/settings.json shape router-setup.sh
# itself reads/writes: {"env": {"ANTHROPIC_BASE_URL": "<base_url>"}}. Omitting
# the call entirely (no settings.json at all) is its own scenario, exercising
# check_router()'s FileNotFoundError -> {} fallback.
write_settings_json() {
  mkdir -p "$H/.claude"
  cat > "$H/.claude/settings.json" <<EOF
{"env": {"ANTHROPIC_BASE_URL": "$1"}}
EOF
}

run_router() {
  HOME="$H" PATH="$BIN:$PATH" VPY="$REAL_PY" SDD_HARNESS_DEPS_SOURCE_ONLY=1 \
    CALLS_LOG="$CALLS_LOG" \
    FAKE_LISTEN_ADDR="${FAKE_LISTEN_ADDR:-}" FAKE_LISTEN_MAP="${FAKE_LISTEN_MAP:-}" \
    bash "$RUNNER2" "$SETUP" 2>&1
}

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

# ──────────────────────────────────────────────────────────────────────────
# Scenario H — no router.toml at all -> skipped (router-setup.sh, task 9.1,
# has simply not run yet); no sentinel/worker/routing rows at all.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario H: no router.toml (router not installed) =="
new_home h
unset FAKE_LISTEN_MAP FAKE_LISTEN_ADDR
outH="$(run_router)"
check "H: FAILURES is 0" "0" "$(failures_from "$outH")"
check_contains "H: model router skipped" "$outH" "skipped (not installed yet — bash scripts/setup/router-setup.sh)"
check_not_contains "H: no sentinel row" "$outH" "router sentinel"
check_not_contains "H: no worker row" "$outH" "router worker"
check_not_contains "H: no routing row" "$outH" "router routing"

# ──────────────────────────────────────────────────────────────────────────
# Scenario I — fully wired: upstream recorded, both services listening on
# 127.0.0.1, ANTHROPIC_BASE_URL already equals the sentinel's own address.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario I: fully wired =="
new_home i
write_router_only_toml 8799 "https://api.anthropic.com"
write_settings_json "http://127.0.0.1:8799"
FAKE_LISTEN_MAP="8799:127.0.0.1:8799,8798:127.0.0.1:8798"
outI="$(run_router)"
check "I: FAILURES is 0" "0" "$(failures_from "$outI")"
check_contains "I: sentinel ok" "$outI" "$(row global "router sentinel" "ok (listening on 127.0.0.1)")"
check_contains "I: worker ok" "$outI" "$(row global "router worker" "ok (listening on 127.0.0.1)")"
check_contains "I: routing ok (wired)" "$outI" "$(row global "router routing" "ok (wired)")"

# ──────────────────────────────────────────────────────────────────────────
# Scenario J — unwired (reclaimed): upstream recorded, but ANTHROPIC_BASE_URL
# no longer equals the sentinel's own address (e.g. headroom init --global
# reclaimed it). The "invisible by construction" case named in tasks.md.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario J: unwired (reclaimed) =="
new_home j
write_router_only_toml 8799 "https://api.anthropic.com"
write_settings_json "https://api.anthropic.com"
FAKE_LISTEN_MAP="8799:127.0.0.1:8799,8798:127.0.0.1:8798"
outJ="$(run_router)"
check "J: FAILURES is 1 (routing only)" "1" "$(failures_from "$outJ")"
check_contains "J: sentinel ok" "$outJ" "$(row global "router sentinel" "ok (listening on 127.0.0.1)")"
check_contains "J: worker ok" "$outJ" "$(row global "router worker" "ok (listening on 127.0.0.1)")"
check_contains "J: routing FAILED unwired" "$outJ" "FAILED (unwired — ANTHROPIC_BASE_URL does not point at the router; re-run: bash scripts/setup/router-setup.sh)"

# ──────────────────────────────────────────────────────────────────────────
# Scenario K — looped: upstream empty (install never completed, or the
# self-loop guard refused it) but ANTHROPIC_BASE_URL already equals the
# sentinel's own address anyway — the ambiguous state cmd_install() itself
# refuses to create, observed here read-only instead of prevented.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario K: looped =="
new_home k
write_router_only_toml 8799 ""
write_settings_json "http://127.0.0.1:8799"
FAKE_LISTEN_MAP="8799:127.0.0.1:8799,8798:127.0.0.1:8798"
outK="$(run_router)"
check "K: FAILURES is 1 (routing only)" "1" "$(failures_from "$outK")"
check_contains "K: routing FAILED looped" "$outK" "FAILED (looped — ANTHROPIC_BASE_URL points at the router but no real upstream was ever recorded; re-run: bash scripts/setup/router-setup.sh)"

# ──────────────────────────────────────────────────────────────────────────
# Scenario L — sentinel down, worker up: its own distinct FAILED row, not
# swallowed into a single combined status (tasks.md 9.3's stated reason for
# this row existing).
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario L: sentinel down, worker up =="
new_home l
write_router_only_toml 8799 "https://api.anthropic.com"
write_settings_json "http://127.0.0.1:8799"
FAKE_LISTEN_MAP="8798:127.0.0.1:8798"
outL="$(run_router)"
check "L: FAILURES is 1 (sentinel only)" "1" "$(failures_from "$outL")"
check_contains "L: sentinel FAILED not listening" "$outL" "$(row global "router sentinel" "FAILED (not listening)")"
check_contains "L: worker still ok (own row)" "$outL" "$(row global "router worker" "ok (listening on 127.0.0.1)")"
check_contains "L: routing still ok wired (config-level, independent of liveness)" "$outL" "$(row global "router routing" "ok (wired)")"

# ──────────────────────────────────────────────────────────────────────────
# Scenario M — worker down, sentinel up: the mirror of L, confirming the two
# rows are independent in both directions.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario M: worker down, sentinel up =="
new_home m
write_router_only_toml 8799 "https://api.anthropic.com"
write_settings_json "http://127.0.0.1:8799"
FAKE_LISTEN_MAP="8799:127.0.0.1:8799"
outM="$(run_router)"
check "M: FAILURES is 1 (worker only)" "1" "$(failures_from "$outM")"
check_contains "M: sentinel still ok (own row)" "$outM" "$(row global "router sentinel" "ok (listening on 127.0.0.1)")"
check_contains "M: worker FAILED not listening" "$outM" "$(row global "router worker" "FAILED (not listening)")"
check_contains "M: routing still ok wired" "$outM" "$(row global "router routing" "ok (wired)")"

# ──────────────────────────────────────────────────────────────────────────
# Scenario N — sentinel wildcard-bound (R2.1), isolated from the worker and
# routing rows.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario N: sentinel wildcard-bound =="
new_home n
write_router_only_toml 8799 "https://api.anthropic.com"
write_settings_json "http://127.0.0.1:8799"
FAKE_LISTEN_MAP="8799:*:8799,8798:127.0.0.1:8798"
outN="$(run_router)"
check "N: FAILURES is 1 (sentinel wildcard only)" "1" "$(failures_from "$outN")"
check_contains "N: sentinel wildcard FAILED" "$outN" "$(row global "router sentinel" "FAILED (wildcard-bound: *:8799 — violates loopback-only, R2.1)")"
check_contains "N: worker still ok" "$outN" "$(row global "router worker" "ok (listening on 127.0.0.1)")"
check_contains "N: routing still ok wired" "$outN" "$(row global "router routing" "ok (wired)")"

# ──────────────────────────────────────────────────────────────────────────
# Scenario O — worker wildcard-bound (R2.1), the mirror of N.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario O: worker wildcard-bound =="
new_home o
write_router_only_toml 8799 "https://api.anthropic.com"
write_settings_json "http://127.0.0.1:8799"
FAKE_LISTEN_MAP="8799:127.0.0.1:8799,8798:*:8798"
outO="$(run_router)"
check "O: FAILURES is 1 (worker wildcard only)" "1" "$(failures_from "$outO")"
check_contains "O: sentinel still ok" "$outO" "$(row global "router sentinel" "ok (listening on 127.0.0.1)")"
check_contains "O: worker wildcard FAILED" "$outO" "$(row global "router worker" "FAILED (wildcard-bound: *:8798 — violates loopback-only, R2.1)")"
check_contains "O: routing still ok wired" "$outO" "$(row global "router routing" "ok (wired)")"

# ──────────────────────────────────────────────────────────────────────────
# Scenario P — not fully installed yet: upstream empty AND ANTHROPIC_BASE_URL
# does not equal the sentinel's own address (here: no settings.json at all)
# -> a skip, not a failure, distinct from both unwired and looped.
# ──────────────────────────────────────────────────────────────────────────
echo "== Scenario P: not fully installed (upstream empty, base url unset) =="
new_home p
write_router_only_toml 8799 ""
# deliberately no write_settings_json call
FAKE_LISTEN_MAP="8799:127.0.0.1:8799,8798:127.0.0.1:8798"
outP="$(run_router)"
check "P: FAILURES is 0" "0" "$(failures_from "$outP")"
check_contains "P: sentinel ok" "$outP" "$(row global "router sentinel" "ok (listening on 127.0.0.1)")"
check_contains "P: worker ok" "$outP" "$(row global "router worker" "ok (listening on 127.0.0.1)")"
check_contains "P: routing skipped (not fully installed)" "$outP" "$(row global "router routing" "skipped (not fully installed — run bash scripts/setup/router-setup.sh)")"

echo ""
echo "$PASS passed, $FAIL failed"
rm -rf "$ROOT"
[ "$FAIL" -eq 0 ]
