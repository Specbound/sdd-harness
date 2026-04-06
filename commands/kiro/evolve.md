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
- .claude/memory/meta/*.md (including meta/graduations.md for graduation tracking)
- .claude/memory/observations.md
- .claude/memory/hot-memory.md

Also scan for enforceable patterns (Step 2b):
- Read .claude/steering/*.md for conventions that could be linter rules
- Check for [enforceable] tagged observations
- Check existing linter config to avoid proposing already-enforced rules
- Use the graduate-to-linter proposal type for enforceable patterns

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
- Now includes **graduation proposals** — conventions that can be promoted from markdown docs to deterministic linter enforcement
- After approving a `graduate-to-linter` proposal, run `/kiro:guardrails scaffold` to apply the linter rule change
- Graduation history tracked in `.claude/memory/meta/graduations.md`
