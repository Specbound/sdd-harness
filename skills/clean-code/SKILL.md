---
name: clean-code
description: "Applies principles from Robert C. Martin's 'Clean Code'. Use this skill when writing, reviewing, or refactoring code to ensure high quality, readability, and maintainability. Covers naming, functio..."
user-invocable: true
risk: safe
source: "ClawForge (https://github.com/jackjin1997/ClawForge)"
---

# Clean Code Skill

This skill embodies the principles of "Clean Code" by Robert C. Martin (Uncle Bob). Use it to transform "code that works" into "code that is clean."

## 🧠 Core Philosophy
> "Code is clean if it can be read, and enhanced by a developer other than its original author." — Grady Booch

## When to Use
Use this skill when:
- **Writing new code**: To ensure high quality from the start.
- **Reviewing Pull Requests**: To provide constructive, principle-based feedback.
- **Refactoring legacy code**: To identify and remove code smells.
- **Improving team standards**: To align on industry-standard best practices.

## 1. Meaningful Names
- **Use Intention-Revealing Names**: `elapsedTimeInDays` instead of `d`.
- **Avoid Disinformation**: Don't use `accountList` if it's actually a `Map`.
- **Make Meaningful Distinctions**: Avoid `ProductData` vs `ProductInfo`.
- **Use Pronounceable/Searchable Names**: Avoid `genymdhms`.
- **Class Names**: Use nouns (`Customer`, `WikiPage`). Avoid `Manager`, `Data`.
- **Method Names**: Use verbs (`postPayment`, `deletePage`).

## 2. Functions
- **Small!**: Functions should be shorter than you think.
- **Do One Thing**: A function should do only one thing, and do it well.
- **One Level of Abstraction**: Don't mix high-level business logic with low-level details (like regex).
- **Descriptive Names**: `isPasswordValid` is better than `check`.
- **Arguments**: 0 is ideal, 1-2 is okay, 3+ requires a very strong justification.
- **No Side Effects**: Functions shouldn't secretly change global state.

## 3. Comments
- **Don't Comment Bad Code—Rewrite It**: Most comments are a sign of failure to express ourselves in code.
- **Explain Yourself in Code**: 
  ```python
  # Check if employee is eligible for full benefits
  if employee.flags & HOURLY and employee.age > 65:
  ```
  vs
  ```python
  if employee.isEligibleForFullBenefits():
  ```
- **Good Comments**: Legal, Informative (regex intent), Clarification (external libraries), TODOs.
- **Bad Comments**: Mumbling, Redundant, Misleading, Mandated, Noise, Position Markers.

## 4. Formatting
- **The Newspaper Metaphor**: High-level concepts at the top, details at the bottom.
- **Vertical Density**: Related lines should be close to each other.
- **Distance**: Variables should be declared near their usage.
- **Indentation**: Essential for structural readability.

## 5. Objects and Data Structures
- **Data Abstraction**: Hide the implementation behind interfaces.
- **The Law of Demeter**: A module should not know about the innards of the objects it manipulates. Avoid `a.getB().getC().doSomething()`.
- **Data Transfer Objects (DTO)**: Classes with public variables and no functions.

## 6. Error Handling
- **Use Exceptions instead of Return Codes**: Keeps logic clean.
- **Write Try-Catch-Finally First**: Defines the scope of the operation.
- **Don't Return Null**: It forces the caller to check for null every time.
- **Don't Pass Null**: Leads to `NullPointerException`.

## 7. Unit Tests
- **The Three Laws of TDD**:
  1. Don't write production code until you have a failing unit test.
  2. Don't write more of a unit test than is sufficient to fail.
  3. Don't write more production code than is sufficient to pass the failing test.
- **F.I.R.S.T. Principles**: Fast, Independent, Repeatable, Self-Validating, Timely.

## 8. Classes
- **Small!**: Classes should have a single responsibility (SRP).
- **The Stepdown Rule**: We want the code to read like a top-down narrative.

## 9. Smells and Heuristics
- **Rigidity**: Hard to change.
- **Fragility**: Breaks in many places.
- **Immobility**: Hard to reuse.
- **Viscosity**: Hard to do the right thing.
- **Needless Complexity/Repetition**.

## 10. Measuring Sloppiness (non-LLM-judge)
- **Don't score code quality 1-10 with an LLM judge**: LLM-as-judge scoring against a
  vague rubric is close to random — it correlates weakly with real quality and gives
  false confidence. Prefer deterministic, mechanical proxies over asking a model to
  rate its own (or another model's) output.
- **Verbosity & Erosion metrics**: `scripts/quality/sloppiness-score.sh` computes two
  dependency-free proxies per file — Verbosity (exact-line-dedup ratio, a clone-detection
  proxy) and Erosion (file-level branch-keyword density, a cyclomatic-mass proxy).
  Published baselines (earendil.com "Measuring code sloppiness"): human ≈0.15/0.31,
  AI-agent ≈0.33/0.68 (verbosity/erosion). Crossing the AI-agent baseline on either axis
  flags `high-slop`.
- **Automated via `sloppiness-warn-hook.sh`**: fires `PostToolUse(Write|Edit|MultiEdit)`,
  scores only the file just written, warns (never blocks) when it verdicts `high-slop`.
  Advisory only — soft thresholds on a bash/awk proxy, not a rigorous AST-based tool;
  treat a warning as a nudge to look for duplicated blocks or flatten nested branches,
  not as a hard failure.

## 11. Comments as Persistent Agent Memory
- **This supersedes Section 3's "don't comment bad code, rewrite it" for one specific case**: an AI agent's session context resets, but comments in the file don't. A comment explaining *why* a non-obvious decision was made (a workaround, a constraint from another system, a rejected alternative and why) is memory an agent in a future session gets for free — it never has to rediscover the same reasoning. This is about durable rationale, not narrating what the code does. (kiro.dev — Frontier Engineering)
- Keep Section 3's rule for everything else: a comment that restates *what* the code does, or exists because the code is unclear, is still a smell — rewrite the code instead.

## 🛠️ Implementation Checklist
- [ ] Is this function smaller than 20 lines?
- [ ] Does this function do exactly one thing?
- [ ] Are all names searchable and intention-revealing?
- [ ] Have I avoided comments by making the code clearer?
- [ ] Am I passing too many arguments?
- [ ] Is there a failing test for this change?
