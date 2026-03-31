---
description: Run verification pipeline (build, types, lint, test, audit, git status)
allowed-tools: Read, Task
argument-hint: [mode:quick|full|pre-commit|pre-pr]
---

# Verification Pipeline

## Parse Arguments
- Mode: `$1` (optional, default: `full`)

## Mode Resolution

**quick** — Build + Test only (fast feedback loop)
**full** — All 6 stages (default)
**pre-commit** — Build + Types + Lint + Test (skip audit and git status)
**pre-pr** — All 6 stages + stricter thresholds

If `$1` is empty, default to `full`.

## Invoke Subagent

Delegate verification to verify-agent:

```
Task(
  subagent_type="verify-agent",
  description="Run verification pipeline",
  prompt="""
Mode: {$1 or 'full'}

Read .claude/steering/tech.md to discover:
- Build command (e.g., npm run build, cargo build, go build ./...)
- Type check command (e.g., npx tsc --noEmit, mypy .)
- Lint command (e.g., ruff check, npx eslint .)
- Test command (e.g., pytest, npm test, go test ./...)

If steering/tech.md is missing or doesn't specify commands, attempt auto-detection from package.json, Cargo.toml, pyproject.toml, Makefile, or go.mod.

Execute the pipeline for the specified mode and return a structured report.
"""
)
```

## Display Result

Show the structured PASS/FAIL report to the user.

### Next Steps Guidance

**If READY**:
- Code is verified and ready for next phase
- Consider `/kiro:validate-impl` for spec alignment check

**If NOT READY**:
- Review failed stages in the report
- For build failures: run `/kiro:fix-build` for automatic resolution
- For test failures: fix failing tests and re-run `/kiro:verify quick`
- For lint issues: most can be auto-fixed by the linter (e.g., `ruff check --fix`)
