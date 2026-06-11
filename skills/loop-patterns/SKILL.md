---
name: loop-patterns
description: Library of 8 named agentic dev loops (ship PR, self-review, spec-first, coverage, E2E, etc.) with kickoff prompt templates and loop contract format. Use when user wants to run a named loop or design a new one.
---

# Loop Patterns

Pre-built, self-pacing agentic loops for common dev workflows. Each loop runs until an exit condition is met or a max iteration cap is hit — no manual re-triggering required.

## When to Activate

- User says "run the ship PR loop", "start a self-review loop", "de-sloppify", "spec-first ship"
- User invokes `/kiro:loop`
- User asks "what loops are available?"
- User wants to design a new self-pacing loop
- Any task that naturally fits a check-loop-exit pattern

## Do Not Use When

- Task is one-shot (no iteration value)
- Task belongs to `iterative-repair-loop` (structured JSON artifact repair)
- Task belongs to `goal-mode` (fully autonomous until `/goal` evaluator fires)

---

## The Loop Contract

Every loop is defined by five fields:

```
Start the "[Name]" loop.

Goal: [measurable end state]
Max iterations: [N, or "until done"]
Between iterations run: [check command]
Exit when: [condition — what the check command must show]

Step 1: [initial action]

Self-pace this loop. After each iteration, run the check command, read the output,
and only continue if the exit condition is not met. Stop when the exit condition
passes or max iterations is reached. Give a short status update each pass.
```

The **between-iterations command** is the loop's heartbeat — Claude runs it after each pass and reads the output to decide whether to continue.

---

## Named Loop Library

### 1. Ship PR Until Green
**Category:** CI  
**Goal:** PR is open with all CI checks passing  
**Max iterations:** 10  
**Check cmd:** `gh pr checks`  
**Exit when:** all PR checks show `success`

```
Start the "Ship PR Until Green" loop.

Goal: PR is open with all CI checks passing
Max iterations: 10
Between iterations run: gh pr checks
Exit when: all PR checks are success

Step 1: Implement the change, test locally, push, open PR, and fix CI until green.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

---

### 2. De-Sloppify Pass
**Category:** Review / Cleanup  
**Goal:** Recent changes are clean, minimal, and convention-aligned  
**Max iterations:** 4  
**Check cmd:** `npm run lint && npm test`  
**Exit when:** review finds no slop and checks pass

```
Start the "De-Sloppify Pass" loop.

Goal: recent changes clean, minimal, convention-aligned
Max iterations: 4
Between iterations run: npm run lint && npm test
Exit when: review finds no slop and checks pass

Step 1: Review the recent diff for debug code, dead code, naming issues, convention violations. Fix what you find, then run the check.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

---

### 3. Spec-First Ship
**Category:** Planning / Implementation  
**Goal:** Every requirement in spec.md is implemented and checked off  
**Max iterations:** 15  
**Check cmd:** `npm test`  
**Exit when:** spec.md has no unchecked requirements

```
Start the "Spec-First Ship" loop.

Goal: every requirement in spec.md is implemented and checked off
Max iterations: 15
Between iterations run: npm test
Exit when: spec.md has no unchecked requirements

Step 1: Read spec.md, identify the first unchecked requirement, implement it, check it off, run tests.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

---

### 4. Build Until Green
**Category:** Build  
**Goal:** Production build succeeds with no errors  
**Max iterations:** until done  
**Check cmd:** `npm run build`  
**Exit when:** build exits 0

```
Start the "Build Until Green" loop.

Goal: production build succeeds with no compile or bundling errors
Max iterations: until done
Between iterations run: npm run build
Exit when: build exits 0

Step 1: Run the build. If it fails, fix the first error, then repeat until green.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

---

### 5. Coverage Until Threshold
**Category:** Testing  
**Goal:** Test coverage ≥ 80% without changing production behavior  
**Max iterations:** until done  
**Check cmd:** `npm test --coverage`  
**Exit when:** coverage threshold is met

```
Start the "Coverage Until Threshold" loop.

Goal: test coverage meets threshold (80%) without changing production behavior
Max iterations: until done
Between iterations run: npm test --coverage
Exit when: coverage threshold is met

Step 1: Run coverage report, identify the lowest-covered module, add focused tests for it.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

---

### 6. E2E Until Green
**Category:** Testing  
**Goal:** E2E suite passes  
**Max iterations:** until done  
**Check cmd:** `npm run test:e2e`  
**Exit when:** E2E exits 0

```
Start the "E2E Until Green" loop.

Goal: end-to-end test suite passes
Max iterations: until done
Between iterations run: npm run test:e2e
Exit when: E2E exits 0

Step 1: Run E2E. Fix the first failing test (UI or integration), re-run to confirm, then continue.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

---

### 7. PR Self-Review
**Category:** Review  
**Goal:** Three clean senior-level review passes on the current diff  
**Max iterations:** 3  
**Check cmd:** `git diff main...HEAD`  
**Exit when:** three passes complete with no critical findings

```
Start the "PR Self-Review" loop.

Goal: three clean self-review passes with no critical findings
Max iterations: 3
Between iterations run: git diff main...HEAD
Exit when: three passes complete with no critical findings

Step 1: Read the full diff. Review for correctness bugs, missing tests, security issues, naming problems. Fix what you find.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

---

### 8. Pre-Commit Guard
**Category:** Event / Hook  
**Goal:** Tests pass before every commit; never commit red  
**Max iterations:** until green  
**Check cmd:** `npm test`  
**Exit when:** tests exit 0

```
Start the "Pre-Commit Guard" loop.

Goal: tests pass before committing — never commit with a red suite
Max iterations: until green
Between iterations run: npm test
Exit when: tests exit 0

Step 1: Run the test suite. If red, fix the failures before committing.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

---

## Authoring a New Loop

Follow the five-field contract. Good loops have:

1. **Measurable goal** — a state you can verify, not a vague intent
2. **Cheap check command** — fast to run after each iteration (lint, test, build status)
3. **Binary exit condition** — either met or not; no ambiguity
4. **Appropriate cap** — prevent runaway loops: use a number for bounded tasks, "until done" only for truly open-ended repair
5. **Concrete Step 1** — the first action; don't make Claude decide where to start

### Adapting for non-npm projects

Replace check commands with project equivalents:

| Situation | Replace with |
|---|---|
| Python project | `pytest` / `ruff check .` |
| Go project | `go build ./...` / `go test ./...` |
| Rust project | `cargo build` / `cargo test` |
| Custom CI | `gh pr checks` (works for any stack) |
| Coverage (Python) | `pytest --cov --cov-fail-under=80` |

---

## Relation to Other Skills

- **`iterative-repair-loop`** — use when you need structured JSON handoffs and remaining-delta tracking for a specific artifact. Heavier; better for document/spec repair.
- **`goal-mode`** — use when you want fully autonomous execution with the `/goal` evaluator and delegation to sub-skills. More powerful; requires `/goal` setup.
- **`/loop` command** — use for interval-based recurring tasks (e.g., "check CI every 5 min"). Not task-driven.
- **`loop-patterns`** (this skill) — use for named, check-command-driven dev workflows. Lightweight; works anywhere.
