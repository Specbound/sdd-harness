---
description: Audit harness rules effectiveness, propose improvements
allowed-tools: Read, Task, Glob, Bash
---

# Kiro Evolve — Harness Architecture Audit

## Pre-check

Use Glob to verify `.claude/memory/meta/` exists. If missing, tell user to run `/kiro:reflect` first to bootstrap memory.

## Invoke Subagent

Delegate audit to evolve-agent:

Use the Task tool to invoke the Subagent:

```
Task(
  subagent_type="evolve-agent",
  description="Audit harness rules and propose improvements",
  prompt="""
Audit the SDD harness rules for effectiveness and propose improvements.

File patterns to read:
- .claude/kiro/settings/rules/*.md
- .claude/memory/meta/*.md
- .claude/memory/observations.md
- .claude/memory/hot-memory.md

JIT Strategy: Fetch codebase files when needed, not upfront.
"""
)
```

## Display Result

Show Subagent summary to user:

### Evolve Audit:
- Scorecard (memory health metrics)
- Friction patterns detected
- Proposed rule changes (for user approval)
- Self-observations appended

## Notes

- Run on demand to improve harness effectiveness
- Proposed changes are NEVER applied automatically — user must approve
- Audits the rules themselves, not the project code
- Findings appended to `meta/self-observations.md`
