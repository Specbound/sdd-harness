---
name: issue-triage-routing
description: Triage a raw issue or idea before implementing or spec'ing — classify by roadmap-fit, scale, ambiguity, and complexity, then route to one-shot, spec, clarify, defer, or program (multi-spec initiative). Use when deciding if work needs a spec.
---

# Issue Triage Routing

A decision gate that runs **before** any implementation or spec work. Given a raw issue,
ticket, or idea, it classifies the work on three axes and routes it to exactly one of four
outcomes — so trivial work is not over-spec'd, off-roadmap work is caught before effort is
spent, and genuinely complex/ambiguous work is spec'd or clarified first.

Ported from Warp's "cloud software factory" triage gate, but source-agnostic and local-first:
the four GitHub labels (`ready-to-implement` / `ready-to-spec` / `needs-info` /
`wait-to-implement`) map to four local harness entrypoints.

## When to Activate

Fire this skill when ALL of these are true:
- There is a **new, not-yet-started** unit of work (an issue, ticket, feature request, bug,
  or a one-line idea) whose route is not already decided.
- You are about to invoke `/kiro:spec-quick`, `/kiro:spec-init`, `/kiro:jira-solve`, start
  a plan, or begin coding — and it is not obvious which of those is correct.
- Someone asks "does this need a spec?", "should I one-shot this?", "is this in scope?", or
  "how should we handle this issue?".

## When NOT to Activate

- The work is already mid-flight (a spec exists, a plan is approved, code is in progress) —
  routing is done; do the work.
- It is a pure conversational question, a doc lookup, or a config tweak with no
  implementation surface.
- The user has already stated the route ("just spec this", "one-shot it") — respect it.

## The Three Axes

Evaluate the issue against each axis. Each has a **falsifiable** threshold — if you cannot
answer it from the issue text, that itself is a signal (usually → `clarify`).

### 1. Roadmap-fit (gate — checked first)
Read `.claude/steering/` (product/vision/roadmap docs) if present.
- **Off-roadmap** = the work contradicts, or is unrelated to, the documented product
  direction, OR pursues a goal the steering docs explicitly defer.
- If steering docs are absent, treat roadmap-fit as **unknown** and note it — do not silently
  assume "fits".

**Off-roadmap → route = DEFER.** Do not spend spec/impl effort. (Overridable by the human.)

### 2. Ambiguity
- **Ambiguous** = there are multiple product OR technical implementations that differ
  *materially* (different UX, different data model, different API surface), and a human
  should choose which is correct. "I don't know exactly what they want" is ambiguity.
- **Not ambiguous** = the desired outcome and the shape of the solution are clear from the
  issue text.

### 3. Complexity
- **Complex** = the implementation would plausibly exceed **a few hundred lines of code**,
  touch multiple modules/folders, or introduce a new subsystem, schema, or external
  integration.
- **Simple** = a bounded change, one folder/module, well under a few hundred LOC.

### 4. Scale
- **Program-scale** = the idea spans multiple decisions that each deserve their own spec —
  you cannot write one coherent `requirements.md` because the destination contains several
  not-yet-separated features or subsystems. "Build the whole X system" or "my most ambitious
  project yet" are signals; a single bounded feature request is not.
- **Feature-scale** = the idea maps to one spec, however complex or ambiguous that spec is.

Check scale *before* ambiguity/complexity — a program-scale idea can sound simple in one
sentence yet still need decomposing before either axis is meaningful.

## Routing Table (apply in order)

| # | Condition | Outcome | Local route |
|---|-----------|---------|-------------|
| 1 | Off-roadmap (axis 1) | **DEFER** | Stop. Note *why* it's off-roadmap; leave for human. (`wait-to-implement`) |
| 2 | On-roadmap **and** Program-scale (axis 4) | **PROGRAM** | `/kiro:idea-refine` — charts or updates `specs/_maps/<name>.md`, decomposes the fog into the first ticket-sized slice, then re-triages that slice against rows 3–5. |
| 3 | On-roadmap **and** Feature-scale **and** Ambiguous (blocks even a spec) | **CLARIFY** | `Skill("questions")` / `/kiro:idea-refine` — resolve the ambiguity, then re-triage. (`needs-info`) |
| 4 | On-roadmap **and** Feature-scale **and** (Complex **or** Ambiguous-but-spec'able) | **SPEC** | `/kiro:spec-quick` (or `spec-init` for full manual control), seeded with the issue. (`ready-to-spec`) |
| 5 | On-roadmap **and** Feature-scale **and** Simple **and** Not ambiguous | **ONE-SHOT** | Plan + implement directly (or `/kiro:jira-solve` type-routing for tickets). (`ready-to-implement`) |

**Precedence:** roadmap-fit (defer) beats program beats clarify beats spec beats one-shot.
Evaluate top-down; first matching row wins.

**Distinction between rows 3 and 4:** both involve ambiguity. Row 3 (**clarify**) is for
ambiguity so fundamental you can't even write a coherent spec — you'd be guessing at the goal.
Row 4 (**spec**) is for ambiguity where the goal is clear but the *implementation choice* needs
human sign-off — exactly what a spec's requirements/design review gate exists to resolve.

**Distinction between row 2 and everything below it:** program-scale is orthogonal to
ambiguity/complexity, not a bigger version of them. A program-scale idea gets decomposed
first; only the resulting slice gets checked against ambiguity/complexity.

## Output

State the verdict explicitly, then act:

```
Triage: <issue one-liner>
- Roadmap-fit: <fits | off-roadmap | unknown (no steering docs)> — <reason>
- Scale:       <feature | program> — <reason>
- Ambiguity:   <clear | ambiguous> — <reason>
- Complexity:  <simple | complex> — <reason>
→ Route: <DEFER | PROGRAM | CLARIFY | SPEC | ONE-SHOT>  → <local command / next action>
```

Then take the routed action (or, if the human is in the loop, propose it and wait).

## Anti-patterns

- **Skipping the roadmap gate.** Always check roadmap-fit first — it's the cheapest way to
  avoid wasted effort. Don't jump to complexity.
- **Spec'ing everything.** `spec-quick` is not the default. Simple + clear + on-roadmap =
  one-shot. Over-spec'ing trivial work is the failure this gate exists to prevent.
- **Treating "unknown roadmap" as "fits".** If there are no steering docs, say so — don't
  launder an assumption into a route.
- **Re-triaging in-flight work.** Once routed and started, don't re-litigate. This gate is
  upstream only.
- **Treating "big" as "complex."** Program-scale isn't a bigger point on the complexity axis
  — it's "this is more than one spec." Route those through `/kiro:idea-refine`'s map-charting
  (row 2), not straight into `spec-quick`.
