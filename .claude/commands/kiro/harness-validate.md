---
description: Check structural integrity of the SDD harness — broken references, missing files, convention violations
allowed-tools: Read, Task, Glob
---

# Kiro Harness Validate — Structural Integrity Check

## Usage

```
/kiro:harness-validate
```

No arguments required. Validates the harness installation in the current project.

## Pre-Check

Verify `.claude/` directory exists. If not, report: "No harness installed. Run install.sh first."

## Invoke Subagent

Delegate to harness-validate-agent:

```
Task(
  subagent_type="harness-validate-agent",
  description="Validate harness structural integrity",
  prompt="""
Check the SDD harness installation in this project for structural integrity:

1. Verify all command → agent references are valid
2. Verify all agent → template references exist
3. Check memory file caps (hot-memory <50 lines, patterns <70 lines, observations <50 entries)
4. Verify L0 headers on all steering and memory files
5. Check rule file consistency

Report issues by severity and category.
"""
)
```

## Display Result

Show the validation report to the user.

## Append Trace

After receiving result, append to `.claude/memory/trace.log`:
```
YYYY-MM-DD HH:MM | harness-validate | haiku | {outcome} | fast
```

## Notes

- Run this after updating the harness (`update.sh`) to catch any structural drift
- Run this before starting a new spec to ensure the harness is healthy
- This is a read-only operation — it reports issues but does not fix them
- Tier 3 (Haiku) agent — this is mechanical validation work
