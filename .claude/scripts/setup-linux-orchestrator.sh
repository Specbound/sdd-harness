#!/bin/bash
# Registers the SDD daily orchestrator via crontab on Linux (non-WSL).
# Fires at 18:00 local time every day.
#
# Idempotent: re-running is a no-op if the cron entry already exists.
# Pass --force to remove and re-add the entry.

set -eu

# Self-locate the harness root (no hardcoded paths — see scripts/lib/resolve-harness-dir.sh)
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/lib/resolve-harness-dir.sh"

ORCHESTRATOR="$HARNESS_DIR/scripts/daily-orchestrator.sh"
CRON_MARKER="sdd-daily-orchestrator"
CRON_ENTRY="0 18 * * * bash -lc \"$ORCHESTRATOR\" # $CRON_MARKER"

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

# Idempotency: skip if marker already present and not forcing
if [ "$FORCE" = false ] && crontab -l 2>/dev/null | grep -qF "$CRON_MARKER"; then
  echo "✓ Cron entry '$CRON_MARKER' already registered. Skipping (use --force to recreate)."
  exit 0
fi

# Remove any existing entry with this marker, then add the fresh one
( crontab -l 2>/dev/null | grep -vF "$CRON_MARKER"; echo "$CRON_ENTRY" ) | crontab -

echo "✓ Cron entry registered. Daily run at 18:00 local time."
echo "  Verify: crontab -l | grep $CRON_MARKER"
echo "  Remove: crontab -l | grep -vF '$CRON_MARKER' | crontab -"
