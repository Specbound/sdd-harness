---
name: evaluation/long-trajectory
description: Evaluate long-horizon agents when standard per-run judges fail — trajectories too long for one context window, actions that mutate external state, or rubrics that need calibration against production outcomes. Three-phase workflow: Search (slice trajectory), Verify (check external systems), Adapt (Rubric Builder loop). Part of the evaluation skill family (see evaluation/SKILL.md for routing).
risk: safe
source: https://www.judgmentlabs.ai/blogs/agent-judge-solving-long-context-evaluations
---

# Long-Trajectory Evaluation — Agent Judge Patterns

> **Scope:** Long-horizon agent runs where standard judges fail. For standard per-run grading see `evaluation/micro`. For population patterns see `evaluation/macro`. For A/B test decisions see `evaluation/funnel`.

Standard LLM judges fail for long-horizon agents in three specific ways:
1. **Context overflow** — the full trajectory doesn't fit in a single judge context
2. **Stateful actions** — the agent changed external state (CRM, GitHub, DB, AWS) that can't be verified by reading the output text alone
3. **Rubric drift** — agent behavior evolves over time and static rubrics go stale

This skill applies the Agent Judge architecture (JudgmentLabs) to solve all three.

## When to Activate

- A single agent run is too long to fit in a standard judge's context window
- The agent performs stateful actions (API calls, DB writes, file changes, GitHub events) that need external verification
- Your rubrics are hand-authored and have never been calibrated against human labels or production outcomes
- A standard judge is underperforming (accuracy < 0.80) on your production traffic

## Do Not Use When

- The trajectory fits comfortably in a single context window → `[[evaluation/micro]]`
- You want patterns across many runs, not one deep run → `[[evaluation/macro]]`
- The agent is read-only (no state mutations) and your rubric is already calibrated → `[[evaluation/micro]]`

## Three-Phase Workflow

### Phase 1 — Search (Slice the Trajectory)

Rather than forcing the full trajectory into a single judge prompt, spawn worker agents to inspect targeted slices:

**Slice strategies:**
- By **turn range** — inspect specific conversation turns (e.g. turns 10–20 where the agent started tool-calling)
- By **tool-call chain** — extract all calls to a specific tool type (e.g. all database writes)
- By **state-transition** — identify turns where key state changed (status flips, handoffs, escalations)
- By **claim type** — extract all factual claims or assertions for downstream verification

**Multi-hop searching:** When an initial slice raises a new question, chain a follow-up search before judging. Example: slice finds an anomalous tool call → follow-up slice fetches all context around that tool call.

**Cross-run searching:** Compare slices against historical runs to surface deviations from typical behavior. This is especially useful for detecting prompt injection or unexpected capability use.

**Output of Phase 1:** A set of targeted evidence chunks, not a monolithic transcript.

### Phase 2 — Verify (Check External Systems)

For each claimed action in the evidence chunks, verify against the actual system state:

| System type | What to check |
|---|---|
| REST API / CRM | Response status codes, created/modified record IDs |
| Database | Row existence, field values, audit log entries |
| GitHub | Commit SHAs, PR state, issue comments, branch refs |
| Cloud infra (AWS/GCP) | Resource creation events, IAM changes, CloudTrail |
| File system | File existence, content hash, modification timestamp |
| Logs | Structured log entries, error codes, latency measurements |

**Verification rule:** Never trust the agent's description of what it did. Confirm against the external source of truth.

**Hallucination detection:** Compare agent claims against verified records. Discrepancy = hallucination or fabrication. This is the core signal in the JudgmentLabs empirical results (Agent Judge refined: 0.86 accuracy / 0.79 F1 vs. 0.74 / 0.65 for a standard LLM judge).

**Output of Phase 2:** A verified evidence record — each claim tagged as CONFIRMED, UNVERIFIABLE, or CONTRADICTED.

### Phase 3 — Adapt (Rubric Builder)

Static rubrics go stale. The Rubric Builder loop keeps them accurate:

```
1. Evaluate  — run current rubric on a batch of recent runs
2. Calibrate — compare rubric verdicts against:
               (a) human labels on the same runs
               (b) production outcomes (did the user complain? did the task succeed?)
               (c) disagreements between rubric dimensions
3. Refine    — identify dimensions where rubric diverges from ground truth
               → rewrite those dimension criteria
               → add examples (few-shot) for borderline cases
4. Iterate   — repeat until accuracy plateaus (typically 2–3 rounds)
```

**Calibration signals (in order of reliability):**
1. Human labels on matched runs — highest signal, highest cost
2. Production outcomes — implicit signal (task completion, user corrections, error rates)
3. Disagreements across dimensions — internal consistency check, free to compute

**When to trigger a Rubric Builder cycle:**
- Judge accuracy drops below 0.80 on a calibration batch
- Agent behavior changes significantly (new tools, new task types)
- More than 4 weeks since last calibration (stale rubrics accumulate drift)

## Practical Notes

**Minimum viable setup:** You don't need the full Agent Judge infrastructure to apply these patterns. Even a simple two-step process — (1) slice the trajectory by tool-call type, (2) verify one external claim per slice — materially improves judge accuracy on long runs.

**Parallel slicing:** Run multiple worker agents on different slices concurrently (use `parallel()` in a workflow) — wall-clock time ≈ slowest single slice, not sum of all slices.

**Evidence budget:** Aim for 3–5 high-signal evidence chunks per run, not exhaustive coverage. More chunks = more context for the final judge, but with diminishing returns past ~5.

**Rubric granularity:** For Phase 2 verification, prefer binary claims (CONFIRMED / CONTRADICTED) over scalar scores — they're easier to calibrate and more actionable.

## Related Skills

- `[[evaluation/micro]]` — for standard per-run grading when the trajectory fits in context
- `[[evaluation/macro]]` — for population-level pattern discovery after grading many runs
- `[[instrument-agent]]` — adding the observability needed to make Phase 2 verification possible
- `[[multi-agent-patterns]]` — patterns for spawning parallel worker agents in Phase 1
