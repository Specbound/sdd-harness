---
name: writing-plans
description: "Use to write or execute a multi-step implementation/research plan before touching code: choosing plan weight, bite-sized task format, file-based planning for long/complex work, and batch-checkpoint execution."
risk: unknown
source: community
---

# Writing Plans

## Overview

Write plans assuming the engineer has zero context for the codebase and questionable
taste. Document everything they need: exact files to touch, exact code, exact test
commands, exact expected output. DRY, YAGNI, TDD, frequent commits.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

## Step 1: Choose Plan Weight

Weight scales with **unsupervised runtime before the next human checkpoint**, not task
size. A short task dispatched to a background/parallel session with no checkpoint until
the end earns the same fully-specified treatment as a large one. A task reviewed within
minutes can tolerate a looser plan.

| Weight | Use when | Format |
|---|---|---|
| **Lightweight checklist** | Small task, reviewed almost immediately, single session | Step 3 Lightweight Template |
| **Bite-sized full plan** | Long unsupervised run, handoff to another session/subagent | Step 4 Full Plan Template |
| **File-based persistent plan** | Multi-session, research, or task spans 15+ tool calls where context may reset | Step 5 File-Based Planning |

Default to **1-2 clarifying questions max**; make reasonable assumptions for everything
else non-blocking. Scan `README.md` / relevant code / constraints (language, frameworks,
tests) before drafting.

## Step 2: Task Breakdown Principles (apply to every weight)

- **Small, focused:** each task 2-5 minutes, one clear outcome, independently verifiable.
- **Specific, not generic:** "Install next-auth, create `/api/auth/[...nextauth].ts`" not
  "Add authentication". Name exact files, exact commands, exact expected output.
- **Logical ordering:** dependencies identified, verification phase always LAST.
- **Max 10 tasks** per plan file — if more, split into multiple plan files.
- **Project-specific scripts only** — never copy-paste a script list; include only what
  this task actually touches.
- Save full/bite-sized plans to `docs/plans/YYYY-MM-DD-<feature-name>.md`. Lightweight
  checklists for small tasks may save to `{task-slug}.md` in the project root instead —
  never inside `.claude/`, `docs/`, or a temp folder.

## Step 3: Lightweight Template

Use for small, quickly-reviewed tasks — 6-10 atomic, verb-first, ordered action items.

```markdown
# Plan
<High-level approach, 1-3 sentences>

## Scope
- In:
- Out:

## Action Items
- [ ] <Step 1: Discovery>
- [ ] <Step 2: Implementation>
- [ ] <Step 3: Validation/Testing>
- [ ] <Step 4: Commit>

## Open Questions
- <max 3>
```

Rule of thumb: if the plan is longer than one page, it's too long — simplify.

## Step 4: Full Plan Template (bite-sized)

Every full plan starts with this header:

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: use this skill's Step 6 (Executing a Plan) to
> implement this plan task-by-task.

**Goal:** [one sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [key technologies/libraries]
---
```

Each task:

```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**
​```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
​```
**Step 2: Run test, verify it fails** — `pytest tests/path/test.py::test_name -v` then FAIL
**Step 3: Write minimal implementation** (complete code, not "add validation")
**Step 4: Run test, verify it passes** then PASS
**Step 5: Commit** — `git add ... && git commit -m "feat: ..."`
```

Reference relevant skills with the `@` syntax inline where a task needs one.

## Step 5: File-Based Planning (complex/multi-session work)

For research tasks, multi-session work, or anything spanning many tool calls: filesystem
is persistent memory, context window is not. Create three files in the **project
directory** (not the skill directory):

| File | Purpose | Update when |
|---|---|---|
| `task_plan.md` | Goal, phases, decisions, error table | After each phase |
| `findings.md` | Research, discoveries | After ANY discovery (esp. images/PDF/browser output — screenshots don't persist) |
| `progress.md` | Session log, test results | Throughout session |

Starter templates: [templates/task_plan.md](templates/task_plan.md),
[templates/findings.md](templates/findings.md), [templates/progress.md](templates/progress.md).
Init all three at once with `scripts/init-session.sh`; verify phase completion with
`scripts/check-complete.sh` (exit 0 only when every phase's `**Status:**` is `complete`).

**Core rules:**
1. Create the plan file FIRST, before any work — non-negotiable.
2. **2-action rule:** after every 2 view/browser/search operations, immediately save
   findings to a file — multimodal/transient output is lost otherwise.
3. Re-read the plan before major decisions — keeps goals in the attention window.
4. Log every error, even ones fixed quickly — prevents repeating them.
5. Never repeat a failed action unchanged — mutate the approach.

**3-strike error protocol:** attempt 1 = diagnose & fix the root cause; attempt 2 = a
genuinely different method/tool (never retry the same failing action); attempt 3 =
question assumptions, consider updating the plan; after 3 failures, stop and escalate to
the user with what was tried and the exact error.

**5-question reboot test** (if you can answer all five, context is solid): Where am I?
(current phase) Where am I going? (remaining phases) What's the goal? (goal statement)
What have I learned? (findings.md) What have I done? (progress.md)

Skip file-based planning for simple questions, single-file edits, or quick lookups.

## Step 6: Executing a Plan

Load, review critically, execute in batches, checkpoint between batches.

**Announce:** "I'm using the executing-plans skill to implement this plan."

1. **Load and review:** read the plan file; raise concerns with the human before starting
   if any; otherwise create a TodoWrite and proceed.
2. **Execute a batch** (default: first 3 tasks): mark in_progress, follow steps exactly,
   run verification as specified, mark completed.
3. **Report:** show what was implemented, show verification output, say "Ready for
   feedback."
4. **Continue:** apply feedback if any, execute next batch, repeat until done.
5. **Finish:** once all tasks are complete and verified, hand off to whatever
   finishing/branch-completion skill this project uses.

**Stop and ask immediately when:** a blocker appears mid-batch (missing dependency,
failing test, unclear instruction), the plan has a gap that blocks starting, or
verification fails repeatedly. Don't force through blockers — ask.

**Return to Step 6 item 1** when the plan was updated based on feedback, or the approach
needs rethinking.

## Remember
- Exact file paths, complete code, exact commands with expected output — always.
- Plan weight is set by unsupervised runtime, not task size.
- Between execution batches: report and wait, don't keep going unprompted.
