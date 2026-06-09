#!/usr/bin/env python3
"""
UserPromptSubmit hook: save the active Jira ticket when /kiro:jira-solve is invoked.

Reads hook stdin JSON, extracts the ticket ID from the prompt, writes it to
~/.claude/state/active_jira_ticket so the push hook can pick it up later.
"""
import json
import re
import sys
from pathlib import Path

data = json.load(sys.stdin)
prompt = data.get("prompt", "")
match = re.search(r"jira-solve\s+([A-Z]+-[0-9]+)", prompt)
if match:
    state_dir = Path.home() / ".claude" / "state"
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / "active_jira_ticket").write_text(match.group(1))
