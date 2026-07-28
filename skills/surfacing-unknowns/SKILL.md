---
name: surfacing-unknowns
description: Run before a spec, design, or large change where your mental model may diverge from the real codebase — surfaces blind spots and tacit taste before building. Skip well-specified mechanical tasks.
---

# Surfacing Unknowns

A pre-execution discovery routine, run **before** you commit to a spec, a design, or a large
change — not after. Its job is to close the gap between what the operator *thinks* is true and
what is *actually* true, before that gap gets baked into a spec or thousands of lines of code.

Ported from Thariq's "Field Guide to Fable: Finding Your Unknowns."

## The Map Is Not the Territory

- **The map** = your prompts, skills, context files, and mental model of the problem.
- **The territory** = the actual codebase, its real constraints, and what the operator
  actually wants (often only knowable when they see it).
- **The gap** = unknowns. Every hour spent building on a wrong map is an hour of rework.

The routine's purpose is to make the gap *visible and small* before execution starts.

### Four Quadrants of Knowledge

Sort what you're dealing with. Each quadrant has a different technique that surfaces it:

| | You know it | You don't know it |
|---|---|---|
| **You know you have it** | **Known knowns** — write them down; they're your spec baseline. | **Known unknowns** — open questions. Use the **architecture interview**. |
| **You don't know you have it** | **Unknown knowns** — tacit taste you can't articulate but recognize instantly. Use a **design prototype**. | **Unknown unknowns** — blind spots. Use a **blind-spot pass**. |

The two hard quadrants are the bottom row. Most of this skill targets them.

## When to Activate

Fire this skill when ALL are true:
- The work is **not yet started** and is **non-trivial** — a spec, a design, a new subsystem,
  a refactor across modules, or any change where getting the shape wrong is expensive.
- There is a plausible **gap between the operator's mental model and the actual codebase or
  intent** — the problem is under-specified, the domain is unfamiliar, or "what good looks
  like" hasn't been pinned down.

Common entry points: right before `/kiro:spec-init`, `/kiro:spec-design`, a big plan, or any
change you'd regret shipping in the wrong shape.

## When NOT to Use

- **Well-specified mechanical tasks** — the outcome and its shape are already clear (rename a
  symbol, apply a documented migration, wire an obvious config).
- **Trivial edits** — typo fixes, one-line changes, bounded work under a few dozen lines.
- **Mid-flight work** — the spec is approved and the map is already validated; discovery is done.
- When the operator has already surfaced the unknowns themselves and just wants execution.

If you're here for one of these, stop and do the work.

## Workflow

Run the phases that match your gaps (use the quadrant table to pick). You do not need all six;
pick by which quadrant is thin. Each is a concrete move you make *with* the operator.

### 1. Blind-spot pass — targets unknown unknowns
Point an analysis explicitly at finding what the operator missed. The move:
> "Do a blind spot pass to help me figure out my relevant unknown unknowns."

Aim it at concrete surfaces, not the whole world: a **git diff**, a design doc, a spec draft,
a discussion thread. Report gaps, contradictions, and unstated assumptions — not a summary.
The output is a list of "things you probably haven't considered," ranked by how much they'd
change the plan.

### 2. Design-prototype for tacit taste — targets unknown knowns
The operator often can't *describe* what they want but recognizes it on sight. Reaction beats
description. The move:
> "Make me an HTML page with four widely different design decisions so I can react."

Produce genuinely divergent options (not four shades of the same idea). Let the operator react
("that one, but not the color") — the reaction reveals tacit preferences that were never in the
prompt. Applies beyond UI: sketch 3-4 divergent API shapes, data models, or flow diagrams and
let them pick.

### 3. Architecture interview — targets known unknowns
Turn open questions into decisions before they calcify. The move:
> "Interview me one question at a time; prioritize questions where my answer would change the
> architecture."

One question at a time (batches get shallow answers). Rank questions by architectural leverage:
ask first the ones whose answer forks the design. Stop when remaining questions no longer move
the structure.

### 4. Reference-as-map — cheaper than a full spec
Instead of writing an exhaustive spec, point at existing code or a design you like and say what
to look for. The move:
> "Build it like `path/to/thing`, and specifically copy how it handles X and Y."

A good reference carries far more context than prose and works cross-language (the *pattern*
transfers even when the syntax doesn't). Name what to imitate and what to ignore.

### 5. Implementation-deviation logging — catches divergence during execution
Where you had to decide something the operator didn't specify is exactly where the mental model
diverged from reality. The move: have the agent **log every decision it made that wasn't in the
spec** as it works — assumptions taken, defaults chosen, ambiguities resolved. After the pass,
review the log: each entry is a place the map was incomplete. **Then update the docs** so the
next run's map is closer to the territory.

### 6. Pre-merge quizzing — comprehension over rubber-stamp
Before approval, the agent **quizzes the operator on the change** rather than the operator
skimming a diff. The move: ask 3-5 pointed questions about what the change does, what it
touches, and what could break. If the operator can't answer, the review is rubber-stamping, not
understanding — surface the gap before merge, not after.

## Output

A short **unknowns brief** the operator can act on:
- **Resolved** — questions the interview/prototype/reference settled (now known knowns).
- **Open** — remaining known unknowns, each with a proposed way to close it.
- **Blind spots found** — what the blind-spot pass surfaced, ranked by impact.
- **Doc updates** — what to write down (from deviation logging) so the next map is better.

Then hand off to the spec/design/implementation step with a smaller, validated map.

## What This Skill Does NOT Do

- It does **not** write the spec, design, or code — it de-risks them first, then hands off.
- It does **not** replace `/kiro:spec-*` or planning — it runs *before* them.
- It does **not** apply to well-specified or trivial work (see "When NOT to Use").
- It is **not** a substitute for the human review gate — pre-merge quizzing informs that gate,
  it doesn't bypass it.
