---
description: Audit and scaffold linter complexity rules for deterministic code quality enforcement
allowed-tools: Read, Task
argument-hint: [action:audit|scaffold|report]
---

# Guardrails — Deterministic Enforcement

## Parse Arguments
- Action: `$1` (optional, default: `audit`)

## Action Resolution

**audit** — Check existing linter config for complexity rules, report gaps (default)
**scaffold** — Create or enhance linter config with recommended complexity rules
**report** — Show current enforcement maturity level (L0-L3)

If `$1` is empty, default to `audit`.

## Invoke Subagent

Delegate to guardrails-agent:

```
Task(
  subagent_type="guardrails-agent",
  description="Audit and scaffold linter guardrails",
  prompt="""
Action: {$1 or 'audit'}

Read .claude/steering/tech.md to detect the project ecosystem (JS/TS, Python, Rust, Go, etc.).

If steering/tech.md is missing, auto-detect from:
- package.json → JS/TS ecosystem
- pyproject.toml / setup.py → Python ecosystem
- Cargo.toml → Rust ecosystem
- go.mod → Go ecosystem

Then execute the requested action:
- audit: Find and read existing linter configs, check for complexity rules, report what's present and what's missing
- scaffold: Create or update linter config with recommended complexity baselines
- report: Assess project enforcement maturity level (L0-L3) based on what's configured

Reference .claude/kiro/settings/rules/deterministic-enforcement.md for recommended baselines per ecosystem.
If .claude/memory/meta/graduations.md exists, read it to include graduated rules in the report.
"""
)
```

## Display Result

Show the structured guardrails report to the user.

### Next Steps Guidance

**If gaps found**:
- Run `/kiro:guardrails scaffold` to apply recommended rules
- Review proposed changes before accepting

**If fully configured**:
- Project has deterministic enforcement in place
- Run `/kiro:verify` to confirm lint passes with the new rules
- Consider running `/kiro:evolve` to identify further graduation candidates

**Maturity advancement**:
- L0 → L1: Run `/kiro:guardrails scaffold` to add baseline complexity rules
- L1 → L2: Run `/kiro:evolve` periodically to graduate steering conventions to linter rules
- L2 → L3: Ensure the full self-tightening loop is active (reflect → evolve → guardrails → verify)
