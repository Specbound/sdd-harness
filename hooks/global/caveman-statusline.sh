#!/bin/bash
# caveman — statusline badge script for Claude Code
# Reads the caveman mode flag file and outputs a colored badge, plus a live
# context-usage meter parsed from the JSON Claude Code pipes to this script
# on stdin (see docs: context_window.used_percentage).
#
# Usage in ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "bash /path/to/caveman-statusline.sh" }
#
# Plugin users: Claude will offer to set this up on first session.
# Standalone users: install.sh wires this automatically.

# Consume stdin once, up front — everything else in this script reads flag
# files, not stdin, so this is the only place the JSON payload is available.
STDIN_JSON=$(cat 2>/dev/null || true)

FLAG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active"

# Badge/savings rendering is gated on caveman mode being active; the context
# meter below is NOT and must render regardless, so badge logic sets
# SHOW_BADGE=false instead of exiting the whole script.
SHOW_BADGE=true

# Refuse symlinks — a local attacker could point the flag at ~/.ssh/id_rsa and
# have the statusline render its bytes (including ANSI escape sequences) to
# the terminal every keystroke.
[ -L "$FLAG" ] && SHOW_BADGE=false
[ "$SHOW_BADGE" = true ] && [ ! -f "$FLAG" ] && SHOW_BADGE=false

if [ "$SHOW_BADGE" = true ]; then
  # Hard-cap the read at 64 bytes and strip anything outside [a-z0-9-] — blocks
  # terminal-escape injection and OSC hyperlink spoofing via the flag contents.
  MODE=$(head -c 64 "$FLAG" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]')
  MODE=$(printf '%s' "$MODE" | tr -cd 'a-z0-9-')

  # Whitelist. Anything else → render nothing rather than echo attacker bytes.
  case "$MODE" in
    off|lite|full|ultra|wenyan-lite|wenyan|wenyan-full|wenyan-ultra|commit|review|compress) ;;
    *) SHOW_BADGE=false ;;
  esac
fi

if [ "$SHOW_BADGE" = true ]; then
  if [ -z "$MODE" ] || [ "$MODE" = "full" ]; then
    printf '\033[38;5;172m[CAVEMAN]\033[0m'
  else
    SUFFIX=$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')
    printf '\033[38;5;172m[CAVEMAN:%s]\033[0m' "$SUFFIX"
  fi

  # Savings suffix: on by default. Opt out via CAVEMAN_STATUSLINE_SAVINGS=0.
  # Reads a pre-rendered string written by caveman-stats.js so we don't shell out
  # to node on every keystroke. Refuses symlinks and strips control bytes —
  # same hardening as the flag file (a local attacker could plant a file with
  # ANSI escape codes otherwise). Until /caveman-stats has run at least once,
  # the suffix file is absent and nothing is rendered — so the default is safe
  # for fresh installs (no fake number, no crash).
  if [ "${CAVEMAN_STATUSLINE_SAVINGS:-1}" != "0" ]; then
    SAVINGS_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-statusline-suffix"
    if [ -f "$SAVINGS_FILE" ] && [ ! -L "$SAVINGS_FILE" ]; then
      SAVINGS=$(head -c 64 "$SAVINGS_FILE" 2>/dev/null | tr -d '\000-\037')
      [ -n "$SAVINGS" ] && printf ' \033[38;5;172m%s\033[0m' "$SAVINGS"
    fi
  fi
fi

# Context-usage meter: on by default. Opt out via CAVEMAN_STATUSLINE_CONTEXT=0.
# Scoped explicitly to context_window.used_percentage — the payload also has
# rate_limits.five_hour.used_percentage / rate_limits.seven_day.used_percentage
# under the SAME key name at a different path, so a naive grep for
# "used_percentage" would silently pick up the wrong number. Absent/null
# before the first API response or right after /compact — no-ops rather than
# rendering a fake 0%.
if [ "${CAVEMAN_STATUSLINE_CONTEXT:-1}" != "0" ] && [ -n "$STDIN_JSON" ] && command -v python3 >/dev/null 2>&1; then
  PCT=$(printf '%s' "$STDIN_JSON" | python3 -c '
import json, sys, os, hashlib, time

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

cw = d.get("context_window") or {}
pct = cw.get("used_percentage")
if pct is None:
    sys.exit(0)
pct = int(round(float(pct)))
print(pct)

# Persist per-repo so the dashboard (a separate offline process) can show
# a "live-ish" reading alongside its existing retrospective session-frequency
# proxy. Keyed by project_dir/cwd since CLAUDE_CONFIG_DIR is machine-global,
# not per-repo. Best-effort — never fail the statusline over this.
try:
    ws = d.get("workspace") or {}
    repo_path = ws.get("project_dir") or ws.get("current_dir") or d.get("cwd") or ""
    if repo_path:
        cfg_dir = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
        state_dir = os.path.join(cfg_dir, "dashboard-context")
        os.makedirs(state_dir, exist_ok=True)
        key = hashlib.sha256(repo_path.encode()).hexdigest()[:16]
        with open(os.path.join(state_dir, key + ".json"), "w") as f:
            json.dump({"pct": pct, "repo_path": repo_path, "updated_at": int(time.time())}, f)
except Exception:
    pass
' 2>/dev/null || true)
  if [ -n "$PCT" ]; then
    if [ "$PCT" -ge 90 ]; then COLOR=196
    elif [ "$PCT" -ge 70 ]; then COLOR=220
    else COLOR=82
    fi
    printf ' \033[38;5;%sm%s%%ctx\033[0m' "$COLOR" "$PCT"
  fi
fi
