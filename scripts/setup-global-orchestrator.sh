#!/bin/bash
# One-time Windows Task Scheduler bootstrap for the SDD daily orchestrator.
# Creates a scheduled task "SDD Daily Orchestrator" that fires at 11:30 local
# every day. Uses "RunOnlyIfIdle=false" and "StartWhenAvailable=true" so the
# task runs as soon as possible after a missed start.
#
# Re-run this script to update the schedule or replace a broken task.

set -eu

TASK_NAME="SDD Daily Orchestrator"
WSL_DISTRO="${WSL_DISTRO_NAME:-Ubuntu}"
ORCHESTRATOR="$HOME/.claude/sdd-harness/scripts/daily-orchestrator.sh"
XML_PATH="/tmp/sdd-orchestrator-task.xml"

if [ ! -x "$ORCHESTRATOR" ]; then
  echo "ERROR: orchestrator not found or not executable at $ORCHESTRATOR" >&2
  exit 1
fi

if ! command -v schtasks.exe >/dev/null 2>&1; then
  echo "ERROR: schtasks.exe not on PATH. Are you in WSL?" >&2
  exit 1
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
      <StartBoundary>2026-01-01T11:30:00</StartBoundary>
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
    <WakeToRun>true</WakeToRun>
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

# Delete existing task if present (idempotent)
schtasks.exe /Query /TN "$TASK_NAME" >/dev/null 2>&1 && \
  schtasks.exe /Delete /TN "$TASK_NAME" /F >/dev/null 2>&1

# Create from XML
if schtasks.exe /Create /TN "$TASK_NAME" /XML "$WIN_XML_PATH" /F >/dev/null 2>&1; then
  echo "✓ Task '$TASK_NAME' created. Daily run at 11:30 local time."
  echo "  Verify: schtasks.exe /Query /TN \"$TASK_NAME\" /V /FO LIST"
  echo "  Run now: schtasks.exe /Run /TN \"$TASK_NAME\""
  echo "  Delete:  schtasks.exe /Delete /TN \"$TASK_NAME\" /F"
else
  echo "✗ schtasks.exe /Create failed" >&2
  exit 1
fi

rm -f "$XML_PATH"
