#!/usr/bin/env bash
# router-setup.sh — install/uninstall the model-router's two persistent
# services (sentinel + worker) and wire/unwire ANTHROPIC_BASE_URL so `claude`
# routes through the sentinel.
#
# THIS IS THE ONLY SETUP STEP THAT CAN TAKE `claude` AWAY FROM YOU: it
# rewrites the global ANTHROPIC_BASE_URL every `claude` invocation on this
# machine reads. The ordering below is deliberate and must not be reversed:
# both services are installed, started, and confirmed answering BEFORE
# settings.json is ever touched (mirrors headroom-setup.sh's own section-4
# install -> health-check -> wire pattern).
#
# Usage:
#   router-setup.sh [install]   # default — install/wire (idempotent)
#   router-setup.sh uninstall   # restore the discovered upstream, remove both services
#
# What install does:
#   1. Resolves `uv` (scripts/lib/tool-paths.sh) and a Python interpreter
#      >=3.11 via `uv python find`/`uv python install 3.12` — never a bare
#      `python3` (R10.8: this machine's system python3 lacks `tomllib`). The
#      resolved absolute path goes into every generated service unit.
#   2. Writes ~/.sdd-router/router.toml from the template when absent; never
#      overwrites an existing one.
#   3. First run only (router.toml absent, or present with an empty
#      [router].upstream): discovers the current ANTHROPIC_BASE_URL (the SDK
#      default https://api.anthropic.com when unset) and, once the services
#      below are confirmed healthy, stores it permanently as
#      [router].upstream. That field is never rewritten by any later run.
#   4. Installs+starts the sentinel and worker as persistent, OS-supervised
#      services — launchd (KeepAlive + ThrottleInterval) on macOS, systemd
#      (Restart=always + RestartSec) on Linux/systemd-enabled WSL — skipping
#      cleanly on Git Bash / unsupported OS. Idempotent: an already-loaded
#      service is left alone.
#   5. Preflights by sending one real HTTP request through the sentinel's own
#      public port; exits 1 (touching nothing in settings.json) if nothing
#      comes back.
#   6. Writes/repairs ~/.claude/settings.json's env.ANTHROPIC_BASE_URL to the
#      sentinel's own address: on first run, and again on every later run
#      where something else (e.g. `headroom init --global --memory claude`,
#      which update.sh re-runs) reclaimed it back to a different value. A
#      run where it already points at the sentinel is a pure no-op.
#
# Looped-on-first-run refusal: if, on a first run, ANTHROPIC_BASE_URL already
# equals the sentinel's own address before router.toml has ever recorded a
# real upstream, that is unresolvable ambiguity (a self-forwarding loop with
# no real upstream ever known) — this script refuses and exits 1 rather than
# guessing, per this repo's fail-loud setup standard.
#
# Named scope decision — NOT done here, flagged rather than silently skipped:
# the worker (server.py) authenticates to jeff using the env var named by
# router.toml's [classifier].api_key_env (default JEFF_API_KEY), read at call
# time via os.environ.get(...). jeff-setup.sh generates jeff's own accepted
# key as JEFF_API_KEYS inside jeff's OWN service environment file
# (~/.sdd-router/jeff/.jeff-service.env) — a different service, with a
# different environment, under a different variable name. Nothing wires that
# value into the worker service's own environment under the api_key_env name.
# Until that wiring exists, every classify call is unauthenticated: if jeff's
# JEFF_API_KEYS is non-empty (the default), every call 401s, the circuit
# breaker opens, and the router permanently (but silently, fail-open) falls
# back to pass-through — `claude` keeps working, but classification and the
# cost savings it exists to produce never happen. Task 9.1's own bullets do
# not mention this wiring, so it is scoped OUT of this script deliberately,
# not forgotten. Recommendation: a follow-up task should read
# ~/.sdd-router/jeff/.jeff-service.env's JEFF_API_KEYS value and inject it
# into the worker service's own environment under router.toml's configured
# api_key_env name, applying the same chmod-600 discipline jeff-setup.sh's
# plist already uses IF that wiring lands in a file that embeds the secret
# directly (launchd has no EnvironmentFile= equivalent); a systemd
# EnvironmentFile= pointing at the existing, already-600, jeff secret file
# would not even need a new secret file.
#
# Neither service unit this script writes embeds a secret of its own (no
# API-key wiring happens here — see the scope decision above), so normal file
# permissions are correct for both the launchd plists and the systemd units
# this script generates.
set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# Verifies: specs/model-router/requirements.md#10.2 (idempotent setup must not
# silently depend on an interactive-shell PATH it won't have under automation).
. "$__here/../lib/resolve-harness-dir.sh"
. "$__here/../lib/tool-paths.sh"
ensure_tool_bin_on_path

ROUTER_DIR="$HOME/.sdd-router"
ROUTER_TOML="$ROUTER_DIR/router.toml"
TEMPLATE_PATH="$HARNESS_DIR/templates/router.toml.template"
SETTINGS_JSON="$HOME/.claude/settings.json"
# SDK's own hardcoded fallback when ANTHROPIC_BASE_URL is absent/unset
# entirely (confirmed in the installed anthropic SDK's _client.py).
SDK_DEFAULT_UPSTREAM="https://api.anthropic.com"

SENTINEL_SCRIPT="$HARNESS_DIR/scripts/router/sentinel.py"
WORKER_SCRIPT="$HARNESS_DIR/scripts/router/server.py"

SENTINEL_LAUNCHD_LABEL="com.sdd.router-sentinel"
WORKER_LAUNCHD_LABEL="com.sdd.router-worker"
SENTINEL_SYSTEMD_UNIT="sdd-router-sentinel.service"
WORKER_SYSTEMD_UNIT="sdd-router-worker.service"

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "  $*"; }

# Verifies: specs/model-router/requirements.md#10.4 (all four detect_os() cases).
detect_os() {
  case "$(uname -s 2>/dev/null)" in
    Darwin)           echo "macos"   ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi ;;
    MINGW*|MSYS*|CYGWIN*) echo "gitbash" ;;
    *) echo "unknown" ;;
  esac
}

# ── uv + interpreter resolution (R10.8) ─────────────────────────────────────
UV_BIN="$(find_tool uv || true)"
[ -n "$UV_BIN" ] || die "uv not found (not installed, not on PATH, not in any known tool dir). Install: https://docs.astral.sh/uv/getting-started/installation/"

resolve_python() {
  local py
  py="$("$UV_BIN" python find '>=3.11' 2>/dev/null || true)"
  if [ -z "$py" ] || [ ! -x "$py" ]; then
    "$UV_BIN" python install 3.12 >/dev/null 2>&1 || die "'uv python install 3.12' failed — cannot provision an interpreter >=3.11"
    py="$("$UV_BIN" python find '>=3.11' 2>/dev/null || true)"
  fi
  [ -n "$py" ] && [ -x "$py" ] || die "could not resolve a Python interpreter >=3.11 via uv (needed for tomllib)"
  echo "$py"
}
PYBIN="$(resolve_python)"
note "Python interpreter resolved at $PYBIN (>=3.11, required for tomllib)."

# ── router.toml ──────────────────────────────────────────────────────────
ensure_router_toml() {
  mkdir -p "$ROUTER_DIR"
  if [ -f "$ROUTER_TOML" ]; then
    note "router.toml already present at $ROUTER_TOML — left as-is."
  else
    [ -f "$TEMPLATE_PATH" ] || die "template not found: $TEMPLATE_PATH"
    cp "$TEMPLATE_PATH" "$ROUTER_TOML"
    note "Wrote router.toml from template to $ROUTER_TOML."
  fi
}

# read_router_fields — prints port and upstream joined by a single 0x1f
# separator on one line (NOT two lines: command substitution strips *all*
# trailing newlines, which would silently eat a genuinely-empty upstream's
# blank second line and make `tail -n1` return the port instead — a real bug
# caught by this script's own test suite). Read-only tomllib, deliberately
# duplicating sentinel.py's own read rather than importing it (the same
# zero-shared-failure-surface decision sentinel.py's own header documents) —
# this script is a third, independent reader.
read_router_fields() {
  ROUTER_TOML_PATH="$ROUTER_TOML" "$PYBIN" - <<'PY'
import os
import tomllib

path = os.environ["ROUTER_TOML_PATH"]
with open(path, "rb") as f:
    data = tomllib.load(f)
router = data.get("router")
if not isinstance(router, dict):
    router = {}
port = router.get("port", 8799)
upstream = router.get("upstream") or ""
print(f"{port}\x1f{upstream}", end="")
PY
}

# write_upstream_to_toml — the ONE place [router].upstream is ever written,
# and only ever called once per installation's lifetime (first successful
# run). Explicit line-based rewrite (stdlib tomllib has no writer, and this
# repo bans regex for exactly this kind of text surgery) rather than a
# pattern match: walks the file's own [section] markers literally.
write_upstream_to_toml() {
  ROUTER_TOML_PATH="$ROUTER_TOML" NEW_UPSTREAM="$1" "$PYBIN" - <<'PY'
import os

path = os.environ["ROUTER_TOML_PATH"]
new_upstream = os.environ["NEW_UPSTREAM"]

with open(path, encoding="utf-8") as f:
    lines = f.readlines()

in_router_table = False
replaced = False
out = []
for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        in_router_table = stripped == "[router]"
        out.append(line)
        continue
    if in_router_table and stripped.startswith("upstream") and "=" in stripped:
        escaped = new_upstream.replace("\\", "\\\\").replace('"', '\\"')
        out.append('upstream = "' + escaped + '"\n')
        replaced = True
        continue
    out.append(line)

if not replaced:
    raise SystemExit("router.toml: [router].upstream line not found")

with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)
PY
}

# ── settings.json — merge-not-overwrite, matching
# scripts/utils/headroom-unwire-if-dead.py's own proven shape exactly: read
# the whole JSON (missing file treated as {}), mutate only env.ANTHROPIC_BASE_URL,
# write the whole structure back so every other key survives untouched.
read_current_base_url() {
  SETTINGS_JSON_PATH="$SETTINGS_JSON" SDK_DEFAULT="$SDK_DEFAULT_UPSTREAM" "$PYBIN" - <<'PY'
import json
import os

path = os.environ["SETTINGS_JSON_PATH"]
default = os.environ["SDK_DEFAULT"]

try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

env = data.get("env")
if not isinstance(env, dict):
    env = {}

print(env.get("ANTHROPIC_BASE_URL") or default)
PY
}

write_base_url_to_settings() {
  SETTINGS_JSON_PATH="$SETTINGS_JSON" NEW_BASE_URL="$1" "$PYBIN" - <<'PY'
import json
import os

path = os.environ["SETTINGS_JSON_PATH"]
new_url = os.environ["NEW_BASE_URL"]

try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

if not isinstance(data, dict):
    raise SystemExit(path + ": top-level JSON is not an object — refusing to overwrite")

env = data.get("env")
if not isinstance(env, dict):
    env = {}
env["ANTHROPIC_BASE_URL"] = new_url
data["env"] = env

parent = os.path.dirname(path) or "."
os.makedirs(parent, exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

# delete_base_url_from_settings — uninstall's "was never explicitly set"
# branch: removes the key entirely rather than writing the literal SDK
# default string, since those are not the same starting state.
delete_base_url_from_settings() {
  SETTINGS_JSON_PATH="$SETTINGS_JSON" "$PYBIN" - <<'PY'
import json
import os

path = os.environ["SETTINGS_JSON_PATH"]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    raise SystemExit(0)

env = data.get("env")
if isinstance(env, dict) and "ANTHROPIC_BASE_URL" in env:
    del env["ANTHROPIC_BASE_URL"]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY
}

# ── service install/uninstall — launchd (macOS) / systemd (Linux, incl.
# systemd-enabled WSL), mirroring jeff-setup.sh's own install_service_macos/
# install_service_linux mechanics, parametrized for two independent services.
install_service_macos() {
  local label="$1" script="$2" logname="$3"
  shift 3
  local plist_dir="$HOME/Library/LaunchAgents"
  local plist_path="$plist_dir/$label.plist"
  local log_dir="$ROUTER_DIR/.logs"
  mkdir -p "$plist_dir" "$log_dir"

  if launchctl list "$label" >/dev/null 2>&1; then
    note "LaunchAgent '$label' already loaded — skipping registration."
    return 0
  fi

  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0">'
    echo '<dict>'
    echo "    <key>Label</key><string>${label}</string>"
    echo "    <key>WorkingDirectory</key><string>${ROUTER_DIR}</string>"
    echo '    <key>ProgramArguments</key>'
    echo '    <array>'
    echo "        <string>${PYBIN}</string>"
    echo "        <string>${script}</string>"
    for a in "$@"; do
      echo "        <string>${a}</string>"
    done
    echo '    </array>'
    echo '    <key>RunAtLoad</key><true/>'
    echo '    <key>KeepAlive</key><true/>'
    echo '    <key>ThrottleInterval</key><integer>5</integer>'
    echo "    <key>StandardOutPath</key><string>${log_dir}/${logname}.stdout.log</string>"
    echo "    <key>StandardErrorPath</key><string>${log_dir}/${logname}.stderr.log</string>"
    echo '</dict>'
    echo '</plist>'
  } > "$plist_path"
  # No secret is embedded in this plist — see the scope-decision header note.

  if launchctl load -w "$plist_path"; then
    note "LaunchAgent '$label' registered and started."
  else
    die "launchctl load failed for $plist_path"
  fi
}

install_service_linux() {
  local unit="$1" script="$2" description="$3"
  shift 3
  local unit_dir="$HOME/.config/systemd/user"
  local unit_path="$unit_dir/$unit"
  mkdir -p "$unit_dir"

  if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
    note "systemd user service '$unit' already active — skipping registration."
    return 0
  fi

  local exec_args=""
  for a in "$@"; do
    exec_args="$exec_args $a"
  done

  cat > "$unit_path" <<UNIT
[Unit]
Description=${description}
After=network.target

[Service]
WorkingDirectory=${ROUTER_DIR}
ExecStart=${PYBIN} ${script}${exec_args}
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
UNIT
  # No secret is embedded in this unit — see the scope-decision header note.

  systemctl --user daemon-reload || die "systemctl --user daemon-reload failed"
  if systemctl --user enable --now "$unit"; then
    note "systemd user service '$unit' installed and started."
  else
    die "systemctl --user enable --now failed for $unit"
  fi
}

uninstall_service_macos() {
  local label="$1"
  local plist_path="$HOME/Library/LaunchAgents/$label.plist"
  if launchctl list "$label" >/dev/null 2>&1; then
    launchctl unload "$plist_path" 2>/dev/null || true
  fi
  rm -f "$plist_path"
  note "Removed LaunchAgent '$label'."
}

uninstall_service_linux() {
  local unit="$1"
  systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
  rm -f "$HOME/.config/systemd/user/$unit"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  note "Removed systemd user service '$unit'."
}

# Verifies: specs/model-router/requirements.md#10.4, #4.5a (two independent,
# OS-supervised services — this pairing is the watchdog).
install_services() {
  case "$(detect_os)" in
    macos)
      install_service_macos "$SENTINEL_LAUNCHD_LABEL" "$SENTINEL_SCRIPT" "sentinel" --router-toml "$ROUTER_TOML"
      install_service_macos "$WORKER_LAUNCHD_LABEL" "$WORKER_SCRIPT" "worker" --router-toml "$ROUTER_TOML"
      ;;
    linux)
      install_service_linux "$SENTINEL_SYSTEMD_UNIT" "$SENTINEL_SCRIPT" "sdd-harness model-router sentinel (front door)" --router-toml "$ROUTER_TOML"
      install_service_linux "$WORKER_SYSTEMD_UNIT" "$WORKER_SCRIPT" "sdd-harness model-router worker (classifier+policy)" --router-toml "$ROUTER_TOML"
      ;;
    wsl)
      if [ -d /run/systemd/system ] && systemctl --user show-environment >/dev/null 2>&1; then
        install_service_linux "$SENTINEL_SYSTEMD_UNIT" "$SENTINEL_SCRIPT" "sdd-harness model-router sentinel (front door)" --router-toml "$ROUTER_TOML"
        install_service_linux "$WORKER_SYSTEMD_UNIT" "$WORKER_SCRIPT" "sdd-harness model-router worker (classifier+policy)" --router-toml "$ROUTER_TOML"
      else
        note "Skipping persistent service: WSL without systemd enabled."
        note "  Enable it (add '[boot]\\nsystemd=true' to /etc/wsl.conf, then 'wsl --shutdown')"
      fi
      ;;
    *)
      note "Skipping persistent service: no launchd/systemd equivalent for a resident process on this OS."
      ;;
  esac
}

uninstall_services() {
  case "$(detect_os)" in
    macos)
      uninstall_service_macos "$SENTINEL_LAUNCHD_LABEL"
      uninstall_service_macos "$WORKER_LAUNCHD_LABEL"
      ;;
    linux|wsl)
      uninstall_service_linux "$SENTINEL_SYSTEMD_UNIT"
      uninstall_service_linux "$WORKER_SYSTEMD_UNIT"
      ;;
    *)
      note "No persistent service to remove on this OS."
      ;;
  esac
}

# Verifies: specs/model-router/requirements.md#10.3 (setup verifies by
# executing, not by assuming) — one real request through the sentinel's own
# public port; exit 1, touching nothing in settings.json, if nothing answers.
preflight_sentinel() {
  local url="$1" code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 -m 5 \
    -X POST "${url}/v1/messages" -H 'Content-Type: application/json' -d '{}' 2>/dev/null || true)"
  if [ -z "$code" ] || [ "$code" = "000" ]; then
    note "Preflight: sentinel not answering yet — retrying once after a short wait..."
    sleep 2
    code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 -m 5 \
      -X POST "${url}/v1/messages" -H 'Content-Type: application/json' -d '{}' 2>/dev/null || true)"
  fi
  if [ -z "$code" ] || [ "$code" = "000" ]; then
    die "preflight failed — sentinel at ${url} did not answer (got: ${code:-no response}). Nothing was written to $SETTINGS_JSON."
  fi
  note "Preflight passed — sentinel at ${url} answered with HTTP ${code}."
}

# Verifies: specs/model-router/requirements.md#10.2, #10.5, #3.4, #4.5a (the
# discover/install/preflight/wire algorithm, idempotent, with looped and
# reclaimed detection-and-repair).
cmd_install() {
  ensure_router_toml

  local fields sep
  fields="$(read_router_fields)" || die "failed to read $ROUTER_TOML (malformed TOML?)"
  sep=$'\x1f'
  local port upstream_stored
  port="${fields%%"$sep"*}"
  upstream_stored="${fields#*"$sep"}"
  local own_url="http://127.0.0.1:${port}"

  local is_first_run=0
  [ -z "$upstream_stored" ] && is_first_run=1

  local current
  current="$(read_current_base_url)" || die "failed to read $SETTINGS_JSON"

  local discovered_upstream=""
  if [ "$is_first_run" -eq 1 ]; then
    if [ "$current" = "$own_url" ]; then
      die "ANTHROPIC_BASE_URL already equals this router's own address ($own_url), but router.toml has never recorded a real upstream — this would create a self-forwarding loop with no real upstream ever known. Fix ANTHROPIC_BASE_URL in $SETTINGS_JSON manually (unset it, or point it at the real upstream), then re-run. Nothing was changed."
    fi
    discovered_upstream="$current"
  fi

  install_services
  preflight_sentinel "$own_url"

  if [ "$is_first_run" -eq 1 ]; then
    write_upstream_to_toml "$discovered_upstream" || die "failed to write discovered upstream into $ROUTER_TOML"
    note "Stored discovered upstream ($discovered_upstream) in router.toml — permanent; no later run will ever rewrite it."
    write_base_url_to_settings "$own_url" || die "failed to write ANTHROPIC_BASE_URL into $SETTINGS_JSON"
    note "Wired ANTHROPIC_BASE_URL -> $own_url in $SETTINGS_JSON."
  else
    if [ "$current" = "$own_url" ]; then
      note "Already wired correctly — ANTHROPIC_BASE_URL already points at $own_url. Nothing to repair."
    else
      note "ANTHROPIC_BASE_URL was reclaimed (currently: $current) — repairing to $own_url. router.toml's stored upstream ($upstream_stored) is left untouched."
      write_base_url_to_settings "$own_url" || die "failed to repair ANTHROPIC_BASE_URL in $SETTINGS_JSON"
    fi
  fi

  echo ""
  echo "router-setup complete. Proxy chain: claude -> sentinel ($own_url) -> worker -> upstream."
}

# Verifies: specs/model-router/requirements.md#10.5 (removable, restores
# unrouted behavior with no residual config).
cmd_uninstall() {
  if [ ! -f "$ROUTER_TOML" ]; then
    note "router.toml not found at $ROUTER_TOML — nothing to uninstall."
    return 0
  fi

  local fields sep
  fields="$(read_router_fields)" || die "failed to read $ROUTER_TOML (malformed TOML?)"
  sep=$'\x1f'
  local upstream_stored
  upstream_stored="${fields#*"$sep"}"

  if [ -z "$upstream_stored" ]; then
    die "router.toml's [router].upstream is empty — the router was never fully installed (first run never completed successfully). Not safe to guess what to restore; remove $ROUTER_TOML by hand if you want a clean slate."
  fi

  if [ "$upstream_stored" = "$SDK_DEFAULT_UPSTREAM" ]; then
    delete_base_url_from_settings || die "failed to remove ANTHROPIC_BASE_URL from $SETTINGS_JSON"
    note "ANTHROPIC_BASE_URL was unset before router-setup.sh ever ran (stored upstream is the SDK default) — removed the key from $SETTINGS_JSON rather than writing that literal string."
  else
    write_base_url_to_settings "$upstream_stored" || die "failed to restore ANTHROPIC_BASE_URL in $SETTINGS_JSON"
    note "Restored ANTHROPIC_BASE_URL -> $upstream_stored in $SETTINGS_JSON."
  fi

  uninstall_services

  echo ""
  echo "router-setup uninstall complete. $ROUTER_TOML is left in place (its stored upstream is reused if you reinstall)."
}

main() {
  local cmd="${1:-install}"
  case "$cmd" in
    install) cmd_install ;;
    uninstall) cmd_uninstall ;;
    *) die "unknown command: $cmd (expected 'install' or 'uninstall')" ;;
  esac
}

main "$@"
