---
description: Structured ideation to refine a vague idea into a clear spec-ready brief
allowed-tools: Read, Glob, Agent
argument-hint: <rough-idea-description>
---

# Idea Refinement

## Parse Arguments
- Rough idea: `$ARGUMENTS`

## Validation
- If `$ARGUMENTS` is empty, ask user: "What's the rough idea or problem you want to explore?"

## Invoke Subagent

Delegate ideation to idea-refine-agent:

```
Agent(
  subagent_type="idea-refine-agent",
  description="Refine idea into spec brief",
  prompt="""
Rough idea: {$ARGUMENTS}

Load `.claude/steering/product.md` and `.claude/steering/tech.md` for project context.
Refine the rough idea into a clear, actionable brief ready for `/kiro:spec-init`.

Return: problem statement, proposed solution brief, key constraints, and suggested spec-init description.
"""
)
```

## Display Result

Show the refined brief to the user.

### Next Steps Guidance

**If user approves the brief**:
- Start the spec workflow: `/kiro:spec-quick <refined-description>` or `/kiro:spec-init <refined-description>`

**If user wants to iterate**:
- Re-run with updated idea: `/kiro:idea-refine <updated-description>`
