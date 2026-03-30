# Skill Extraction Scoring Rubric

## Overview
When extracting skills from a repository, score each candidate module against four criteria. This rubric ensures only genuinely reusable, non-obvious knowledge becomes a skill.

## Scoring Criteria (0-3 each)

| Criterion | 0 (Skip) | 1 (Low) | 2 (Medium) | 3 (High) |
|-----------|----------|---------|------------|----------|
| **Recurrence** | One-off script or business logic | Used in 2-3 places within the repo | Common cross-project pattern | Universal pattern applicable anywhere |
| **Code Quality** | Undocumented, tangled, no tests | Partially documented, some structure | Well-structured with clear interfaces | Exemplary: documented, tested, idiomatic |
| **Domain Expertise** | Trivial or obvious implementation | Some useful insight | Non-obvious patterns requiring experience | Deep specialist knowledge hard to find elsewhere |
| **Generalizability** | Tightly coupled to this repo only | Reusable within the same domain | Applicable across related domains | Universal utility across any project |

## Threshold
- **Include in plan**: Score >= 6 out of 12
- **High priority**: Score >= 9 out of 12
- **Skip**: Score < 6

## Scoring Modifiers
Apply after base scoring:

| Modifier | Condition | Adjustment |
|----------|-----------|------------|
| Existing overlap | A similar skill already exists in `~/.claude/skills/` | -2 |
| Good documentation | Module has its own README, docstrings, or inline docs | +1 |
| Test coverage | Module has associated test files | +1 |
| Heavy coupling | Module requires 3+ repo-specific dependencies to function | -1 |

## What Makes a Good Skill Candidate

**Extract**:
- Workflow patterns (how to set up, configure, deploy something)
- Domain-specific decision trees (when to use X vs Y)
- Non-obvious integration patterns (gotchas, workarounds, best practices)
- Architecture patterns with concrete implementation guidance
- Error handling strategies specific to a domain or tool

**Skip**:
- Thin wrappers around well-documented APIs
- Business logic specific to the repo's domain model
- Configuration files without explanatory context
- Boilerplate that any scaffold generator produces
- Code that merely follows a framework's tutorial patterns

## Deduplication
Before scoring, cross-reference candidate names and descriptions against existing skills:
1. Glob `~/.claude/skills/*/SKILL.md`
2. Read frontmatter (name + description) of potential matches
3. If an existing skill covers >70% of the candidate's scope, apply the -2 overlap modifier
4. Note the existing skill name in the extraction plan for reference
