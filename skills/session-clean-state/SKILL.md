---
name: session-clean-state
description: >
  Activate at session end to enforce clean handoff, or at session start to assess inherited state.
  Provides five-dimension clean state checklist, clock-in/clock-out protocols, Quality Document
  maintenance, and entropy management. Prevents the entropy spiral that degrades long-running
  agent projects week-over-week.
source: walkinglabs.github.io/learn-harness-engineering (Lectures 05, 12)
---

# Session Clean State

Agent reliability degrades over time without active entropy management. Each session that ends
without a clean handoff compounds state debt: broken builds, stale progress files, scattered debug
artifacts — and the next session spends 30+ minutes inferring what was intentional vs. temporary.

**Core model:** A session is a database transaction. Either fully commit and leave clean state, or
roll back to the last consistent state. No middle ground.

## When to Activate

- End of any session (clock-out protocol)
- Start of a session picking up from previous work (clock-in protocol)
- When diagnosing why session startup is slow or requires manual intervention
- During housekeeping or maintenance passes

## Five Dimensions of Clean State

A session is only complete when all five conditions are met:

| Dimension | Check | Failure |
|---|---|---|
| **Build passes** | `CI passes` or run verify command | Broken build blocks all successor sessions |
| **Tests pass** | All tests, including pre-existing ones | Regressions hidden in "done" work |
| **Progress recorded** | Feature list and PROGRESS.md updated | Successor spends 20 min inferring state |
| **No stale artifacts** | Debug code, temp files, TODO markers removed | Successor copies bad patterns |
| **Startup path functional** | Next session can run without manual intervention | Requires human to unblock |

Missing any single dimension means the session is incomplete — "the code compiles" is not clean state.

## Clock-Out Protocol (End of Session)

Run before ending any session that spans multiple features or days:

```
## Session End Checklist

- [ ] Verify command passes: <verify_command>
- [ ] All tests pass: <test_command>
- [ ] Feature list updated: F01–FN states current
- [ ] PROGRESS.md updated: completed work, in-progress, blockers, next steps
- [ ] Debug artifacts removed: grep for console.log/debugger/TODO/FIXME
- [ ] Clean commit: all completed work committed with descriptive message
- [ ] Startup path: next session can `<run_command>` without manual setup
```

Incomplete checklist = incomplete session. Do not report the task as done until all boxes are checked.

## Clock-In Protocol (Start of Session)

Run at the start of any session picking up from prior work:

```
1. Read PROGRESS.md — what is the current state? What was in progress?
2. Read feature list — which features are passing, active, blocked, not_started?
3. Run consistency check: <verify_command>
4. If checks fail — fix before starting new work; inheriting broken state means any new bugs are masked
5. Read DECISIONS.md (if exists) — why were the key choices made?
6. Resume from "Next Steps" section of PROGRESS.md
```

**Rebuild time target:** A well-maintained handoff should take ≤ 3 minutes to reach an executable
state. If it takes longer, the clock-out protocol failed.

## PROGRESS.md Structure

The progress file is the primary handoff artifact:

```markdown
# PROGRESS.md

## Current State
- Last commit: <hash> — <message>
- Build: passing / failing
- Tests: all passing / N failing (see below)

## Completed
- [x] F01: User registration (commit a3f2c1b)
- [x] F02: Login endpoint (commit b4e2d3c)

## In Progress
- [ ] F03: Password reset — 60% done; email sending works, link verification not yet implemented
  - Remaining: implement token validation in POST /api/reset-password/verify

## Blocked
- F07: Payment integration — waiting on Stripe webhook config from ops

## Known Issues
- None

## Next Steps (priority order)
1. Complete F03 token validation — see src/auth/reset.py:authenticate_token
2. Start F04: Profile update endpoint
```

## DECISIONS.md Structure (for longer projects)

Record rationale that would otherwise live only in session memory:

```markdown
# DECISIONS.md

## 2026-05-31: Use JWT over sessions for auth
**Decision:** JWT tokens stored client-side
**Rationale:** Stateless scaling; avoids session store dependency
**Rejected:** Redis sessions — adds infrastructure dependency
**Constraint:** Tokens expire in 24h; refresh endpoint required

## 2026-05-30: SQLite for local development, PostgreSQL for production
**Decision:** DB abstraction via SQLAlchemy
**Rationale:** Keep dev setup lightweight
**Expiry:** When production config stabilizes
```

## Quality Document (Module-Level Health Tracking)

For projects running 4+ weeks or with 5+ modules, maintain a quality document:

```markdown
# QUALITY.md

## Auth Module — Grade: A
- Verification passing: Yes
- Agent-understandable: Yes (ARCHITECTURE.md current)
- Test stability: Stable
- Architecture boundaries: Compliant
- Code conventions: Followed

## Cart Module — Grade: B
- Verification passing: Yes
- Agent-understandable: Partial (ARCHITECTURE.md stale)
- Test stability: 1 flaky test (test_cart_concurrent_add)
- Architecture boundaries: Compliant
- Code conventions: Followed

## Payment Module — Grade: C
- Verification passing: No (F07 blocked)
- Agent-understandable: No (no docs)
- Test stability: Unstable (2 failures)
- Architecture boundaries: Violations in payment/webhook.py:L45
- Code conventions: Partial
```

Grade thresholds:
- **A**: All 5 dimensions green
- **B**: 4 dimensions green
- **C**: ≤ 3 dimensions green — prioritize before new work

## Entropy Management

**Lehman's law:** Systems undergoing continuous change grow more complex unless actively managed.
Agent-generated codebases are especially vulnerable because agents copy patterns already present —
including bad ones.

**Entropy signals to catch at clock-out:**
- Temporary files not removed (debug-*.log, .tmp, scratch/)
- Commented-out code blocks left in place
- TODO/FIXME markers without associated issues
- Inconsistent naming (introduced when context was low)
- Debug prints (`console.log`, `print(`, `debugger`)

**Cleanup script (idempotent — safe to run multiple times):**
```bash
find . -name "debug-*.log" -delete       # temp logs
grep -r "console\.log\|debugger" src/ --include="*.ts" -l  # debug code
grep -r "TODO\|FIXME" src/ --include="*.py" -l             # untracked debt
```

## Harness Simplification Cadence

As model capabilities improve, some harness components become unnecessary overhead.

**Monthly review:** Temporarily disable one harness component, run 3–5 tasks, compare quality.
Retain if quality drops, remove if no difference.

Example: Anthropic found that sprint-splitting (essential for Sonnet 4.5) became unnecessary
overhead under Opus 4.6's stronger decomposition capabilities. The evaluator component, however,
remained valuable at task difficulty boundaries.

Principle: harness components should earn their keep on current capability benchmarks, not
historical ones.

## Anti-Patterns

| Anti-pattern | Consequence |
|---|---|
| "Clean up next session" | Next session doesn't know what's temporary; entropy compounds |
| "The code compiles" = clean | Misses 4 of 5 dimensions; hidden regressions |
| Skipping clock-in | Inherits broken state; new bugs masked |
| No PROGRESS.md | Successor spends 15–20 min inferring state |
| Skipping DECISIONS.md | Successor reverses previous decisions; design drift |

## Integration

This skill is enforced by:
- `reflect-agent` — runs clean-state check after each session reflection
- `housekeeping-agent` — periodic entropy scan and quality document update
- `evolve-agent` — audits session clean-state health as a harness dimension

Related skills:
- `feature-list-primitive` — feature state machine provides the progress tracking foundation
- `context-optimization` — compaction and handoff strategies for long sessions
- `agent-harness-design` — clean state is the 𝒢 (governance) component at the session boundary
