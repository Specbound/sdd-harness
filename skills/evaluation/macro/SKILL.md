---
name: evaluation/macro
description: Population-scale agent evaluation — cluster recurring failure patterns across many traces, rank by impact (prevalence × severity), backward-trace to the suspect workflow step. Use when you have many runs and want to know which problems repeat and where to look first. Part of the evaluation skill family (see evaluation/SKILL.md for routing).
risk: safe
source: external
source_url: https://developers.openai.com/cookbook/examples/partners/macro_evals_for_agentic_systems/macro_evals_for_agentic_systems
---

# Macro Evaluation — Population-Scale Pattern Discovery

> **Scope:** Population patterns across many traces (tens to thousands). For per-run grading see `evaluation/micro`. For long single-run trajectories see `evaluation/long-trajectory`. For A/B test decisions see `evaluation/funnel`.

Micro evals grade one run ("was this answer correct?"). Macro evals ask a different question across the whole population:

> Which kinds of problems repeat across many traces, where do they concentrate, and which part of the workflow warrants inspection first?

Multi-agent systems make this hard because the final answer is only the last event in a longer workflow — a correct final answer can hide a broken middle. Macro evals treat trace bundles as analyzable evidence: compress each run into a comparable document, discover recurring patterns at population scale, then anchor diagnosis in explicit *focus events* and *suspect scoring*.

## When to Activate

- You have many agent traces/runs (tens to thousands) and want systemic patterns, not per-run grades
- A multi-agent system is live and accumulating traces; you want to know what to fix first
- Per-run eval labels already exist and you want to aggregate them into actionable themes
- You're triaging "the agent sometimes does X" and need to quantify how often, how badly, and where it originates

## Do Not Use When

- Grading a single response or small handful → `[[evaluation/micro]]` or `[[cma-outcomes]]`
- Deciding whether to ship a change → `[[evaluation/funnel]]`
- Designing the agent topology itself → `[[multi-agent-patterns]]`

## Core Principle

**The quality of the trace document is part of the evaluation design, not mechanical cleanup.** You cannot cluster raw traces usefully — you cluster *comparable compressed documents* that preserve the evidence (business setup, outcome, handoffs, review markers, state-transition digest) and drop the noise.

## The Two-Layer Model

```
MICRO (per-run signal)            MACRO (population pattern)
─────────────────────             ──────────────────────────
rubric pass/fail per run    ──▶   cluster runs into recurring behavior patterns
outcome + severity per run  ──▶   rank patterns by impact = prevalence × severity
                                  backward-trace high-impact patterns to a suspect step
```

Micro evals create the raw signal; macro evals reveal the patterns. Keep the layers separate.

## Workflow

### Phase 0 — Construct the Population from Traces

Before collecting runs, decide what they should measure. The most common mistake is pulling any available traces and assuming they represent what users actually care about. This phase anchors the benchmark to real user intent.

**Mine production PRDs.** Sample from recent production traces — specifically the initial user requests or task descriptions that launched each run. These are your benchmark tasks. Anonymize, deduplicate (cluster near-duplicate requests), and keep a stratified sample by complexity and task type. Avoid engineering-imagined tasks; the population must reflect what users actually request.

**Pair with natural-language test plans.** For each sampled task, write 2–5 natural-language assertions that describe what a correct outcome looks like at the feature level — not at the implementation level. Example: "The user can create an account and see a confirmation email" not "The POST /auth/register endpoint returns 201." Feature-level assertions stay valid as the agent's implementation strategy evolves; implementation-level assertions go stale.

**Maintain as a living document.** Anchor the population window to a recent time range (e.g., last 30 days of production traces) and refresh it when the trace distribution shifts materially — new feature launches, user segment changes, model upgrades. A benchmark frozen in time is a benchmark for a product that no longer exists.

**Human curation is required.** The PRD-extraction step is not mechanical — engineers must curate which tasks represent meaningful diversity and which are noise or duplicates. Schedule this as a deliberate activity, not a side step. The benchmark only climbs the right hill if a human confirmed the hill is the right one.

### Phase 1 — Collect & Normalize

Pull a population of traced runs and join any per-run eval labels. Each run becomes a row with: business setup / input context, outcome, severity, important handoffs, review/finding markers, a state-transition digest. Decide the population window (e.g. last N days) and a minimum size — patterns need density (typically ≥24 runs to cluster meaningfully).

### Phase 2 — Build the Trace Document

Compress each run into one comparable document:

```
case_type=<input/scenario class>
run_outcome=<completed | awaiting_review | blocked | failed>
eval_finding=<which rubric failed, if any>
handoffs=<specialist activations / reroutes>
review_markers=<findings, escalations, warnings>
state_digest=<compressed sequence of key state transitions>
```

Anti-pattern: clustering on raw event logs. Always compress first.

### Phase 3 — Discover Patterns (Cluster)

Group documents into recurring behavior patterns. Reference pipeline: **embed → reduce (UMAP) → cluster (HDBSCAN) → label (class-aware TF-IDF)**. For small N or no embedding infra, an LLM can group documents directly. Output shape:

```
behavior_pattern=<distinctive name, e.g. pricing_drift_with_unnecessary_escalation>
members=<run ids>
```

### Phase 4 — Prioritize by Impact

```
impact_score = prevalence_share × severity_weighted_prevalence
```

Severity weights (tune to your domain):

| Outcome | Severity weight |
|---|---|
| successful_completion | 1.0 |
| review_escalation | 2.0 |
| hard_failure | 2.5 |

Produce a leaderboard. The top patterns are your work list — strategic remediation, not chasing isolated anomalies.

### Phase 5 — Diagnose (Backward Suspect Trace)

For each high-impact pattern, reconstruct a lightweight execution graph for representative runs. Start from an explicit **focus event** (a review finding, a failure state, a late-stage decision). Walk backward and score upstream suspects:

```
suspect_score = 0.4·proximity + 0.3·frequency + 0.2·bridge + 0.1·role
```

- **proximity** — how close upstream to the focus event
- **frequency** — how often this step appears across the pattern's runs
- **bridge** — does it sit on the path between distinct subsystems/handoffs
- **role** — weight by the step's responsibility (decision > passthrough)

The suspect score is an **inspection guide, not proof of causality.** Output the top suspect steps per pattern for a human to inspect.

### Human Handoff — Hypothesis Selection Gate

After Phase 5 produces the ranked suspect list, the macro sweep ends and a human must take the next action. **The sweep cannot decide which cluster deserves the improvement budget.** That is a judgment call about product priority, engineering effort, and user impact — not a computation.

Present the top 3 candidates in this format:

```
Cluster A: [name] — impact score X, affects Y% of runs, top suspect: [step]
  Proposed hypothesis: "Changing [X] will address [failure mode]"
  Estimated effort: [small / medium / large]

Cluster B: ...

Cluster C: ...

Which should we pursue with the Harness-Improvement Loop? (or "none — run sweep again next cycle")
```

Wait for human selection before proceeding to the Harness-Improvement Loop (see `loop-patterns` Loop 11). Do not auto-select the highest-impact cluster; impact alone does not capture effort, feasibility, or current product priority.

## Do's and Don'ts

**Do:** Separate per-run evals (raw signal) from macro (pattern). Preserve evidence (handoffs, environment signals, review markers) in trace documents. Compare context with slice analysis. Anchor diagnosis on explicit focus events. Keep every score decomposable.

**Don't:** Assume a correct final answer means a correct workflow. Cluster raw traces. Treat isolated failures equally to repeated patterns. Read suspect scores as causality.

## Harness Integration

This methodology runs as the ~twice-weekly `/kiro:macro-eval-sweep` routine (driven by the daily orchestrator), which runs Phases 1–5 over Raindrop Workshop traces and writes a ranked report + posts findings back as annotations.

## Reference

Full scoring derivations, the BERTopic clustering stack, rubric/outcome taxonomy, a runnable pipeline sketch over Raindrop Workshop trace tables, and visualization patterns live in `../resources/pipeline-reference.md`.
