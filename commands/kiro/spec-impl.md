---
description: Execute spec tasks using TDD methodology
allowed-tools: Read, Task, Skill, Write, Edit, Grep, Glob, Bash
argument-hint: <feature-name> [task-numbers]
---

# Implementation Task Executor

## Parse Arguments
- Feature name: `$1`
- Task numbers: `$2` (optional)
  - Format: "1.1" (single task) or "1,2,3" (multiple tasks)
  - If not provided: Execute all pending tasks

## Validate
Check that tasks have been generated:
- Verify `specs/$1/` exists
- Verify `specs/$1/tasks.md` exists

If validation fails, inform user to complete tasks generation first.

## Task Selection Logic

**Parse task numbers from `$2`** (perform this in Slash Command before invoking Subagent):
- If `$2` provided: Parse task numbers (e.g., "1.1", "1,2,3")
- Otherwise: Read `specs/$1/tasks.md` and find all unchecked tasks (`- [ ]`)

## Phase -1: Pre-Implementation Gates

Before delegating to the TDD agent, run this checklist against `specs/$1/tasks.md` and `specs/$1/design.md`. Surface any failure to the user and wait for confirmation before proceeding.

**Simplicity Gate**
- [ ] Implementation has ≤3 main components for this feature?
- [ ] No tasks contain "future-proof", "extensible", "generic", or "might need" language?

**Anti-Abstraction Gate**
- [ ] Tasks use framework features directly — no wrapper layers proposed without explicit rationale?
- [ ] Single data model representation (no parallel DTO/entity/domain object duplication)?

**Integration-First Gate**
- [ ] API contracts or interface definitions exist in design.md before any implementation task?
- [ ] At least one integration/contract test task appears before any unit-only implementation task?

**Decision-Budget Gate**
- [ ] Does every task leave the implementer *inheriting* decisions rather than making them?
- [ ] Is every deliberately-open freedom named in the task as delegated ("implementer's choice: X")?

The three gates above check for over-engineering and integration ordering — all
failures of *too much*. This one checks the opposite: under-specification. An
unnamed freedom is a spec gap, and it does not fail loudly. It produces working,
tested code that quietly embeds an architecture the user never chose, and it
surfaces later as a fat entry in the choices ledger. Naming the freedom is what
turns it from a silent decision into a delegated one.

If all gates pass: proceed to subagent invocation.
If any gate fails: show the failing item(s), ask the user to confirm or fix before continuing. This is a soft gate — user can override with "proceed anyway".

## Task Loop (one subagent per task — isolated context)

Resolve the target list (from `$2`, or all unchecked tasks). Then run the four
steps below **once per task**, in order, before starting the next task's Step 1.
Never batch multiple tasks into a single `spec-tdd-impl-agent` call — each task
gets its own fresh subagent invocation so one task's context never bloats into
the next.

### Step 1 — Implement
```
Task(
  subagent_type="spec-tdd-impl-agent",
  description="Execute TDD implementation for task {task_number}",
  prompt="""
Feature: $1
Spec directory: specs/$1/
Target tasks: {task_number}

File patterns to read:
- specs/$1/*.{json,md}
- .claude/steering/*.md

TDD Mode: strict (test-first)
"""
)
```

### Step 2 — Review (mandatory, every task)
Immediately after Step 1 returns, invoke `spec-refactor-agent` against only the
files that task touched. Do not skip this even for small tasks.
```
Task(
  subagent_type="spec-refactor-agent",
  description="Review task {task_number} implementation",
  prompt="""
Feature: $1
Task: {task_number}
Files touched: {file list from Step 1's summary}

Review for reuse, simplification, efficiency, security, error handling, and
boundary conditions. Fix confirmed issues and re-run tests.
"""
)
```

### Step 3 — Choices Ledger Audit
Run `/kiro:audit-choices $1` (or invoke `Skill("auditing-spec-choices")`
directly), scoped to this task's pass.

This runs **per task**, not once at the end. Waiting until the feature closes
means auditing a session trace that has already been compacted away and subagent
reports that no longer exist — the evidence is gone precisely when you need it.

It changes no code and never blocks: `needs-user` entries carry reversible
provisional calls so an unattended run completes with an open ledger. Skip it
only when the pass produced no code.

Feed the result back into this command's gates: entries clustering on one slice
means reslice it, and a pass heavy with `needs-user` means the Decision-Budget
Gate above should have failed.

### Step 4 — Checkpoint
Show this task's implementation summary, review findings, and ledger counts to
the user before Step 1 of the next task starts.

## Display Result

After the last task in the target list completes its Step 4, show the
aggregated choices-ledger counts across all tasks run this pass
(`sound` / `unsound` / `needs-user`) with the `needs-user` entries in full, then
provide next step guidance:

### Task Execution

**Execute specific task(s)**:
- `/kiro:spec-impl $1 1.1` - Single task
- `/kiro:spec-impl $1 1,2,3` - Multiple tasks

**Execute all pending**:
- `/kiro:spec-impl $1` - All unchecked tasks

**Close out the feature**:
- `/kiro:audit-choices $1 --close` - Resolve open `needs-user` calls and consolidate the ledger before calling the spec done

**Before Starting Implementation**:
- **IMPORTANT**: Clear conversation history and free up context before running `/kiro:spec-impl`
- This applies when starting first task OR switching between tasks
- Fresh context ensures clean state and proper task focus
