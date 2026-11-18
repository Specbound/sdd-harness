---
name: code-reviewer
description: Use when reviewing a pull request or diff, requesting review of your own work before merging, or responding to review feedback. Covers reviewer checklists and severity triage, how to dispatch a review, and how to evaluate and act on feedback (including pushing back) without performative agreement.
---

# Code Reviewer

**Core principle:** Review early, review often. Technical correctness over social comfort —
for both giving and receiving feedback.

## When to Use

Reviewing PRs/diffs, requesting review before merge or after a task/feature, responding to
review feedback, establishing review standards. Not for pure design discussion with no code,
and not as a substitute for implementing the fixes yourself.

## Giving a Review

If scope or focus is ambiguous, ask one question; otherwise read the code first. Calibrate
depth to size: PRs >1000 lines get a superficial pass (flag for splitting); <200 lines get
a deep review.

Deliver findings in three buckets, and state which automated tool you'd run for each:

| Severity | Meaning | Examples |
|---|---|---|
| **Blocking / Critical** | Must fix before merge | Security vuln, data loss, auth bypass, broken functionality |
| **Important / Warning** | Fix before next release | Performance bottleneck, missing test coverage, architectural anti-pattern |
| **Minor / Suggestion** | Track, don't block | Style, naming, nice-to-have refactor |

### Checklist by category

**Functionality** — solves the stated problem; edge cases and errors handled; no off-by-one
or state-management bugs; input validated.

**Security** — parameterized queries (no string-concatenated SQL); output escaped (XSS);
CSRF protection present; no hardcoded secrets (env vars instead); auth/authz checks present;
dependencies free of known CVEs. Map findings to OWASP Top 10 when relevant: broken access
control, cryptographic failures, injection, insecure design, security misconfiguration,
vulnerable components, auth failures, data-integrity failures (unsigned JWTs), logging
failures, SSRF.

**Performance** — no N+1 queries (eager-load/batch instead); indexes used; no unbounded
collections or missing pagination; caching used appropriately; no obvious memory leaks.

**Code quality** — readable, descriptive names, functions small and focused, no duplication,
magic numbers replaced with constants, follows project conventions.

**Tests** — new code has tests; edge cases and errors covered; tests are meaningful (not
asserting on mocks); all tests pass; coverage adequate for the risk.

**Docs & git** — comments explain *why* not *what*; API docs and README updated for breaking
changes; commit messages clear; no unnecessary files committed.

### Example: catch this class of issue

```javascript
// Bad — SQL injection
const query = `SELECT * FROM users WHERE email = '${email}'`;
// Good — parameterized
const query = 'SELECT * FROM users WHERE email = $1';
db.query(query, [email]);
```

```javascript
// Bad — function doing too much (validate + calc + pay + email + inventory)
// Good — separated concerns, one responsibility per function
function processOrder(order) {
  validateOrder(order);
  const total = calculateOrderTotal(order);
  processPayment(total);
  sendOrderConfirmation(order.email);
  updateInventory(order.items);
}
```

### Output format

1. High-level summary of findings
2. Issues grouped by severity, each with file/line, rationale, and a concrete fix
3. Questions for the author where intent is unclear
4. Test/coverage notes

### Comment templates

```markdown
**Issue:** [problem] — **Current:** ```code``` — **Suggested:** ```code``` — **Why:** [reason]
**Question:** [question] — **Context:** [why asking] — **Suggestion:** [if any]
```

Be constructive: don't nitpick minor style, don't rubber-stamp, don't review tired, explain
*why* an issue matters, and call out what's good — not just what's wrong.

## Requesting a Review

**Mandatory:** after each task in subagent-driven development, after completing a major
feature, before merge to main.
**Valuable but optional:** when stuck (fresh perspective), before a refactor (baseline
check), after fixing a complex bug.

1. Get the diff bounds: `BASE_SHA=$(git rev-parse HEAD~1)` (or `origin/main`), `HEAD_SHA=$(git rev-parse HEAD)`.
2. Dispatch the reviewer with: what was implemented, the plan/requirements it should satisfy,
   `BASE_SHA`/`HEAD_SHA`, and a brief description.
3. Act on feedback: fix Critical/blocking issues immediately, fix Important issues before
   proceeding, note Minor issues for later, push back if the reviewer is wrong (with
   reasoning, not deference).

**Never:** skip review because "it's simple," ignore Critical issues, proceed with unfixed
Important issues, argue with valid technical feedback instead of fixing it.

## Receiving Review Feedback

Code review requires technical evaluation, not emotional performance.

```
1. READ: complete feedback without reacting
2. UNDERSTAND: restate the requirement in your own words (or ask)
3. VERIFY: check against codebase reality
4. EVALUATE: technically sound for THIS codebase?
5. RESPOND: technical acknowledgment or reasoned pushback
6. IMPLEMENT: one item at a time, test each
```

**Forbidden:** "You're absolutely right!", "Great point!", "Thanks for catching that!", any
gratitude expression, or implementing before verifying. Actions speak — just fix it, or push
back with reasoning. If you catch yourself writing "Thanks," delete it and state the fix.

**Unclear feedback:** if any item is unclear, stop — don't implement anything yet. Items may
be related; partial understanding produces a wrong implementation. Ask for clarification on
the unclear items specifically, and say which items you *do* understand so work isn't
blocked entirely.

### Source-specific handling

**From your human partner:** trusted — implement after understanding; still ask if scope is
unclear; no performative agreement, skip straight to action or a short technical ack.

**From external reviewers**, before implementing, check: technically correct for *this*
codebase? Does it break existing functionality? Is there a reason for the current
implementation? Does it work on all target platforms/versions? Does the reviewer have full
context? If a suggestion seems wrong, push back with technical reasoning. If you can't verify
it, say so explicitly rather than guessing. If it conflicts with a prior architectural
decision, stop and raise that conflict before implementing either side.

### Intent-provenance check

Before accepting or pushing back on a suggestion that touches existing code, classify why
that code is the way it is:

1. **Requirement** — traces to an approved spec or explicit user ask
2. **Decision** — traces to a documented tradeoff (commit message, PR discussion, ADR)
3. **Convention** — traces to a steering doc or house style
4. **Unexplained guess** — no traceable reason found

If you can't place it in 1–3 from memory, dig it up (git blame → commit → PR/issue → project
memory) before responding — "I don't know why this is here" and "I checked, and here's why"
lead to very different conversations. Only bucket 4 is freely changeable; 1–3 mean the
reviewer's suggestion needs to address the original requirement/decision/convention, not just
how the code looks today.

### YAGNI check

If a reviewer suggests "implementing properly" / adding a full feature, check actual usage
first. Unused → propose removing it instead ("this isn't called anywhere — remove it?").
Used → implement it properly.

### Implementation order

Clarify everything unclear first. Then: blocking issues (breaks, security) → simple fixes
(typos, imports) → complex fixes (refactoring, logic). Test each fix individually; verify no
regressions before moving to the next.

### When and how to push back

Push back when: the suggestion breaks existing functionality, the reviewer lacks context,
it violates YAGNI, it's technically incorrect for this stack, there's a legacy/compat reason,
or it conflicts with a prior architectural decision. Use technical reasoning, ask specific
questions, reference working tests/code — not defensiveness. Involve a human if it's
architectural.

If you pushed back and were wrong: "You were right — I checked X and it does Y. Fixing." No
long apology, no over-explaining — state the correction and move on.

### Common mistakes

| Mistake | Fix |
|---|---|
| Performative agreement | State the requirement, or just act |
| Blind implementation | Verify against the codebase first |
| Batch without testing | One item at a time, test each |
| Assuming reviewer is right | Check whether it actually breaks something |
| Avoiding pushback | Technical correctness beats comfort |
| Partial implementation | Clarify all unclear items before starting |
| Can't verify, proceed anyway | State the limitation, ask for direction |

GitHub inline comments: reply in the comment thread (not as a new top-level PR comment) so
the conversation stays attached to the line.

**The bottom line:** external feedback is suggestions to evaluate, not orders to follow.
Verify. Question. Then implement. No performative agreement — technical rigor always.
