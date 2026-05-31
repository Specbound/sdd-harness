---
name: macro-evals
description: "Evaluate agentic systems at population scale — cluster recurring failure patterns across many traces, rank by impact (prevalence × severity), backward-trace each to the suspect workflow step. Use when you have many agent runs/traces (not one response) and want to know which problems repeat and where to look first. The macro layer above per-run grading (see evaluation, cma-outcomes)."
risk: safe
source: external
source_url: https://developers.openai.com/cookbook/examples/partners/macro_evals_for_agentic_systems/macro_evals_for_agentic_systems
---

# Macro Evals for Agentic Systems

Micro evals grade one run ("was this answer correct?"). **Macro evals** ask a different question across the whole population:

> Which kinds of problems repeat across many traces, where do they concentrate, and which part of the workflow warrants inspection first?

Multi-agent systems make this hard because the final answer is only the last event in a longer workflow — a correct final answer can hide a broken middle. Macro evals treat trace bundles as analyzable evidence: compress each run into a comparable document, discover recurring patterns at population scale, then anchor diagnosis in explicit *focus events* and *suspect scoring*.

## Use this skill when

- You have many agent traces/runs (tens to thousands) and want to find systemic patterns, not grade one response
- A multi-agent system is live and accumulating traces; you want to know what to fix first
- Per-run eval labels already exist (pass/fail rubrics) and you want to aggregate them into actionable themes
- You're triaging "the agent sometimes does X" and need to quantify how often, how badly, and where it originates

## Do not use this skill when

- You're grading a single response or a small handful → use `[[evaluation]]` (LLM-as-judge) or `[[cma-outcomes]]` (grade-and-revise)
- You're deciding whether to ship a change → that's an A/B / funnel question → `[[llm-eval-funnel]]`
- You're designing the agent topology itself → `[[multi-agent-patterns]]`

## Core principle

**The quality of the trace document is part of the evaluation design, not mechanical cleanup.** You cannot cluster raw traces usefully — you cluster *comparable compressed documents* that preserve the evidence (business setup, outcome, handoffs, review markers, state-transition digest) and drop the noise.

## The two-layer model

```
MICRO (per-run signal)            MACRO (population pattern)
─────────────────────             ──────────────────────────
rubric pass/fail per run    ──▶   cluster runs into recurring behavior patterns
outcome + severity per run  ──▶   rank patterns by impact = prevalence × severity
                                  backward-trace high-impact patterns to a suspect step
```

Micro evals create the raw signal; macro evals reveal the patterns. Keep the layers separate — don't try to compute population patterns inside a per-run grader.

## Workflow

### Phase 1 — Collect & normalize

Pull a population of traced runs and join any per-run eval labels you have. Each run becomes a row with: business setup / input context, outcome, severity, important handoffs, review/finding markers, a state-transition digest. Decide the population window (e.g. last N days) and a minimum size — patterns need density (typically ≥24 runs to cluster meaningfully).

### Phase 2 — Build the trace document

Compress each run into one comparable document. A good document preserves evidence and is *short enough to embed and compare*:

```
case_type=<input/scenario class>
run_outcome=<completed | awaiting_review | blocked | failed>
eval_finding=<which rubric failed, if any>
handoffs=<specialist activations / reroutes>
review_markers=<findings, escalations, warnings>
state_digest=<compressed sequence of key state transitions>
```

Anti-pattern: clustering on raw event logs. Always compress first.

### Phase 3 — Discover patterns (cluster)

Group documents into recurring behavior patterns. The reference pipeline is BERTopic-style: **embed → reduce (UMAP) → cluster (HDBSCAN) → label (class-aware TF-IDF)**. When a full clustering stack is overkill (small N, or no embedding infra), an LLM can group the documents directly: ask it to read the compressed documents and emit named behavior-pattern groups with membership. Either way the output is the same shape:

```
behavior_pattern=<distinctive name, e.g. pricing_drift_with_unnecessary_escalation>
members=<run ids>
```

### Phase 4 — Prioritize by impact

A pattern matters more when it is both **common and severe**. Score every pattern with a *decomposable* formula so the ranking is explainable:

```
impact_score = prevalence_share × severity_weighted_prevalence
```

Outcome severity weights (tune to your domain):

| Outcome | Severity weight |
|---|---|
| successful_completion | 1.0 |
| review_escalation | 2.0 |
| hard_failure | 2.5 |

Produce a leaderboard. The top patterns are your work list — strategic remediation, not chasing isolated anomalies.

### Phase 5 — Diagnose (backward suspect trace)

For each high-impact pattern, reconstruct a lightweight execution graph for representative runs. Start from an explicit **focus event** (a review finding, a failure/blocked state, a late-stage decision) — *not* a vague "it went wrong." Walk backward and score upstream suspects with a decomposable formula:

```
suspect_score = 0.4·proximity + 0.3·frequency + 0.2·bridge + 0.1·role
```

- **proximity** — how close upstream to the focus event
- **frequency** — how often this step appears across the pattern's runs
- **bridge** — does it sit on the path between distinct subsystems/handoffs
- **role** — weight by the step's responsibility (decision > passthrough)

The suspect score is an **inspection guide, not proof of causality.** Output the top suspect step(s) per pattern for a human to inspect.

## Do's and don'ts

**Do**
- Separate concerns: per-run evals = raw signal; macro = pattern.
- Preserve evidence (handoffs, environment signals, review markers) in the trace document.
- Compare context with slice analysis (lift: is this pattern concentrated in one case_type?).
- Anchor diagnosis on explicit focus events.
- Keep every score decomposable into interpretable components.

**Don't**
- Don't assume a correct final answer means a correct workflow.
- Don't cluster raw traces — compress to comparable documents first.
- Don't treat isolated failures equally to repeated patterns.
- Don't read suspect scores as causality — they guide inspection.

## Reference

Full scoring derivations, the BERTopic clustering stack, the rubric/outcome taxonomy, a runnable pipeline sketch over Raindrop Workshop trace tables, and visualization patterns (Sankey, leaderboard, heatmap, swimlane) live in `resources/pipeline-reference.md`.

This methodology is automated in this harness as the ~twice-weekly `/kiro:macro-eval-sweep` routine (driven by the daily orchestrator), which runs Phases 1–5 over Raindrop Workshop traces and writes a ranked report + posts findings back as annotations.
