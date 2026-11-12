#!/bin/bash
# router-session-hook.sh — SessionStart/SessionEnd hook that keeps the model
# router (sentinel + worker + jeff) running only while a harness-active
# session needs it. Registered for both events; the event name in the hook
# input picks `up` or `down`.
#
# A project is routed only when router-setup.sh wired its
# .claude/settings.local.json (env.ANTHROPIC_BASE_URL -> sentinel). An
# unwired project is a no-op here, so nothing starts for it.
#
# SessionStart failure is loud: a wired session whose sentinel is not
# listening cannot reach the API at all.

HOOK_INPUT="$(cat 2>/dev/null || true)"
EVENT="$(printf '%s' "$HOOK_INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
SESSION_ID="$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
[ -n "$SESSION_ID" ] || exit 0

SDD_ROOT="$(cat "$HOME/.sdd-harness-root" 2>/dev/null || true)"
CTL="$SDD_ROOT/scripts/router/router-ctl.sh"
[ -n "$SDD_ROOT" ] && [ -f "$CTL" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

case "$EVENT" in
  SessionStart)
    bash "$CTL" wired "$PROJECT_DIR" || exit 0
    if ! out="$(bash "$CTL" up "$SESSION_ID" 2>&1)"; then
      echo "[ROUTER-DOWN] $out"
      echo "This project routes API calls through the model router, which failed to start. Tell the user; fix with: bash $SDD_ROOT/scripts/setup/router-setup.sh (or 'uninstall' to unroute)."
    fi
    ;;
  SessionEnd)
    bash "$CTL" down "$SESSION_ID" >/dev/null 2>&1 || true
    ;;
esac
exit 0
