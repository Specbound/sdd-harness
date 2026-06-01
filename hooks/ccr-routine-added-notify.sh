#!/bin/bash
# Fires PostToolUse (CronCreate) — injects a documentation reminder into Claude's
# context after a new CCR routine is created.

set -euo pipefail

EVENT=$(cat)

# Extract routine name and schedule from the tool output
ROUTINE_NAME=$(echo "$EVENT" | python3 -c "
import json, sys
try:
    e = json.load(sys.stdin)
    inp = e.get('tool_input', {})
    print(inp.get('name', inp.get('label', inp.get('description', '(unknown)'))))
except Exception:
    print('(unknown)')
" 2>/dev/null || echo "(unknown)")

SCHEDULE=$(echo "$EVENT" | python3 -c "
import json, sys
try:
    e = json.load(sys.stdin)
    inp = e.get('tool_input', {})
    print(inp.get('schedule', inp.get('cron', '(check claude.ai/code/routines)')))
except Exception:
    print('(check claude.ai/code/routines)')
" 2>/dev/null || echo "(check claude.ai/code/routines)")

ROUTINE_ID=$(echo "$EVENT" | python3 -c "
import json, sys
try:
    e = json.load(sys.stdin)
    out = e.get('tool_result', e.get('output', {}))
    if isinstance(out, dict):
        print(out.get('id', out.get('trigger_id', '')))
    else:
        print('')
except Exception:
    print('')
" 2>/dev/null || echo "")

ID_LINE=""
if [[ -n "$ROUTINE_ID" ]]; then
  ID_LINE="║  ID: $ROUTINE_ID"
fi

cat << EOF
╔══ CCR Routine Documentation Required ═════════════════════════════╗
║  New CCR routine created: $ROUTINE_NAME
║  Schedule: $SCHEDULE
$ID_LINE
║                                                                   ║
║  Update docs/ccr-routines/README.md before this session ends.    ║
║                                                                   ║
║  Add a section under Active Routines with:                        ║
║    - ID and URL (https://claude.ai/code/routines/<ID>)           ║
║    - Schedule (cron expression + human-readable)                  ║
║    - What it does and what it outputs                             ║
║    - Why it exists                                                ║
║    - How to use the output                                        ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
