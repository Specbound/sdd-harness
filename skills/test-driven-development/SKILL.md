---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code. Covers the red-green-refactor cycle, source-grounding tests in real code before writing them, coverage/refactoring thresholds, and the common rationalizations for skipping TDD.
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

**Always:** new features, bug fixes, refactoring, behavior changes.
**Exceptions (ask your human partner first):** throwaway prototypes, generated code,
configuration files.

Thinking "skip TDD just this once"? Stop. That's rationalization.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote code before the test? Delete it. Start over. Don't keep it "as reference," don't
"adapt" it while writing tests, don't even look at it. Delete means delete — implement
fresh from tests.

## Red-Green-Refactor

### 0. Source-grounding (before writing any test)

Read the actual code or spec before deciding what to test — don't write tests against
assumed behavior:

| Scenario | Read this first |
|---|---|
| Bug fix | `git diff HEAD` (or the bug report) — the exact broken path |
| New feature | Spec + existing interfaces — real signatures, real data shapes |
| Refactor | Current implementation — what behavior must be preserved |

Only write tests for paths that exist in source or are explicitly specified. Flag an
assumed path with `# TODO: verify path exists` instead of silently writing a test that
fails for the wrong reason. If you can't ground a test in source or spec, stop and get
the spec before proceeding.

### RED — Write Failing Test

One minimal test, one behavior, clear name, real code (mock only if unavoidable).

```typescript
// Good: tests real behavior
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => { attempts++; if (attempts < 3) throw new Error('fail'); return 'success'; };
  const result = await retryOperation(operation);
  expect(result).toBe('success');
  expect(attempts).toBe(3);
});

// Bad: tests the mock, not the code
test('retry works', async () => {
  const mock = jest.fn().mockRejectedValueOnce(new Error()).mockRejectedValueOnce(new Error()).mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(3);
});
```

**Verify RED (mandatory, never skip):** run the test. Confirm it fails (not errors), the
failure message is the expected one, and it fails because the feature is missing — not
because of a typo. Passes already? You're testing existing behavior — fix the test.
Errors instead of fails? Fix the error and re-run until it fails correctly.

### GREEN — Minimal Code

Simplest code that passes. Don't add features, refactor unrelated code, or "improve"
beyond the test — that's YAGNI violation disguised as diligence.

**Verify GREEN (mandatory):** run the test. Confirm it passes, other tests still pass,
and output is pristine (no errors/warnings). Fails? Fix the code, not the test. Other
tests broke? Fix now, don't defer.

### REFACTOR — Clean Up

After green only: remove duplication, improve names, extract helpers. Keep tests green.
Don't add behavior here.

### Repeat

Next failing test for the next behavior.

## AAA Pattern

Every test: **Arrange** (set up data) → **Act** (execute code under test) → **Assert**
(verify outcome).

## Test Prioritization & Edge Cases

| Priority | Test type |
|---|---|
| 1 | Happy path |
| 2 | Error cases |
| 3 | Edge cases |
| 4 | Performance |

Edge case categories to run through: null/empty (undefined, null, empty string/array/
object), boundaries (min/max, single element, capacity limits), special cases (Unicode,
whitespace, special chars), state (invalid transitions, concurrent modification), errors
(network failure, timeout, permissions).

## Good Tests

| Quality | Good | Bad |
|---|---|---|
| Minimal | One thing — "and" in the name? Split it. | `test('validates email and domain and whitespace')` |
| Clear | Name describes the behavior | `test('test1')` |
| Shows intent | Demonstrates the desired API | Obscures what the code should do |

## GREEN Phase in Practice

Review the failing tests, implement the smallest change that advances the next one, run
tests after each change, and record any shortcuts taken as debt for the refactor phase.
Avoid bypassing a test to make it pass (e.g. hardcoding the expected value) and keep
changes scoped to the failing behavior only.

## Refactor Phase: Triggers & Technique

**Refactor when:** cyclomatic complexity > 10, a method exceeds ~20 lines, a class exceeds
~200 lines, or a duplicate block exceeds ~3 lines.

**Common moves:** extract method/variable, inline unnecessary indirection, rename for
clarity, move method/field to the right class, replace magic numbers with constants,
replace conditionals with polymorphism where it removes a parallel `if`/`switch` family.
Apply SOLID where it clarifies responsibility — don't force a pattern that doesn't earn
its complexity.

**Safety:** run the full suite after each small, atomic change; commit after each
successful step; if a change breaks tests, revert immediately rather than layering a fix
on top. Keep refactoring commits separate from behavior-changing commits.

## Coverage Targets

Minimum line coverage 80%, branch coverage 75%, critical-path coverage 100%. Treat these
as a floor for risk-weighted code, not a target to game with trivial assertions.

## Why Order Matters

- **"I'll write tests after to verify it works"** — tests written after code pass
  immediately, which proves nothing: might test the wrong thing, might test the
  implementation instead of behavior, might miss edge cases you forgot. Test-first forces
  you to see the test fail, proving it actually tests something.
- **"I already manually tested the edge cases"** — manual testing is ad hoc: no record of
  what you tested, can't re-run on every change, easy to forget cases under pressure.
- **"Deleting X hours of work is wasteful"** — sunk cost fallacy. The time is already
  spent; the choice now is delete-and-rewrite-with-TDD (high confidence) vs.
  keep-and-add-tests-after (low confidence, likely bugs). Working code you can't trust
  *is* the technical debt.
- **"Tests after achieve the same goals"** — no: tests-after answer "what does this do?",
  tests-first answer "what should this do?" Tests-after are biased by the implementation
  you already built; they verify remembered edge cases, not discovered ones.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "Too simple to test" | Simple code breaks too. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Already manually tested" | Ad hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Unverified code is the debt. |
| "Keep as reference, write tests first" | You'll adapt it — that's testing after. Delete means delete. |
| "Need to explore first" | Fine — throw away the exploration, start fresh with TDD. |
| "Test is hard = design unclear" | Listen to the test. Hard to test = hard to use. |
| "TDD will slow me down" | TDD is faster than debugging later. |
| "Existing code has no tests" | You're touching it now — add tests for what you touch. |

## Red Flags — STOP and Start Over

Code before test · test written after implementation · test passes immediately · can't
explain why a test failed · tests added "later" · "I already manually tested it" ·
"tests after achieve the same purpose" · "keep as reference"/"adapt existing code" ·
"already spent X hours, deleting is wasteful" · "this is different because...".

**All of these mean: delete the code, start over with TDD.**

## Example: Bug Fix

```typescript
// RED
test('rejects empty email', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
// $ npm test → FAIL: expected 'Email required', got undefined

// GREEN
function submitForm(data: FormData) {
  if (!data.email?.trim()) return { error: 'Email required' };
  // ...
}
// $ npm test → PASS

// REFACTOR: extract validation for multiple fields if needed.
```

## Verification Checklist

Before marking work complete: every new function/method has a test · you watched each
test fail before implementing · each failed for the expected reason (feature missing, not
a typo) · minimal code written to pass each test · all tests pass · output is pristine ·
tests use real code (mocks only if unavoidable) · edge cases and errors are covered.
Can't check all of these? You skipped TDD — start over.

## When Stuck

| Problem | Solution |
|---|---|
| Don't know how to test | Write the wished-for API. Write the assertion first. Ask. |
| Test too complicated | Design is too complicated. Simplify the interface. |
| Must mock everything | Code is too coupled. Use dependency injection. |
| Test setup is huge | Extract helpers; still complex → simplify the design. |

## Debugging Integration

Bug found? Write a failing test reproducing it, then follow the TDD cycle — the test
proves the fix and prevents regression. Never fix a bug without a test. See
`systematic-debugging` for root-causing the bug itself before writing that test.

## Testing Anti-Patterns

When adding mocks or test utilities, read `testing-anti-patterns.md` in this directory to
avoid: testing mock behavior instead of real behavior, adding test-only methods to
production classes, mocking without understanding the dependency's side effects,
incomplete mocks that silently diverge from the real API shape.

## Final Rule

```
Production code → a test exists and failed first
Otherwise → not TDD
```

No exceptions without your human partner's permission.
