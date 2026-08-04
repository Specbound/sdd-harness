---
name: conductor-validator
description: "Validates Conductor project artifacts for completeness,"
  consistency, and correctness. Use after setup, when diagnosing issues, or
  before implementation to verify project context.
allowed-tools: Read Glob Grep Bash
metadata:
  model: opus
  color: cyan
risk: unknown
source: community
---

# Check if conductor directory exists
ls -la conductor/

# Find all track directories
ls -la conductor/tracks/

# Check for required files
ls conductor/index.md conductor/product.md conductor/tech-stack.md conductor/workflow.md conductor/tracks.md
```

## Use this skill when

- Validating a Conductor project for completeness or correctness
- Diagnosing Conductor setup issues or missing artifacts

## Do not use this skill when

- The task is unrelated to Conductor project validation

## Instructions

Read the conductor directory structure first. Check for: (1) required files (index.md, product.md, tech-stack.md, workflow.md, tracks.md), (2) valid track IDs matching `<type>_<name>_<YYYYMMDD>`, (3) consistent status markers ([ ], [~], [x]). Report what exists, what's missing, and what's malformed.

## Pattern Matching

**Status markers in tracks.md:**

```
- [ ] Track Name  # Not started
- [~] Track Name  # In progress
- [x] Track Name  # Complete
```

**Task markers in plan.md:**

```
- [ ] Task description  # Pending
- [~] Task description  # In progress
- [x] Task description  # Complete
```

**Track ID pattern:**

```
<type>_<name>_<YYYYMMDD>
Example: feature_user_auth_20250115
```
