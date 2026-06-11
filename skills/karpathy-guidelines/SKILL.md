---
name: karpathy-guidelines
description: Behavioral checklist for EVERY coding task — writing, editing, reviewing, or refactoring code. Principles from Karpathy (coding discipline), cpojer (dependency ownership, option value), and Christina Lin (AI-legible code: blast radius, Rule of Three, vertical slices, fail-fast, context rot).
license: MIT
source: https://github.com/multica-ai/andrej-karpathy-skills
---

# Karpathy Guidelines

Behavioral checklist to reduce common LLM coding mistakes, derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks (obvious one-liners, typo fixes), use judgment — not every change needs full rigor.

**Related skills:** Use `questions` to ask clarifying questions, `refactoring-safely` when restructuring, `test-driven-development` for goal-driven loops.

---

## Before You Write a Single Line

Run through this checklist mentally:

- [ ] **Assumptions stated?** — If uncertain about scope or intent, surface it. Don't pick silently.
- [ ] **Tradeoffs presented?** — If multiple approaches exist, name them before choosing.
- [ ] **Clarification needed?** — If something is unclear, stop. Name what's confusing. Ask.
- [ ] **Simplest path identified?** — Could this be done with less code? If yes, do less.
- [ ] **Scope locked?** — Know exactly which lines you'll touch and why.
- [ ] **Success criteria defined?** — How will you know it's done? Tests? Expected output?
- [ ] **Adding a dependency?** — Run the ownership check (section 6).
- [ ] **Architectural decision?** — Run the option value check (section 7).
- [ ] **Blast radius estimated?** — How many folders/modules will this change touch? If >1, can it be scoped down?
- [ ] **Rule of Three applied?** — Extracting shared code? Do 3+ real call sites exist yet?

---

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

**Red flag:** You started implementing before you fully understood the request.

---

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you wrote 200 lines and it could be 50, rewrite it.

**The test:** Would a senior engineer say this is overcomplicated? If yes, simplify.

---

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

**The test:** Every changed line should trace directly to the user's request.

---

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

## 5. Review Tiering

**AI owns the mechanical; humans own the judgment.**

When reviewing or requesting review, route by category:

| AI reviews | Human reviews |
|---|---|
| Style, formatting, linting | Domain logic and business rules |
| PR description completeness | Legal / compliance / privacy |
| Bug patterns, test coverage gaps | Security-sensitive code (auth, crypto, secrets) |
| Naming and structural consistency | Product taste (UX copy, feature feel) |

**Implication for your PRs:** Don't wait for a human to catch lint errors or missing tests — fix those before requesting review. Reserve human attention for the right-column categories.

---

## 6. Before Adding a Dependency

**Every dependency is code you'll own forever.**

When suggesting or adding a third-party library:
- What constraints, architecture decisions, or upgrade paths does this impose?
- Could this be built in under a day with agent help? If yes, owning it may be cheaper long-term.
- Does the dependency solve the problem in a way that forecloses your own future design choices?

**Not a rule against dependencies** — a prompt to make the cost explicit before accepting it.

**Red flag:** You added a library without considering what it locks in architecturally.

---

## 7. Option Value Check

**Good design unlocks future choices. Bad design forecloses them.**

Before finalizing any architectural decision:
- Does this make the next change easier or harder?
- Does it create a corner you can't easily escape from?
- With agents, large-scale rewrites are cheap — but only if the architecture permits them.

**Flip side:** Don't over-engineer for hypothetical futures (→ Simplicity First). The check is whether this *closes off* obvious future paths, not whether it opens every conceivable one.

**Red flag:** You locked in an architectural choice because it was convenient today, without considering what it prevents tomorrow.

---

## 8. AI-Legible Code

**Write code that AI agents can reason about locally.**

AI has a cognitive load — it's called the context window — and coherence degrades past ~300,000–400,000 tokens (context rot). Write code so that reasoning about a change requires reading as little context as possible.

### Blast Radius First
Every change should break a small, knowable region. Ask before writing: if this logic is wrong, what is the maximum surface area that could fail?
- Prefer flat, explicit code over clever indirection
- A change touching 1 folder beats a change touching 3
- "Clever" and "safely modifiable by an agent" are frequent opposites

### Rule of Three for Abstractions
Do not extract a shared function, base class, or generic until the same pattern appears in at least **3 distinct, real call sites**.
- Two similar implementations = coincidence, not a pattern
- If the urge to abstract arrives early, leave a comment noting the duplication and move on
- Prefer explicit duplication over an abstraction that hides intent

### Vertical Slices
Organize by feature, not by layer.
- One feature = one folder: routes, logic, data access, types, tests — all colocated
- Features do not import from other features
- No `shared/`, `utils/`, `common/`, or `helpers/` folders — these become blast-radius epicenters

### Fail Fast, Fail Loud
- Validate inputs at every public function boundary
- Raise specific, named exceptions on bad data — no silent fallbacks, no default values masking missing data
- No bare `except` / `catch` blocks — re-raise or convert to domain-specific error context

### Reviewer Model Mismatch
The model that helped write the code is the worst possible reviewer of it — it produces confidence, not error-catching. Use a separate session or a different model for review.

**Red flag:** You extracted a shared abstraction because it appeared in two places. Wait for three.

---

## How to Know It's Working

- **Fewer unnecessary changes in diffs** — only requested changes appear
- **Fewer rewrites due to overcomplication** — code is simple the first time
- **Clarifying questions come before implementation** — not after mistakes
- **Clean, minimal PRs** — no drive-by refactoring or "improvements"
- **Human reviewers focus on domain/security/taste** — not style nits
