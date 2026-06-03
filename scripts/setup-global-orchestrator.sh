#!/bin/bash
# One-time Windows Task Scheduler bootstrap for the SDD daily orchestrator.
# Creates a scheduled task "SDD Daily Orchestrator" that fires at 18:00 local
# every day (evening, Israel time when Windows TZ = Jerusalem). Uses
# "RunOnlyIfIdle=false" and "StartWhenAvailable=true" so the task runs as soon
# as possible after a missed start. The SessionStart hook is a backup catch-up
# path: if the runner hasn't fired in >24h, opening a Claude session triggers it.
#
# Idempotent: re-running with no args is a no-op if the task already exists.
# Pass --force to delete and recreate (e.g. after editing the schedule here).

set -eu

# Self-locate the harness root (no hardcoded paths — see scripts/lib/resolve-harness-dir.sh)
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/lib/resolve-harness-dir.sh"

TASK_NAME="SDD Daily Orchestrator"
WSL_DISTRO="${WSL_DISTRO_NAME:-Ubuntu}"
ORCHESTRATOR="$HARNESS_DIR/scripts/daily-orchestrator.sh"
XML_PATH="/tmp/sdd-orchestrator-task.xml"

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

if ! command -v schtasks.exe >/dev/null 2>&1; then
  echo "ERROR: schtasks.exe not on PATH. Are you in WSL?" >&2
  exit 1
fi

# --- Idempotency check: skip if task already exists and --force not set ---
if [ "$FORCE" = false ] && schtasks.exe /Query /TN "$TASK_NAME" >/dev/null 2>&1; then
  echo "✓ Task '$TASK_NAME' already exists. Skipping (use --force to recreate)."
  exit 0
fi

# Build the XML. Windows Task Scheduler XML is locale-sensitive; this template
# is the minimal portable form. The trigger uses local time.
cat > "$XML_PATH" <<XML
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>SDD harness daily maintenance — runs daily-orchestrator.sh inside WSL.</Description>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2026-01-01T18:00:00</StartBoundary>
      <ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay>
      <Enabled>true</Enabled>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <StartWhenAvailable>true</StartWhenAvailable>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>wsl.exe</Command>
      <Arguments>-d $WSL_DISTRO -- bash -lc "$ORCHESTRATOR"</Arguments>
    </Exec>
  </Actions>
</Task>
XML

# Convert to UTF-16 LE BOM (Windows Task Scheduler XML import requires this)
iconv -f UTF-8 -t UTF-16LE "$XML_PATH" > "$XML_PATH.utf16"
printf '\xFF\xFE' | cat - "$XML_PATH.utf16" > "$XML_PATH"
rm "$XML_PATH.utf16"

# Convert WSL path to Windows path for schtasks
WIN_XML_PATH="$(wslpath -w "$XML_PATH")"

# Delete existing task if present (idempotent — only reached when --force or task missing)
schtasks.exe /Query /TN "$TASK_NAME" >/dev/null 2>&1 && \
  schtasks.exe /Delete /TN "$TASK_NAME" /F >/dev/null 2>&1

# Create from XML
if schtasks.exe /Create /TN "$TASK_NAME" /XML "$WIN_XML_PATH" /F >/dev/null 2>&1; then
  echo "✓ Task '$TASK_NAME' created. Daily run at 18:00 local time."
  echo "  Verify: schtasks.exe /Query /TN \"$TASK_NAME\" /V /FO LIST"
  echo "  Run now: schtasks.exe /Run /TN \"$TASK_NAME\""
  echo "  Delete:  schtasks.exe /Delete /TN \"$TASK_NAME\" /F"
else
  echo "✗ schtasks.exe /Create failed" >&2
  exit 1
fi

rm -f "$XML_PATH"
