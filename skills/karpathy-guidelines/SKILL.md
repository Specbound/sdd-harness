---
name: karpathy-guidelines
description: Behavioral checklist for EVERY coding task — writing, editing, reviewing, or refactoring code. Enforces four principles from Andrej Karpathy's observations on LLM coding pitfalls: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution.
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

## How to Know It's Working

- **Fewer unnecessary changes in diffs** — only requested changes appear
- **Fewer rewrites due to overcomplication** — code is simple the first time
- **Clarifying questions come before implementation** — not after mistakes
- **Clean, minimal PRs** — no drive-by refactoring or "improvements"
