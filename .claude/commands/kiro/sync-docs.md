---
description: Sync documentation with code changes — prevents drift in specs, steering, and any .md referencing changed code
allowed-tools: Read, Task, Glob, Bash, Grep
---

# Kiro Sync Docs — Documentation Drift Prevention

## Detect Changes

Collect all changed files (uncommitted + staged + recent commits):

```bash
git diff --name-only          # uncommitted
git diff --cached --name-only # staged
git diff HEAD~1 --name-only   # last commit
```

Combine, deduplicate, and filter out `.md` files and `.claude/` paths (those are handled by the harness updater).

If no source files changed, report "No source changes detected — docs are current."

## Invoke Subagent

Delegate documentation sync to doc-sync agent:

Use the Task tool to invoke the Subagent:

```
Task(
  subagent_type="doc-sync",
  description="Sync docs with code changes",
  prompt="""
The following source files have changed:
{changed_files}

Find ALL .md files in the repo that document behavior affected by these changes.
Update only sections directly affected. Do not restructure unrelated sections.
Also check .claude/steering/*.md for new patterns not yet captured.

Skip: .venv/, .git/, __pycache__/
"""
)
```

## Display Result

Show Subagent summary to user:

### Docs Synced:
- Files updated (list)
- Sections changed (brief)
- Steering updates (if any)

### No Changes:
- "No source changes detected — docs are current."

## Notes

- This command catches ALL changes: uncommitted, staged, and recently committed
- The stop-hook runs this automatically at session end — this command is for manual trigger
- The post-commit git hook is a safety net that also triggers doc sync on commit
- Excludes .claude/ paths (harness updater handles SDD-SETUP-GUIDE separately)
- Excludes .md-only changes to avoid infinite loops
