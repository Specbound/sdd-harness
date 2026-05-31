#!/bin/bash
# Registers the SDD daily orchestrator as a macOS LaunchAgent.
# Fires at 18:00 local time every day via launchd.
#
# Idempotent: re-running is a no-op if the agent is already loaded.
# Pass --force to unload and re-register (e.g. after editing the schedule).

set -eu

LABEL="com.sdd.daily-orchestrator"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
ORCHESTRATOR="$HOME/.claude/sdd-harness/scripts/daily-orchestrator.sh"
LOG_DIR="$HOME/.claude/sdd-harness/logs"

FORCE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [ ! -x "$ORCHESTRATOR" ]; then
  echo "ERROR: orchestrator not found or not executable at $ORCHESTRATOR" >&2
  exit 1
fi

# Idempotency: skip if already loaded and not forcing
if [ "$FORCE" = false ] && launchctl list "$LABEL" >/dev/null 2>&1; then
  echo "✓ LaunchAgent '$LABEL' already loaded. Skipping (use --force to recreate)."
  exit 0
fi

# Unload existing agent if present (covers --force path and stale plist)
if launchctl list "$LABEL" >/dev/null 2>&1; then
  launchctl unload -w "$PLIST_PATH" 2>/dev/null || true
fi

mkdir -p "$PLIST_DIR" "$LOG_DIR"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-lc</string>
        <string>${ORCHESTRATOR}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>18</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/orchestrator.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/orchestrator.stderr.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLIST

if launchctl load -w "$PLIST_PATH"; then
  echo "✓ LaunchAgent '$LABEL' registered. Daily run at 18:00 local time."
  echo "  Plist: $PLIST_PATH"
  echo "  Verify: launchctl list $LABEL"
  echo "  Run now: launchctl start $LABEL"
  echo "  Remove: launchctl unload -w $PLIST_PATH && rm $PLIST_PATH"
else
  echo "✗ launchctl load failed" >&2
  exit 1
fi
