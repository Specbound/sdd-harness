---
description: Smoke-test harness prompts using Haiku to expose vague instructions and implicit assumptions
allowed-tools: Read, Task, Glob, Bash
---

# Kiro Harness Test — Haiku Smoke Testing

## Purpose

Run key harness workflows at Haiku tier (cheapest model) to stress-test prompt quality. If prompts produce correct results with Haiku, they are well-structured. Failures at Haiku tier expose:
- Vague or ambiguous instructions
- Implicit assumptions not captured in prompts
- Over-reliance on model intelligence instead of clear structure

## Usage

```
/kiro:harness-test [agent-name]
```

- No arguments: runs the standard smoke-test suite
- `agent-name`: test a specific agent only

## Standard Smoke-Test Suite

### Test 1: Steering Generation

Invoke the steering agent at Haiku tier on the current project:

```
Task(
  subagent_type="steering",
  model="haiku",
  description="Smoke-test: steering generation",
  prompt="""
Generate steering documentation for this project.
Read the codebase structure and produce product.md, tech.md, and structure.md.
Follow .claude/kiro/settings/rules/steering-principles.md exactly.

File patterns:
- .claude/kiro/settings/rules/steering-principles.md
- .claude/kiro/settings/templates/steering/*.md
"""
)
```

**Pass criteria**: Output includes all 3 steering file types with relevant content. Reject if output is generic boilerplate unrelated to the actual project.

### Test 2: Harness Validation

Invoke harness-validate at Haiku tier:

```
Task(
  subagent_type="harness-validate-agent",
  model="haiku",
  description="Smoke-test: harness validation",
  prompt="""
Check the SDD harness installation for structural integrity.
Validate command → agent references, template existence, memory caps, and L0 headers.
"""
)
```

**Pass criteria**: Produces a structured report with component counts and issue list. Reject if format is wrong or categories are missed.

### Test 3: Design Review (if spec exists)

Find any existing spec:
```bash
ls specs/*/design.md 2>/dev/null | head -1
```

If a spec exists, invoke validate-design at Haiku tier:

```
Task(
  subagent_type="validate-design-agent",
  model="haiku",
  description="Smoke-test: design review",
  prompt="""
Feature: {detected-feature}
Spec directory: specs/{detected-feature}/
File patterns: specs/{detected-feature}/*.md, .claude/steering/*.md, .claude/kiro/settings/rules/design-review.md
"""
)
```

**Pass criteria**: Produces structured output with examination summary, observations, and GO/NO-GO decision.

## Reporting

```
## Harness Smoke-Test Results

| Test | Agent | Result | Notes |
|------|-------|--------|-------|
| Steering | steering | PASS/FAIL | [brief note] |
| Validation | harness-validate | PASS/FAIL | [brief note] |
| Design Review | validate-design | PASS/FAIL or SKIPPED | [brief note] |

### Failures
[For each failure: what went wrong, which prompt needs improvement]

### Recommendations
[Specific prompt improvements based on failures]
```

## Notes

- Haiku failures are a QA signal about harness quality, not Haiku quality
- Run this after making changes to agent prompts or rules
- If an agent consistently fails at Haiku, its prompt needs clarification — add structure, examples, or constraints
- Results are informational only — they don't block any workflow
