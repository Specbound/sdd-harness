---
name: refactoring-safely
description: Safely restructure code without changing behavior — small change/test/commit cycles, legacy modernization via strangler fig, and technical-debt triage. Use when cleaning up code, extracting duplication, migrating off legacy frameworks, or prioritizing tech debt.
---

Refactoring changes structure, not behavior. If tests must change their assertions, you're rewriting, not refactoring.

## When to use
- Improving structure without changing functionality; extracting duplication; renaming for clarity
- Reorganizing modules; simplifying complex code while preserving behavior
- Migrating off legacy frameworks/languages incrementally; reducing technical debt

**Don't use for:** changing functionality (feature work), fixing bugs (behavior change by definition), adding features while restructuring, or code with no tests (write characterization tests first).

## Core cycle: change → test → commit

| Step | Action | Verify |
|---|---|---|
| 1 | Run full test suite before starting | ALL pass (if not, fix first — you can't detect breakage otherwise) |
| 2 | Make ONE small change | Compiles |
| 3 | Run tests immediately | ALL still pass |
| 4 | Commit with descriptive message | History stays reviewable |
| 5 | Repeat 2–4 until complete | Each step independently safe |
| 6 | Final: full suite + linter, review diff | No new warnings, no behavior change |

**Small** = one extracted method, one rename, one moved function, one inlined constant. **Not small** = extracting multiple methods at once, rename+move+restructure together, "while I'm here" improvements (scope creep).

**If tests fail:** STOP → `git restore` the change → understand why → make a smaller change → retry. Never proceed with failing tests. **3+ failures on the same change → question the approach**: you may need to write tests first, or this is a rewrite in disguise.

### Common excuses that mean "stop and return to the cycle"
"I'll test at the end" · "just fixing this bug while I'm here" (bug fixes = behavior change = not refactoring) · "easier to do it all at once" · "tests will fail temporarily but I'll fix them" (tests must stay green throughout).

## Refactor vs. rewrite vs. strangler fig

| Situation | Approach |
|---|---|
| Tests exist, changes are incremental, logic stays the same | **Refactor** — small safe steps |
| No tests, fundamental architecture change, requirements shifted, 3+ failed refactor attempts | **Rewrite** — write tests first (documenting current behavior), then build the replacement |
| System too large/critical to refactor in place, can't tolerate downtime | **Strangler fig** — see below |

### Strangler fig pattern (legacy modernization / framework migration)
1. **Transform** — build the modernized component alongside the legacy one, tested in isolation.
2. **Coexist** — add a routing/façade layer; send a slice of traffic (by route, header, or user segment) to the new component; monitor both, compare results.
3. **Eliminate** — once confident, migrate the rest of the traffic and retire the legacy path.

Migrate **one module at a time** — pick the next only after the current one is fully migrated and tested; parallel migration of several modules loses the incremental safety this pattern exists for.

**Progressive rollout once a component is ready:** 5% → 25% → 50% → 100% traffic, with an observation window (e.g. 24h) between stages. Automatic rollback triggers: error rate >1%, latency >2× baseline, or business-metric degradation.

**Success bar:** >80% test coverage on modernized components, zero unplanned downtime, P95 latency ≤110% of baseline, stable for 30 days post-migration with no rollback.

## Technical debt: find it, size it, sequence it

**Inventory categories:** code debt (duplication, complexity >10 cyclomatic, god classes >500 lines/>20 methods, circular deps, feature envy), architecture debt (missing/leaky abstractions, outdated frameworks, deprecated APIs), test debt (slow/flaky suites, low coverage), doc debt, infra debt (manual deploys, no rollback procedure).

**Cost a debt item** (not just "it's messy"):
```
monthly_cost = (hours_lost_to_it_per_month) × (loaded_hourly_rate)
priority = (business_value × technical_debt) / (effort × risk)
```
Business value and technical debt scored 1–10 (critical-path/production-bug-causing = 10); effort in hours; risk scored by test coverage + coupling (no tests + high coupling = 10).

**Sequence by ROI, not by what's most annoying:**
- **Quick wins** (hours, not weeks): extract duplicate logic, add missing error monitoring, automate a manual script — ship these first, they fund the rest.
- **Medium-term** (weeks): split a god class, upgrade a major framework version — needs its own tests before touching.
- **Long-term** (quarters): architectural change (e.g. DDD bounded contexts) — only after quick wins prove the pattern works.

**Prevent regrowth:** complexity/duplication gates in CI, a debt budget (e.g. "max 2% increase/month, mandatory 5% reduction/quarter"), two-approval review requiring tests on new code.

## Code quality reference

| Metric | Good | Warning | Critical → action |
|---|---|---|---|
| Cyclomatic complexity | <10 | 10–15 | >15 → split into smaller methods |
| Method length | <20 lines | 20–50 | >50 → extract methods, apply SRP |
| Class length | <200 lines | 200–500 | >500 → decompose |
| Duplication | <3% | 3–5% | >5% → extract shared code |
| Test coverage | >80% | 60–80% | <60% → add tests before refactoring |

**SOLID smells → fixes:** god object doing validation+persistence+email+logging → split by responsibility, inject collaborators (SRP). `if type == X / elif type == Y` dispatch that grows every release → strategy objects implementing a common interface, no modification needed for new types (OCP). Subclass that overrides a setter to break the parent's invariant (e.g. `Square extends Rectangle`) → both implement a shared interface instead of inheriting (LSP). One fat interface forcing unrelated implementers to stub methods they don't support → segregate into focused interfaces (ISP). High-level module importing a concrete low-level one (`UserService` constructs `MySQLDatabase` directly) → depend on an abstraction, inject the implementation (DIP).

## Rules with no exceptions
1. Tests stay green throughout — a failure means you changed behavior; stop and undo.
2. Commit after each small change — large commits hide which change broke what.
3. One transformation at a time.
4. Test after every change, not "at the end."
5. 3+ failures on one step → stop and reconsider the approach.

## Final checklist
- [ ] All tests pass, no new linter warnings, no behavior change
- [ ] Each commit is small, safe, and independently reviewable
- [ ] Code is measurably simpler (fewer lines, lower complexity, less duplication)
- [ ] Breaking changes (if any) are documented with a migration path

## Resources
- `resources/refactoring-patterns.md` — Extract Method, Rename, Extract Class, Inline Abstraction, each with before/after and the exact step sequence.
