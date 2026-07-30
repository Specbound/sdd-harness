---
name: loop-patterns
description: Library of 10 named agentic dev loops (ship PR, self-review, coverage, E2E, fresh-clone onboarding, feedback sweep, etc.) with kickoff templates and loop contract format. Use to run a named loop or design a new one.
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

## Loop Guardrails

A self-pacing loop has two failure modes: it **stops too early** (a half-passing check looks like success) and it **runs away** (it spins forever, or hammers the same failing approach). The cap alone catches neither — it only bounds total spend. Every loop carries these guardrails regardless of which named loop is running.

### Dual-condition exit (guards stopping too early)

Do **not** exit on the check command alone. Before declaring the loop done, confirm **both**:

1. The check command output objectively meets the exit condition (e.g. exit 0, all checks `success`, coverage ≥ threshold), AND
2. You can state in one line *why* that output means the goal is truly met — not flaky-green, not a partial pass, not a skipped suite.

If the check passes but condition 2 is shaky, treat it as not met and do one more verifying pass. State the explicit confirmation in the status update before stopping.

### Circuit breakers (guard runaway), checked every pass

Abort the loop early — independent of the max-iteration cap — when either fires:

- **No-progress:** 2 consecutive passes where the check output is no closer to the goal (same failure count, same coverage number, same unchecked count). Stalled, not converging.
- **Same-error:** 2 consecutive passes failing on the **identical** error/test. The current approach is wrong; repeating it won't help.

On trip, **stop and report** — name the breaker, show the repeated output, and hand back to the user. Never silently keep looping. Optionally add explicit fields to the contract to tune thresholds:

```
Stop early if: same error 2 passes in a row, OR no measurable progress for 2 passes.
```

### Fresh/clean state (guards false-green from a dirty environment)

When the loop's goal is about reproducibility, onboarding, or setup — anything a stale local environment could mask — run each verifying pass from a **disposable, dependency-free state** (fresh temp dir, clean clone, new session), not your already-warmed workspace. A check that only passes because your machine is pre-configured is a false green. Fix the artifact (docs, scripts, config), never the throwaway environment.

### Cross-run state (guards redundant rework across repeat runs)

When a loop runs repeatedly over the same target (a codebase, a dataset, a review queue), two techniques stop it from re-litigating or re-reporting what a prior pass already resolved:

- **Disposition ledger** — a state machine tracking every finding/candidate through its lifecycle (e.g. candidate → verified / rejected), each transition backed by an evidence receipt. Without it, the loop can silently reopen something it already resolved.
- **Monotonic knowledge base** — a persistent dedup store carried across repeat runs of the same loop, so re-running doesn't rediscover and re-report the same already-known issue.

Both are general-purpose techniques for any loop that revisits the same target across runs — not just security-audit loops.

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

### 9. Fresh-Clone Onboarding
**Category:** Onboarding / Docs  
**Goal:** A new dev can go from clean clone to running project using only the README/install docs — no hidden setup  
**Max iterations:** 5  
**Check cmd:** `setup in a fresh temp dir following ONLY the docs, then run the project's smoke check`  
**Exit when:** a from-scratch run succeeds with zero undocumented steps

```
Start the "Fresh-Clone Onboarding" loop.

Goal: a new dev reaches a running project using only the README/install docs — no hidden setup assumptions
Max iterations: 5
Between iterations run: in a fresh disposable temp dir, clone/copy the repo, follow ONLY the documented setup steps, then run the smoke check (build/test/start)
Exit when: a from-clean run succeeds with zero steps you had to improvise outside the docs

Step 1: Act as a first-time user in a clean temp dir. Follow the docs literally. The first time you must do something the docs don't say, STOP, fix the docs (not your environment) to cover it, then retry from a fresh dir.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

Critical rule: fix the **docs**, never your live environment — the whole point is to surface assumptions a clean machine doesn't satisfy. Run each pass from a disposable, dependency-free dir (see "Fresh/clean state" guardrail).

---

### 10. Recent-Feedback Sweep
**Category:** Review / Hardening  
**Goal:** A correction the user just made is fixed everywhere it occurs, with a regression guard so the class of mistake can't recur  
**Max iterations:** 4  
**Check cmd:** `the project's grep/search for the anti-pattern + the test suite`  
**Exit when:** no remaining instances of the pattern AND a guard exists

```
Start the "Recent-Feedback Sweep" loop.

Goal: turn a single recent correction into a project-wide fix + regression guard
Max iterations: 4
Between iterations run: search the codebase for other instances of the same anti-pattern, then run the test suite
Exit when: zero remaining instances AND a test/lint rule guards against reintroduction

Step 1: State the correction as a falsifiable rule (what was wrong, what is right). Search the whole project for that class of mistake. Fix the highest-impact instance, add a regression guard (test or lint rule) for it, then re-search.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.
```

Scope discipline: fix only the **class** named by the correction — do not expand into unrelated cleanup. A correction without a regression guard is a half-fix; the guard is the exit gate, not the fix itself.

---

### 11. Harness-Improvement Loop
**Category:** Meta / Harness  
**Goal:** A ranked failure cluster from the macro-eval sweep is addressed — a candidate harness change is measured, and a ship/drop recommendation reaches a human reviewer  
**Max iterations:** 3 per hypothesis  
**Check cmd:** Re-run `/kiro:macro-eval-sweep` (or targeted subset) with candidate change active; compare before/after impact scores for the target cluster  
**Exit when:** hypothesis confirmed (target cluster impact drops ≥20%) OR refuted (two passes with no measurable movement)

```
Start the "Harness-Improvement Loop".

Goal: turn a ranked failure cluster from the macro-eval sweep into a reviewed candidate change with a ship/drop recommendation
Max iterations: 3
Between iterations run: re-run /kiro:macro-eval-sweep over recent traces with the candidate change active; diff before/after cluster impact scores
Exit when: target cluster impact drops ≥20% (confirmed) OR two consecutive passes show no measurable change (refuted)

Step 1: Read the latest macro-eval sweep report. Identify the highest-impact cluster not yet investigated. Write one falsifiable hypothesis: "Changing [X] will reduce [cluster] by addressing [failure mode]."

⟳ Human gate 1 — hypothesis selection: Present the hypothesis and estimated effort. Wait for human approval before building a candidate. Do not proceed if the human selects a different cluster or rejects the hypothesis.

Step 2: Build the smallest candidate change that tests the hypothesis — edit one skill, adjust one prompt, fix one tool, or add one hook. Do not bundle multiple independent changes into one candidate.

Step 3: Measure — run the check command. Compare before/after impact scores for the target cluster only. Record the delta.

Self-pace this loop. After each iteration, run the check command, read the output, and only continue if the exit condition is not met. Stop when the exit condition passes or max iterations is reached. Give a short status update each pass.

⟳ Human gate 2 — ship decision: Present evidence (before/after cluster scores, affected users, blast radius of the change). Await human approval or rejection before merging the change into the harness source.
```

**Human gates are mandatory and cannot be skipped.** Hypothesis selection (which cluster deserves the budget) and ship decision (whether the evidence justifies the change) are the two places where human taste has irreplaceable leverage. The loop can build and measure autonomously; it cannot decide which problem matters or whether the evidence is sufficient.

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

### Fuzz invariants, don't "write tests"

"Write tests" is too vague — the agent produces shallow happy-path coverage. Instead instruct it to *"look for risky areas of the code and find invariants that might be violated and fuzz them."* This points the loop at the code most likely to break and at properties (not examples), which is where real defects hide.

### Build bespoke loops, not heavyweight orchestrators

A purpose-built one-off loop only has to be correct for *your* workflow — it can be short and hard-coded. Heavyweight generic orchestrators are often too rigid for the actual task. When you do need structure, the useful shape is a "higher-order workspace": the agent decides a task list → fans each item out to sub-agents → runs a reduce step over the outputs — i.e. a DAG with concurrency limits, not a fixed pipeline.

Also: loops degrade in productivity without a human periodically nudging them. No fully autonomous loop yet replaces the operator — budget for the human check-ins, don't design them out.

### When a loop should become a graph, not just relabeled

A loop is one node in a graph. Promoting a design from loop to multi-node graph only pays off in specific conditions — otherwise it's a relabeled loop with added maintenance cost (state schemas, routing bugs, merge failures). Before adding graph structure, run this gut-check:

1. Does this need genuinely parallel, specialized contexts (not just sequential steps)?
2. Is there real fan-out/fan-in (multiple paths that must merge), not just linear branching?
3. Would the routing logic benefit from being an explicit, auditable diagram rather than implicit in-loop conditionals?
4. Do different paths through the system have DIFFERENT success criteria (not just the same criteria checked at different points)?
5. Does this run on a repeating cadence (weekly review, nightly job), not a one-off?
6. If it breaks, do you need to see the exact step it broke on — rather than re-running the whole loop to find out?

**Score:** 0-1 yes = relabeled loop, keep it a loop. 2-4 = genuine composition, a graph may be justified. 5-6 = likely a real paradigm shift, graph is justified. Default bias: most tasks are still one well-scoped loop — only promote when the gut-check clears 2+. When it does, promote to the `Workflow` tool's `pipeline`/`parallel`/`phase` primitives rather than hand-rolling state machine logic inside the loop.

---

## Relation to Other Skills

- **`iterative-repair-loop`** — use when you need structured JSON handoffs and remaining-delta tracking for a specific artifact. Heavier; better for document/spec repair.
- **`goal-mode`** — use when you want fully autonomous execution with the `/goal` evaluator and delegation to sub-skills. More powerful; requires `/goal` setup.
- **`/loop` command** — use for interval-based recurring tasks (e.g., "check CI every 5 min"). Not task-driven.
- **`loop-patterns`** (this skill) — use for named, check-command-driven dev workflows. Lightweight; works anywhere.
