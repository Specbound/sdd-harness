#!/usr/bin/env bash
# router-setup.test.sh — throwaway-tree tests for router-setup.sh.
#
# NOTE for task 9.4: this file will be EXPANDED there, not replaced. Build on
# these scenarios; do not delete them.
#
# What is FAKED on a prepended PATH: uv (python find/install — returns the
# real resolved python3 below, so router-setup.sh's own tomllib/json logic
# runs against a genuine interpreter, not a stub), curl (controllable fake
# HTTP code via a file), launchctl / systemctl (marker-file tracking, same
# convention as jeff-setup.test.sh; launchctl's `load` can also be made to
# fail for one specific label via LAUNCHD_FAIL_LABEL — used by scenario I to
# test sentinel/worker registration independence).
# What is NOT faked: uname (real, so detect_os() exercises this machine's
# real branch — this machine is macOS; grep is real too). The real python3
# on this machine (resolved once, below, via `command -v`, BEFORE PATH is
# overridden) is used as the "uv-resolved interpreter" stub answer, so every
# TOML/JSON read-write in router-setup.sh is exercised for real.
#
# Every scenario uses its own throwaway $HOME under a per-run mktemp -d
# directory — the real $HOME/.claude/settings.json and the real
# ~/.sdd-router are never touched.
set -u

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SETUP="$SCRIPT_DIR/router-setup.sh"
HARNESS_ROOT="$(cd -P "$SCRIPT_DIR/../.." && pwd)"

# Resolved BEFORE PATH is overridden below — this is the real interpreter,
# not a stub; confirmed (session ground-truth) to have tomllib (>=3.11).
REAL_PY="$(command -v python3)"

ROOT="$(mktemp -d)"
PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want=$2 got=$3)"; fi
}
check_contains() {
  if printf '%s' "$2" | grep -qF "$3"; then ok "$1"; else bad "$1 (missing: $3)"; fi
}
check_not_contains() {
  if printf '%s' "$2" | grep -qF "$3"; then bad "$1 (should not contain: $3)"; else ok "$1"; fi
}

BIN="$ROOT/bin"
mkdir -p "$BIN"

# ── stub: uv ────────────────────────────────────────────────────────────
# `uv python find`/`install` both answer with $REAL_PY so router-setup.sh's
# tomllib/json code genuinely executes against a real interpreter.
cat > "$BIN/uv" <<SH
#!/usr/bin/env bash
echo "uv \$*" >> "\$CALLS_LOG"
if [ "\$1" = "python" ] && [ "\$2" = "find" ]; then
  echo "$REAL_PY"
  exit 0
fi
if [ "\$1" = "python" ] && [ "\$2" = "install" ]; then
  exit 0
fi
if [ "\$1" = "tool" ]; then
  exit 1
fi
exit 1
SH

# ── stub: curl ──────────────────────────────────────────────────────────
# Reads the desired HTTP status code from $CURL_CODE_FILE (set per scenario);
# defaults to 200 if the file is absent.
cat > "$BIN/curl" <<SH
#!/usr/bin/env bash
echo "curl \$*" >> "\$CALLS_LOG"
code="200"
if [ -n "\${CURL_CODE_FILE:-}" ] && [ -f "\$CURL_CODE_FILE" ]; then
  code="\$(cat "\$CURL_CODE_FILE")"
fi
if [ "\$code" = "000" ]; then
  exit 7
fi
echo -n "\$code"
exit 0
SH

# ── stub: launchctl ────────────────────────────────────────────────────
cat > "$BIN/launchctl" <<SH
#!/usr/bin/env bash
echo "launchctl \$*" >> "\$CALLS_LOG"
case "\$1" in
  list)
    label="\$2"
    if [ -f "\$LAUNCHD_MARKER.\$label" ]; then
      exit 0
    else
      exit 1
    fi
    ;;
  load)
    shift
    fail=0
    for a in "\$@"; do
      case "\$a" in
        -*) continue ;;
        *.plist)
          label="\$(basename "\$a" .plist)"
          if [ -n "\${LAUNCHD_FAIL_LABEL:-}" ] && [ "\$label" = "\$LAUNCHD_FAIL_LABEL" ]; then
            fail=1
          else
            : > "\$LAUNCHD_MARKER.\$label"
          fi
          ;;
      esac
    done
    [ "\$fail" -eq 1 ] && exit 1
    exit 0
    ;;
  unload)
    plist="\${*: -1}"
    label="\$(basename "\$plist" .plist)"
    rm -f "\$LAUNCHD_MARKER.\$label"
    exit 0
    ;;
  *) exit 0 ;;
esac
SH

# ── stub: systemctl ────────────────────────────────────────────────────
cat > "$BIN/systemctl" <<SH
#!/usr/bin/env bash
echo "systemctl \$*" >> "\$CALLS_LOG"
case "\$1" in
  --user)
    shift
    case "\$1" in
      is-active)
        unit="\$3"
        if [ -f "\$SYSTEMD_MARKER.\$unit" ]; then
          exit 0
        else
          exit 1
        fi
        ;;
      enable)
        unit="\${*: -1}"
        : > "\$SYSTEMD_MARKER.\$unit"
        exit 0
        ;;
      disable)
        unit="\${*: -1}"
        rm -f "\$SYSTEMD_MARKER.\$unit"
        exit 0
        ;;
      daemon-reload) exit 0 ;;
      show-environment) exit 0 ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac
SH

chmod +x "$BIN"/*

new_home() {
  local suffix="$1"
  H="$ROOT/home-$suffix"
  mkdir -p "$H/.claude"
  export CALLS_LOG="$ROOT/calls-$suffix.log"
  export LAUNCHD_MARKER="$ROOT/launchd-marker-$suffix"
  export SYSTEMD_MARKER="$ROOT/systemd-marker-$suffix"
  export CURL_CODE_FILE="$ROOT/curl-code-$suffix"
  : > "$CALLS_LOG"
  rm -f "$LAUNCHD_MARKER".* "$SYSTEMD_MARKER".*
  echo "200" > "$CURL_CODE_FILE"
}

run() {
  HOME="$H" PATH="$BIN:$PATH" CALLS_LOG="$CALLS_LOG" LAUNCHD_MARKER="$LAUNCHD_MARKER" \
    SYSTEMD_MARKER="$SYSTEMD_MARKER" CURL_CODE_FILE="$CURL_CODE_FILE" \
    bash "$SETUP" "$@"
}

count_calls() { grep -c "$1" "$CALLS_LOG" 2>/dev/null || true; }

settings_json() { cat "$H/.claude/settings.json" 2>/dev/null || echo "{}"; }
router_toml() { cat "$H/.sdd-router/router.toml" 2>/dev/null || echo ""; }

# ── Scenario A: template-copy-on-first-run, never overwrites existing ─────
new_home "A"
run install >"$ROOT/out-A1.log" 2>&1
out1="$?"
toml1="$(router_toml)"
check "A1: first run installs cleanly" "0" "$out1"
check_contains "A1: router.toml created from template" "$toml1" "[router]"

# Mutate router.toml by hand, then run again — must not be clobbered by a
# fresh template copy.
printf '%s\n# hand-edited marker\n' "$toml1" > "$H/.sdd-router/router.toml"
run install >"$ROOT/out-A2.log" 2>&1
toml2="$(router_toml)"
check_contains "A2: existing router.toml is never overwritten by the template" "$toml2" "hand-edited marker"

# ── Scenario B: upstream discovery when ANTHROPIC_BASE_URL unset — falls
# back to the SDK default ─────────────────────────────────────────────────
new_home "B"
echo '{}' > "$H/.claude/settings.json"
run install >"$ROOT/out-B.log" 2>&1
rc_b="$?"
toml_b="$(router_toml)"
check "B: install succeeds with no ANTHROPIC_BASE_URL set" "0" "$rc_b"
check_contains "B: stored upstream falls back to SDK default" "$toml_b" 'upstream = "https://api.anthropic.com"'
settings_b="$(settings_json)"
check_contains "B: settings.json now points at the router's own address" "$settings_b" "127.0.0.1:8799"

# ── Scenario C: upstream discovery when ANTHROPIC_BASE_URL IS set —
# captures the real value ───────────────────────────────────────────────
new_home "C"
printf '{\n  "env": {\n    "ANTHROPIC_BASE_URL": "https://my-custom-upstream.example.com"\n  }\n}\n' > "$H/.claude/settings.json"
run install >"$ROOT/out-C.log" 2>&1
rc_c="$?"
toml_c="$(router_toml)"
check "C: install succeeds with a real upstream set" "0" "$rc_c"
check_contains "C: stored upstream captures the real pre-existing value" "$toml_c" 'upstream = "https://my-custom-upstream.example.com"'
settings_c="$(settings_json)"
check_contains "C: settings.json rewritten to the router's own address" "$settings_c" "127.0.0.1:8799"

# ── Scenario D: looped-on-first-run refusal — exit 1, no corruption ──────
new_home "D"
printf '{\n  "env": {\n    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8799"\n  }\n}\n' > "$H/.claude/settings.json"
before_settings="$(settings_json)"
run install >"$ROOT/out-D.log" 2>&1
rc_d="$?"
after_settings="$(settings_json)"
check "D: first-run self-loop is refused (exit 1)" "1" "$rc_d"
check "D: settings.json left untouched on refusal" "$before_settings" "$after_settings"
# ensure_router_toml() deliberately runs before the loop check, so the
# templated file exists either way — that is not corruption, since its
# upstream field is left exactly as empty as the shipped template's.
check_contains "D: router.toml exists but upstream is still empty (no corruption)" "$(router_toml)" 'upstream = ""'

# ── Scenario E: reclaimed-value repair on a second run ────────────────────
new_home "E"
echo '{}' > "$H/.claude/settings.json"
run install >"$ROOT/out-E1.log" 2>&1
toml_e1="$(router_toml)"
# Simulate `headroom init --global --memory claude` reclaiming the value.
printf '{\n  "env": {\n    "ANTHROPIC_BASE_URL": "https://headroom.example.com/reclaimed"\n  }\n}\n' > "$H/.claude/settings.json"
run install >"$ROOT/out-E2.log" 2>&1
rc_e2="$?"
settings_e2="$(settings_json)"
toml_e2="$(router_toml)"
check "E: second run (repair) exits 0" "0" "$rc_e2"
check_contains "E: settings.json repaired back to the router's own address" "$settings_e2" "127.0.0.1:8799"
check_not_contains "E: reclaimed value no longer present in settings.json" "$settings_e2" "headroom.example.com/reclaimed"
check "E: router.toml's stored upstream is untouched by the repair" "$toml_e1" "$toml_e2"

# ── Scenario F: idempotent second run is a no-op when nothing changed ────
new_home "F"
echo '{}' > "$H/.claude/settings.json"
run install >"$ROOT/out-F1.log" 2>&1
settings_f1="$(settings_json)"
run install >"$ROOT/out-F2.log" 2>&1
rc_f2="$?"
settings_f2="$(settings_json)"
check "F: second identical run exits 0" "0" "$rc_f2"
check "F: settings.json is byte-identical across the no-op run" "$settings_f1" "$settings_f2"
out_f2="$(cat "$ROOT/out-F2.log")"
check_contains "F: second run reports nothing to repair" "$out_f2" "Nothing to repair"

# ── Scenario G: preflight failure causes exit 1 before any settings.json
# mutation ─────────────────────────────────────────────────────────────
new_home "G"
echo '{}' > "$H/.claude/settings.json"
echo "000" > "$CURL_CODE_FILE"
before_settings_g="$(settings_json)"
run install >"$ROOT/out-G.log" 2>&1
rc_g="$?"
after_settings_g="$(settings_json)"
check "G: preflight failure exits non-zero" "1" "$rc_g"
check "G: settings.json untouched when preflight fails" "$before_settings_g" "$after_settings_g"
out_g="$(cat "$ROOT/out-G.log")"
check_contains "G: preflight failure message names the cause" "$out_g" "preflight failed"

# base_url_value — exact (not substring) extraction of
# settings.json's env.ANTHROPIC_BASE_URL via the real interpreter, so
# restoration/deletion assertions below are byte-for-byte rather than
# "happens to contain the right text somewhere". Prints the sentinel string
# "<absent>" when the key itself is missing, distinguishing "key removed"
# from "key present but empty".
base_url_value() {
  "$REAL_PY" - "$H/.claude/settings.json" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    print("<absent>")
    raise SystemExit(0)
env = data.get("env")
if not isinstance(env, dict) or "ANTHROPIC_BASE_URL" not in env:
    print("<absent>")
else:
    print(env["ANTHROPIC_BASE_URL"])
PY
}

# ── Scenario H: uninstall correctness ─────────────────────────────────────
# H1/H2: a completed install's real, pre-existing upstream is restored
# byte-for-byte, and both services are unloaded — not just one.
new_home "H"
printf '{\n  "env": {\n    "ANTHROPIC_BASE_URL": "https://my-custom-upstream.example.com"\n  }\n}\n' > "$H/.claude/settings.json"
run install >"$ROOT/out-H1.log" 2>&1
rc_h1="$?"
check "H1: install succeeds before uninstall" "0" "$rc_h1"

run uninstall >"$ROOT/out-H2.log" 2>&1
rc_h2="$?"
val_h2="$(base_url_value)"
calls_h2="$(cat "$CALLS_LOG")"
check "H2: uninstall exits 0" "0" "$rc_h2"
check "H2: real pre-existing upstream restored byte-for-byte" "https://my-custom-upstream.example.com" "$val_h2"
check_contains "H2: uninstall unloads the sentinel LaunchAgent" "$calls_h2" "launchctl unload $H/Library/LaunchAgents/com.sdd.router-sentinel.plist"
check_contains "H2: uninstall unloads the worker LaunchAgent" "$calls_h2" "launchctl unload $H/Library/LaunchAgents/com.sdd.router-worker.plist"
check "H2: sentinel LaunchAgent marker gone after uninstall" "1" "$( [ -f "$LAUNCHD_MARKER.com.sdd.router-sentinel" ] && echo 0 || echo 1 )"
check "H2: worker LaunchAgent marker gone after uninstall" "1" "$( [ -f "$LAUNCHD_MARKER.com.sdd.router-worker" ] && echo 0 || echo 1 )"

# H3: stored upstream equals the SDK default (ANTHROPIC_BASE_URL was never
# set before the first install) — uninstall must delete the key entirely,
# never write back the literal default string.
new_home "H3"
echo '{}' > "$H/.claude/settings.json"
run install >"$ROOT/out-H3-1.log" 2>&1
run uninstall >"$ROOT/out-H3-2.log" 2>&1
rc_h3="$?"
val_h3="$(base_url_value)"
check "H3: uninstall exits 0 when stored upstream is the SDK default" "0" "$rc_h3"
check "H3: SDK-default case deletes the key rather than writing it back" "<absent>" "$val_h3"

# H4: router.toml's stored upstream is empty (first run never completed —
# reuse scenario D's self-loop setup to reach that exact state) — uninstall
# must refuse with a clear error rather than guessing what to restore.
new_home "H4"
printf '{\n  "env": {\n    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8799"\n  }\n}\n' > "$H/.claude/settings.json"
run install >"$ROOT/out-H4-1.log" 2>&1
toml_h4="$(router_toml)"
check_contains "H4 setup: router.toml exists with an empty upstream (install never completed)" "$toml_h4" 'upstream = ""'
run uninstall >"$ROOT/out-H4-2.log" 2>&1
rc_h4="$?"
out_h4="$(cat "$ROOT/out-H4-2.log")"
check "H4: uninstall refuses on an empty stored upstream (exit 1)" "1" "$rc_h4"
check_contains "H4: refusal names the cause rather than guessing" "$out_h4" "never fully installed"

# ── Scenario I: sentinel/worker registration independence ────────────────
# This file never starts a real process (launchctl/systemctl are fully
# faked — see header), so "worker killed, sentinel still answers" cannot be
# proven at this file's fidelity; sentinel.test.sh/server.test.sh already
# cover the real pass-through behavior at the process level (task 6.2/7.3).
# What this file CAN prove, and does: install_services() registers the two
# services as separate launchctl calls, so a worker registration failure
# does not retroactively unregister an already-succeeded sentinel — i.e.
# the two are independently supervised once running. It also proves (see
# report) that install_service_macos's own die() on a load failure aborts
# the REST of cmd_install (no preflight, no settings.json write) rather
# than continuing past the worker — that is current, real behavior, tested
# here rather than assumed.
new_home "I"
echo '{}' > "$H/.claude/settings.json"
export LAUNCHD_FAIL_LABEL="com.sdd.router-worker"
run install >"$ROOT/out-I.log" 2>&1
rc_i="$?"
unset LAUNCHD_FAIL_LABEL
calls_i="$(cat "$CALLS_LOG")"
settings_i="$(settings_json)"
out_i="$(cat "$ROOT/out-I.log")"
check "I: a worker registration failure aborts cmd_install (exit 1)" "1" "$rc_i"
check_contains "I: sentinel load was attempted before the worker failure" "$calls_i" "launchctl load -w $H/Library/LaunchAgents/com.sdd.router-sentinel.plist"
check_contains "I: worker load was attempted and is the one that failed" "$calls_i" "launchctl load -w $H/Library/LaunchAgents/com.sdd.router-worker.plist"
check "I: sentinel is left registered despite the overall install aborting" "0" "$( [ -f "$LAUNCHD_MARKER.com.sdd.router-sentinel" ] && echo 0 || echo 1 )"
check "I: worker is NOT registered (its own load call is what failed)" "1" "$( [ -f "$LAUNCHD_MARKER.com.sdd.router-worker" ] && echo 0 || echo 1 )"
check_not_contains "I: settings.json was never wired — cmd_install died before preflight/write" "$settings_i" "127.0.0.1:8799"
check_contains "I: failure message names the launchctl load failure" "$out_i" "launchctl load failed"

echo ""
echo "$PASS passed, $FAIL failed"
rm -rf "$ROOT"
[ "$FAIL" -eq 0 ]
