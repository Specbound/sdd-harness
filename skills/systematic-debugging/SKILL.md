---
name: systematic-debugging
description: Use when encountering any bug, test failure, unexpected behavior, or production incident, before proposing fixes. Covers root-cause investigation, strategy selection by failure type, multi-service debugging, and when to stop patching and question the architecture.
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

**Violating the letter of this process is violating the spirit of debugging.**

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## When to Use

Any technical issue: test failures, production bugs, unexpected behavior, performance
problems, build failures, integration issues, intermittent/distributed failures.

**Use ESPECIALLY when:** under time pressure, "just one quick fix" seems obvious, you've
already tried multiple fixes, the previous fix didn't work, you don't fully understand
the issue.

**Don't skip because:** the issue seems simple (simple bugs have root causes too), you're
in a hurry (rushing guarantees rework), or someone wants it fixed NOW (systematic is
faster than thrashing).

## The Four Phases

Complete each phase before proceeding to the next.

### Phase 1: Root Cause Investigation

1. **Read errors completely** — stack traces, line numbers, file paths, error codes often contain the exact solution.
2. **Reproduce consistently** — exact steps, every time? If not reproducible, gather more data, don't guess.
3. **Check recent changes** — git diff, recent commits, new dependencies, config/environment differences.
4. **Gather evidence in multi-component systems** (CI → build → signing, API → service → DB): instrument EVERY component boundary before proposing fixes — log what enters/exits each component, verify env/config propagation, check state at each layer. Run once to find WHERE it breaks, then investigate that component only.
5. **Trace data flow when the error is deep in the call stack** — see "Supporting Techniques" below for the full backward-tracing technique. Quick version: where does the bad value originate? What called this with it? Keep tracing up to the source; fix at source, not symptom.

### Phase 2: Pattern Analysis

1. **Find working examples** — locate similar working code in the same codebase.
2. **Compare against references** — if implementing a known pattern, read the reference implementation completely, not skimmed.
3. **Identify differences** — list every difference between working and broken, however small; don't assume "that can't matter."
4. **Understand dependencies** — what components, settings, config, assumptions does this need?

### Phase 3: Hypothesis and Testing

1. **Form a single hypothesis** — "I think X is the root cause because Y." Specific, not vague.
2. **Test minimally** — smallest change to test the hypothesis, one variable at a time.
3. **Verify before continuing** — worked → Phase 4. Didn't work → new hypothesis, don't stack more fixes on top.
4. **When you don't know** — say "I don't understand X." Don't pretend. Research or ask.

### Phase 4: Implementation

1. **Create a failing test case first** — simplest reproduction, automated if possible. Use `test-driven-development` for the mechanics.
2. **Implement a single fix** — the root cause, one change at a time, no "while I'm here" improvements.
3. **Verify the fix** — test passes, no other tests broken, issue actually resolved.
4. **If it doesn't work: STOP.** Count attempts. `< 3` → return to Phase 1 with new information. **`≥ 3` → question the architecture**, don't attempt fix #4 blind.
5. **3+ failed fixes = architectural problem, not a hypothesis problem.** Signs: each fix reveals new coupling/shared state elsewhere, fixes need "massive refactoring," each fix creates new symptoms. Stop and discuss refactor vs. continue patching with your human partner before any more fix attempts.

## Debugging Strategy Selection

Pick the approach that matches how the bug manifests:

| Situation | Strategy | Tools |
|---|---|---|
| Reproducible locally | Interactive | Debugger, step-through, breakpoints |
| Production-only | Observability-driven | Error tracker (Sentry/Rollbar), APM (DataDog/Honeycomb), trace analysis |
| Complex state, hard to reproduce | Time-travel | Record & replay (rr), Redux DevTools |
| Intermittent under load | Chaos engineering | Fault injection (Chaos Monkey/Gremlin) |
| Fails in small % of cases | Statistical/delta debugging | Compare successful vs. failing runs |

**Production-safe instrumentation** when you can't attach a debugger: feature-flagged debug
logging for specific users/cohorts, sampling-based continuous profiling (Pyroscope),
read-only auth-gated debug endpoints, canary a debug build to a small traffic slice.

## Multi-Service / Distributed Debugging

- Identify service and trace boundaries before instrumenting; add/verify correlation IDs
  that propagate across every hop.
- Correlate errors with deployment timeline, not just with each other — "what deployed
  right before this started" beats guessing.
- Check for cascading failures: one service's timeout becomes another's retry storm.
- Tool categories by failure type: logs (ELK/Loki), APM/traces (Jaeger/Zipkin/OTel/DataDog),
  metrics (Prometheus/Grafana), container/orchestration (`kubectl describe/logs`, OOMKilled
  → resource limits, CrashLoopBackOff → init container/probe config), network (tcpdump,
  dig/nslookup for DNS, security-group/firewall rules).
- Redact secrets/PII before sharing diagnostics; don't enable verbose tracing in prod
  without sampling and a rollback path.

## Error / Log Pattern Analysis

When the entry point is a pile of logs rather than a single stack trace:

1. Start from symptoms, work backward to cause.
2. Look for patterns across time windows, not single occurrences.
3. Correlate error spikes with deploys/config changes.
4. Write the extraction query precisely (log aggregation query, not ad-hoc regex scanning)
   so it's reusable for recurrence detection.

Output worth producing: timeline of occurrences, correlation across services, a root-cause
hypothesis backed by evidence, a monitoring query to catch recurrence, and the specific
code location likely at fault.

## Red Flags — STOP and Follow Process

- "Quick fix for now, investigate later" / "Just try changing X and see"
- "Add multiple changes, run tests" / "Skip the test, I'll manually verify"
- "It's probably X, let me fix that" / "I don't fully understand but this might work"
- "Here are the main problems: [lists fixes without investigation]"
- Proposing solutions before tracing data flow
- **"One more fix attempt" when already tried 2+, or each fix reveals a new problem elsewhere**

**All of these mean: STOP. Return to Phase 1.** 3+ failed fixes → question the architecture (Phase 4.5).

**Your human partner's signals you're doing it wrong:** "Is that not happening?" (you
assumed without verifying) · "Will it show us...?" (you should have added evidence
gathering) · "Stop guessing" · "Ultrathink this" (question fundamentals, not symptoms) ·
"We're stuck?" (your approach isn't working).

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "I'll write a test after confirming the fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question the pattern, don't fix again. |

## When Process Reveals "No Root Cause"

If investigation truly shows the issue is environmental, timing-dependent, or external:
document what you investigated, implement appropriate handling (retry, timeout, clear
error message), add monitoring for future occurrences. **But 95% of "no root cause"
verdicts are incomplete investigation** — check that before accepting it.

## Supporting Techniques (this directory)

- **`root-cause-tracing.md`** — trace bugs backward through the call stack to the original
  trigger; includes the `find-polluter.sh` bisection script for finding which test pollutes
  shared state.
- **`defense-in-depth.md`** — after finding root cause, validate at every layer (entry,
  business logic, environment guard, debug instrumentation) so the bug becomes structurally
  impossible, not just patched once.
- **`condition-based-waiting.md`** — replace arbitrary test timeouts/sleeps with condition
  polling to kill flaky, timing-dependent failures; see `condition-based-waiting-example.ts`
  for a full `waitFor`-style implementation.

**Related skills:** `test-driven-development` for the failing-test step in Phase 4;
`verification-before-completion` to verify the fix before claiming success.

## Anti-Patterns to Avoid

### Symptom-layer fixes in multi-layer systems
When fixing governance/operational issues (rules, memory writes, throttling), fixing the
symptom layer (e.g. restricting writes) without identifying the root decision layer that
emits the problem leaves enforcement conflicts unresolved — it bloats the blocker list
instead of fixing the source.

### Using filesystem metadata to identify structured records
Date records by primary data fields (`timestamp`), not filesystem mtime. Metadata lags;
data is truth.

## Quick Reference

| Phase | Key Activities | Success Criteria |
|---|---|---|
| **1. Root Cause** | Read errors, reproduce, check changes, instrument boundaries | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare, list differences | Identify differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Implementation** | Failing test, fix, verify | Bug resolved, tests pass |

Real-world impact of following this process: ~15-30 min to fix vs. 2-3 hours thrashing,
~95% first-time fix rate vs. ~40%, near-zero new bugs introduced vs. common.
