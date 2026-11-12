#!/usr/bin/env bash
# router-setup.sh — configure the model router and wire/unwire
# ANTHROPIC_BASE_URL in each harness-active project so `claude` sessions there
# route through the sentinel.
#
# No resident OS service is installed. The sentinel, worker and jeff are
# started on demand by hooks/claude/router-session-hook.sh (via
# scripts/router/router-ctl.sh) when a wired project's session starts, and
# stopped when the last such session ends. Earlier versions installed launchd/
# systemd services; install and uninstall both remove those if present.
#
# Wiring is per project, never global: env.ANTHROPIC_BASE_URL goes into
# <project>/.claude/settings.local.json for each project in projects.txt whose
# .claude/settings.json registers router-session-hook.sh — the hook that
# starts the sentinel. A session in any other directory never points at a
# router that is not running. settings.local.json is used because update.sh
# rewrites settings.json from a template; settings.local.json is the user's.
#
# Usage:
#   router-setup.sh [install]   # default — configure/wire (idempotent)
#   router-setup.sh uninstall   # unwire every project, stop processes, remove legacy services
#
# What install does:
#   1. Resolves a Python interpreter >=3.11 via `uv python find`/`uv python
#      install 3.12` — never a bare `python3` (R10.8: this machine's system
#      python3 lacks `tomllib`).
#   2. Writes ~/.sdd-router/router.toml from the template when absent; never
#      overwrites an existing one.
#   3. First run only (empty [router].upstream): discovers the current
#      upstream — global ~/.claude/settings.json env.ANTHROPIC_BASE_URL, else
#      this shell's ANTHROPIC_BASE_URL (e.g. headroom exported from a shell
#      rc), else the SDK default https://api.anthropic.com — and stores it as
#      [router].upstream BEFORE anything is started. The sentinel refuses to
#      start without an upstream, so the old order (start, preflight, then
#      write) could never succeed on a first run. Never rewritten later.
#   4. Removes the legacy launchd/systemd units, if any.
#   5. Preflights by starting the router via router-ctl.sh under a setup-only
#      session, sending one real HTTP request through the sentinel's public
#      port, and stopping it again. Exits 1, wiring nothing, on failure.
#   6. Wires each eligible project's settings.local.json. If the global
#      settings.json still points at the sentinel (old global wiring), it is
#      restored to the stored upstream so non-harness sessions keep working.
#
# Looped-on-first-run refusal: if, on a first run, the discovered upstream
# already equals the sentinel's own address, there is no real upstream to
# record — this script refuses and exits 1 rather than guessing.
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
PROJECTS_TXT="${SDD_PROJECTS_TXT:-$HARNESS_DIR/projects.txt}"
ROUTER_CTL="$HARNESS_DIR/scripts/router/router-ctl.sh"
ROUTER_HOOK_NAME="router-session-hook.sh"
# SDK's own hardcoded fallback when ANTHROPIC_BASE_URL is absent/unset
# entirely (confirmed in the installed anthropic SDK's _client.py).
SDK_DEFAULT_UPSTREAM="https://api.anthropic.com"
SETUP_SESSION_ID="router-setup-preflight"

LEGACY_LAUNCHD_LABELS="com.sdd.router-sentinel com.sdd.router-worker com.sdd.jeff-classifier"
LEGACY_SYSTEMD_UNITS="sdd-router-sentinel.service sdd-router-worker.service sdd-jeff-classifier.service"

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "  $*"; }

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

# ── settings JSON — merge-not-overwrite, matching
# scripts/utils/headroom-unwire-if-dead.py's own proven shape exactly: read
# the whole JSON (missing file treated as {}), mutate only env.ANTHROPIC_BASE_URL,
# write the whole structure back so every other key survives untouched.

# read_base_url <settings-file> — prints env.ANTHROPIC_BASE_URL, or nothing.
read_base_url() {
  SETTINGS_JSON_PATH="$1" "$PYBIN" - <<'PY'
import json
import os

path = os.environ["SETTINGS_JSON_PATH"]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

env = data.get("env") if isinstance(data, dict) else None
if not isinstance(env, dict):
    env = {}

print(env.get("ANTHROPIC_BASE_URL") or "", end="")
PY
}

# write_base_url <settings-file> <url>
write_base_url() {
  SETTINGS_JSON_PATH="$1" NEW_BASE_URL="$2" "$PYBIN" - <<'PY'
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

# delete_base_url <settings-file> — removes the key entirely (and an `env`
# object it leaves empty) rather than writing a default value, since those are
# not the same starting state.
delete_base_url() {
  SETTINGS_JSON_PATH="$1" "$PYBIN" - <<'PY'
import json
import os

path = os.environ["SETTINGS_JSON_PATH"]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    raise SystemExit(0)

env = data.get("env") if isinstance(data, dict) else None
if isinstance(env, dict) and "ANTHROPIC_BASE_URL" in env:
    del env["ANTHROPIC_BASE_URL"]
    if not env:
        del data["env"]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY
}

# discover_upstream — global settings.json, then this shell's env, then the
# SDK default. The shell env matters: headroom-setup exports its proxy from a
# shell rc, and skipping it would route around headroom.
discover_upstream() {
  local from_settings
  from_settings="$(read_base_url "$SETTINGS_JSON")"
  if [ -n "$from_settings" ]; then
    echo "$from_settings"
  elif [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
    echo "$ANTHROPIC_BASE_URL"
  else
    echo "$SDK_DEFAULT_UPSTREAM"
  fi
}

# eligible_projects — projects.txt entries whose settings.json registers the
# hook that starts the sentinel. Literal substring match on the hook's name.
eligible_projects() {
  local project
  [ -f "$PROJECTS_TXT" ] || return 0
  while IFS= read -r project; do
    [ -n "$project" ] || continue
    [ -f "$project/.claude/settings.json" ] || continue
    grep -qF "$ROUTER_HOOK_NAME" "$project/.claude/settings.json" 2>/dev/null || continue
    echo "$project"
  done < "$PROJECTS_TXT"
}

# ── legacy OS services (pre on-demand design) ───────────────────────────────
remove_legacy_services() {
  local label unit plist
  case "$(uname -s 2>/dev/null)" in
    Darwin)
      for label in $LEGACY_LAUNCHD_LABELS; do
        plist="$HOME/Library/LaunchAgents/$label.plist"
        if launchctl list "$label" >/dev/null 2>&1; then
          launchctl unload "$plist" 2>/dev/null || true
        fi
        if [ -f "$plist" ]; then
          rm -f "$plist"
          note "Removed legacy LaunchAgent '$label' (router now starts on demand)."
        fi
      done
      ;;
    Linux)
      command -v systemctl >/dev/null 2>&1 || return 0
      for unit in $LEGACY_SYSTEMD_UNITS; do
        if [ -f "$HOME/.config/systemd/user/$unit" ]; then
          systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
          rm -f "$HOME/.config/systemd/user/$unit"
          systemctl --user daemon-reload >/dev/null 2>&1 || true
          note "Removed legacy systemd unit '$unit' (router now starts on demand)."
        fi
      done
      ;;
  esac
}

# Verifies: specs/model-router/requirements.md#10.3 (setup verifies by
# executing, not by assuming) — one real request through the sentinel's own
# public port; exit 1, wiring nothing, if nothing answers.
preflight_sentinel() {
  local url="$1" code
  bash "$ROUTER_CTL" up "$SETUP_SESSION_ID" \
    || die "router-ctl.sh could not start the router. Nothing was wired."
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 -m 5 \
    -X POST "${url}/v1/messages" -H 'Content-Type: application/json' -d '{}' 2>/dev/null || true)"
  bash "$ROUTER_CTL" down "$SETUP_SESSION_ID" >/dev/null 2>&1 || true
  if [ -z "$code" ] || [ "$code" = "000" ]; then
    die "preflight failed — sentinel at ${url} did not answer (got: ${code:-no response}). Nothing was wired."
  fi
  note "Preflight passed — sentinel at ${url} answered with HTTP ${code}."
}

# Verifies: specs/model-router/requirements.md#10.2, #10.5, #3.4 (discover/
# record/preflight/wire, idempotent, with looped detection).
cmd_install() {
  ensure_router_toml

  local fields sep
  fields="$(read_router_fields)" || die "failed to read $ROUTER_TOML (malformed TOML?)"
  sep=$'\x1f'
  local port upstream
  port="${fields%%"$sep"*}"
  upstream="${fields#*"$sep"}"
  local own_url="http://127.0.0.1:${port}"

  if [ -z "$upstream" ]; then
    upstream="$(discover_upstream)"
    if [ "$upstream" = "$own_url" ]; then
      die "ANTHROPIC_BASE_URL already equals this router's own address ($own_url), but router.toml has never recorded a real upstream — this would create a self-forwarding loop with no real upstream ever known. Unset it (or point it at the real upstream), then re-run. Nothing was changed."
    fi
    write_upstream_to_toml "$upstream" || die "failed to write discovered upstream into $ROUTER_TOML"
    note "Stored discovered upstream ($upstream) in router.toml — permanent; no later run will ever rewrite it."
  fi

  remove_legacy_services
  preflight_sentinel "$own_url"

  if [ "$(read_base_url "$SETTINGS_JSON")" = "$own_url" ]; then
    if [ "$upstream" = "$SDK_DEFAULT_UPSTREAM" ]; then
      delete_base_url "$SETTINGS_JSON" || die "failed to unwire $SETTINGS_JSON"
    else
      write_base_url "$SETTINGS_JSON" "$upstream" || die "failed to unwire $SETTINGS_JSON"
    fi
    note "Global $SETTINGS_JSON pointed at the router (old global wiring) — restored to $upstream."
  fi

  local project local_json wired=0
  while IFS= read -r project; do
    [ -n "$project" ] || continue
    local_json="$project/.claude/settings.local.json"
    if [ "$(read_base_url "$local_json")" = "$own_url" ]; then
      note "Already wired: $project"
    else
      write_base_url "$local_json" "$own_url" || die "failed to write ANTHROPIC_BASE_URL into $local_json"
      note "Wired ANTHROPIC_BASE_URL -> $own_url in $local_json."
    fi
    wired=$((wired+1))
  done <<EOF
$(eligible_projects)
EOF

  echo ""
  if [ "$wired" -eq 0 ]; then
    echo "router-setup complete, but no project is wired: none in $PROJECTS_TXT registers $ROUTER_HOOK_NAME in .claude/settings.json yet (run update.sh in each, then re-run this)."
  else
    echo "router-setup complete. $wired project(s) wired. Chain: claude -> sentinel ($own_url) -> worker -> $upstream; started on session start, stopped after the last session ends."
  fi
}

# Verifies: specs/model-router/requirements.md#10.5 (removable, restores
# unrouted behavior with no residual config).
cmd_uninstall() {
  if [ ! -f "$ROUTER_TOML" ]; then
    note "router.toml not found at $ROUTER_TOML — nothing to uninstall."
    return 0
  fi

  local fields sep port
  fields="$(read_router_fields)" || die "failed to read $ROUTER_TOML (malformed TOML?)"
  sep=$'\x1f'
  port="${fields%%"$sep"*}"
  local own_url="http://127.0.0.1:${port}"

  local project local_json
  [ -f "$PROJECTS_TXT" ] && while IFS= read -r project; do
    [ -n "$project" ] || continue
    local_json="$project/.claude/settings.local.json"
    if [ "$(read_base_url "$local_json")" = "$own_url" ]; then
      delete_base_url "$local_json" || die "failed to unwire $local_json"
      note "Unwired $local_json."
    fi
  done < "$PROJECTS_TXT"

  bash "$ROUTER_CTL" stop >/dev/null 2>&1 || true
  remove_legacy_services

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
