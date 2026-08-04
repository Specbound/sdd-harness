---
name: goal-mode
description: Run any dev task autonomously to completion — same workflow as interactive (TDD, debugging, planning) but loops without stopping until the goal condition is met
---

# Goal Mode

Same workflow as interactive development. Same skills. Same quality bar. The only difference: **Claude does not stop until the task is done.**

Use this when you want to hand off a well-defined task and walk away.

---

## Invoke when

- User says "do this as a goal", "don't stop until done", "run autonomously", "goal mode"
- User explicitly invokes `/goal-mode`
- Any task where the user wants zero interruptions from start to completion

---

## Phase 1: Formulate the Condition

Before doing anything else, translate the task into a verifiable `/goal` condition.

A good condition has three parts:

**1. One measurable end state** — a test result, build exit code, file state, or empty queue.
Examples:
- `all tests in test/auth pass and lint is clean`
- `the feature is implemented, committed, and npm test exits 0`
- `every call site in src/ uses the new API and the build succeeds`

**2. A stated check** — the command Claude will run to prove it (the evaluator reads the transcript, not files directly, so Claude must surface the result explicitly).
Examples:
- "`npm test` output shows 0 failures"
- "`git status` shows no unstaged changes"
- "`python -m pytest` exits 0 with N tests passing"

**3. A turn limit** — prevents runaway loops. Use: `or stop after N turns`.
- Simple bug fix / small feature: `or stop after 10 turns`
- Medium feature with TDD: `or stop after 20 turns`
- Large refactor / multi-file: `or stop after 35 turns`

**Announce the condition** before starting work. Format:
```
Goal condition: [condition here]
Starting in goal mode — will not stop until this condition is met or turn limit reached.
```

---

## Phase 2: Session Setup

Tell the user once (then continue immediately — don't wait):

> To enable fully uninterrupted execution:
> 1. Run `/goal [condition]` — sets the evaluator
> 2. Run `/auto` — approves tool calls without prompting
>
> Or run non-interactively: `claude -p "/goal [condition]"`

If the user invoked this via `/goal [condition]` already, skip this step entirely.

---

## Phase 3: Run the Right Workflow

Delegate to the appropriate sub-skill based on task type. **Do not reinvent — invoke the skill.**

| Task type | Invoke |
|---|---|
| New feature | `tdd-orchestrator` → `tdd-workflow` → `finishing-a-development-branch` |
| Bug fix | `systematic-debugging` |
| Refactor | `code-refactoring-refactor-clean` |
| Full-stack feature | `full-stack-orchestration-full-stack-feature` |
| Multi-step / unclear | `brainstorming` first → then appropriate sub-skill |
| Branch finalization | `finishing-a-development-branch` |

The sub-skill runs **exactly as it would interactively** — same quality, same steps, same rigor. Goal mode changes when Claude stops, not how Claude works.

---

## Phase 4: Autonomous Execution Rules

While running in goal mode:

1. **Do not stop to ask clarifying questions** — make a reasonable decision, document it in the transcript, continue. If something is truly ambiguous, state the assumption and proceed.

2. **Do not stop after each phase** — run tests, fix failures, repeat within the same turn if possible.

3. **Surface verification results explicitly** — run the check command (tests, lint, build) and print the output. The evaluator reads the transcript to decide if the condition is met.

4. **Self-check before ending any turn:**
   - Run the verification command
   - If passing → state it clearly: "Tests pass: 42/42. Lint clean. Condition met."
   - If failing → keep working, do not return control

5. **Commit at natural boundaries** — don't wait until the very end. Commit when a meaningful unit of work is complete (e.g. after each TDD cycle, after each fixed test).

6. **If genuinely blocked** (dependency missing, impossible requirement, permission error) → state the blocker clearly in one message and stop. Don't loop on something that cannot be resolved without user input.

---

## Phase 5: Completion

When the condition is met:

1. Run the final verification command and print output
2. State clearly: `Goal condition met: [restate condition]`
3. Give a one-paragraph summary: what was built/fixed, files changed, tests added, key decisions made
4. The `/goal` evaluator clears the goal automatically

---

## Condition Templates

Copy-paste starting points for common tasks:

**New feature with TDD:**
```
Feature [name] is implemented with tests, all tests pass (npm test / pytest exits 0), 
lint is clean, and the implementation is committed — or stop after 20 turns
```

**Bug fix:**
```
The bug described is fixed, the previously-failing test now passes, 
no existing tests are broken, and the fix is committed — or stop after 10 turns
```

**Refactor:**
```
[Target code] is refactored, all existing tests still pass, 
no behavior has changed, and the changes are committed — or stop after 25 turns
```

**Test suite cleanup:**
```
All tests in [path] pass, no skipped or xfail tests remain without justification, 
and coverage has not decreased — or stop after 15 turns
```

---

## How /goal evaluation works (background)

`/goal` is a session-scoped prompt-based Stop hook. After each turn, your configured small/fast model (Haiku by default) reads the condition + conversation and returns yes/no + a reason. "No" sends the reason to Claude as guidance for the next turn. "Yes" clears the goal. The evaluator **cannot run commands** — it only reads what Claude has written in the transcript. This is why surfacing verification output explicitly (Phase 4, rule 3) is critical.
