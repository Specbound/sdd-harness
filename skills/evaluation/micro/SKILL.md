---
name: evaluation/micro
description: Per-run agent evaluation — LLM-as-judge rubrics, test set design, quality gates, and continuous monitoring. Use when grading individual runs/responses, validating context engineering, or catching regressions. Part of the evaluation skill family (see evaluation/SKILL.md for routing).
---

# Micro Evaluation — Per-Run Grading

> **Scope:** Individual run grading (LLM-as-judge, rubrics, quality gates). For population patterns across many traces see `evaluation/macro`. For long trajectories that exceed context limits see `evaluation/long-trajectory`. For A/B test decisions see `evaluation/funnel`.

Evaluation of agent systems requires different approaches than traditional software. Agents make dynamic decisions, are non-deterministic, and often lack single correct answers. Effective evaluation must account for these characteristics while providing actionable feedback.

## When to Activate

- Testing agent performance systematically
- Validating context engineering choices
- Measuring improvements over time
- Catching regressions before deployment
- Building quality gates for agent pipelines
- Comparing different agent configurations
- Evaluating production systems continuously

## Core Concepts

Agent evaluation requires outcome-focused approaches that account for non-determinism and multiple valid paths. Multi-dimensional rubrics capture various quality aspects: factual accuracy, completeness, citation accuracy, source quality, and tool efficiency. LLM-as-judge provides scalable evaluation while human evaluation catches edge cases.

The key insight: agents may find alternative paths to goals — evaluate whether they achieve the right outcome, not whether they followed a specific path.

**Performance Drivers: The 95% Finding**

Research on the BrowseComp evaluation found three factors explain 95% of performance variance:

| Factor | Variance Explained | Implication |
|--------|-------------------|-------------|
| Token usage | 80% | Evaluate with realistic token budgets |
| Number of tool calls | ~10% | More exploration helps |
| Model choice | ~5% | Model upgrades beat token increases |

## Error-Analysis Bootstrap

Run this **before** rubric design when you have no failure taxonomy yet — starting a new eval project, after a major pipeline change, when a metric drops, or post-incident. It builds the vocabulary of what actually breaks from real traces, so the rubric in the next section reflects observed failures instead of guessed-at dimensions.

*Extracted from: Hamel Husain's `error-analysis` skill ([hamelsmu/evals-skills](https://github.com/hamelsmu/evals-skills)).*

**Phase 1 — Collect ~100 Traces**

"~100" is roughly where new traces stop revealing new kinds of failures. Prefer real usage data over synthetic.

| Strategy | When |
|---|---|
| Random | Default |
| Stratified | Ensure segment/complexity coverage |
| Outlier | Extremes in length/latency/tool-call count |
| Failure-driven | Flagged or complained-about traces |
| Uncertainty | Judge/human disagreement cases |

**Phase 2 — Read and Note**

Judge each trace Pass/Fail. On failure, record **only the first root-cause issue** — later errors usually cascade from it, and cataloging symptoms instead of causes inflates the category count with noise. Keep notes observational ("what happened"), not interpretive ("why it probably happened"). Four-column template: `Trace ID | Trace | What Went Wrong | Pass/Fail`. If you can't articulate an issue, check against common categories first: fabricated facts, malformed output, ignored requirements, wrong tone, tool misuse.

**Phase 3 — Group Into Categories**

Start clustering once you have 30–50 read traces — don't wait for all 100. This is inductive: categories emerge from what you observed, not from a list you brought in. Split notes that share surface wording but differ in root cause; merge notes that share a root cause despite differing surface details. Target 5–10 categories that are distinct, clearly defined, and actionable. An LLM can suggest groupings from your notes, but review every suggestion yourself — LLMs cluster on wording, not on true cause.

**Phase 4 — Label Every Trace**

Apply binary pass/fail per category, across all traces (spreadsheet, annotation tool, or script).

**Phase 5 — Compute Failure Rates**

Sum each category's failure count over total traces, sort descending. This is your priority order — not the order you found them in.

**Phase 6 — Decide Per Category**

1. **Direct fix first** — prompt gap, missing tool, engineering bug. Most failures end here.
2. **Only build an evaluator if the failure persists** and clears frequency + business-impact + will-actually-drive-iteration.
3. Prefer a **code-based check** (regex/schema) for objective failures; reserve **LLM-judge evaluators** (see Evaluation Rubric Design below) for genuinely subjective ones. Safety/compliance failures may warrant an evaluator as a standing guardrail even after the prompt fix lands.

**Phase 7 — Iterate**

Expect 2–3 refinement rounds: merge overlapping categories, split overly broad ones, clarify fuzzy definitions, re-label.

**Stopping criteria:** ~100 traces read, no new failure type in the last 20.

**Anti-patterns:** brainstorming categories before reading data · starting from a fixed predefined list · skipping user/product-owner involvement in early review · treating a generic quality score as if it were a failure category · building an evaluator before trying the direct fix · treating this as one-off rather than repeatable after every major change.

**Output:** write the taxonomy (categories, failure rates, decisions) to `.claude/memory/failure-taxonomy-<YYYY-MM-DD>.md` — same convention as `active-observability`'s `trace-patterns-<date>.md`. The harness dashboard's memory-files panel picks this up automatically; no separate registration needed.

## Evaluation Rubric Design

**Multi-Dimensional Rubric**

Effective rubrics cover key dimensions scored 0.0–1.0:

- **Factual accuracy** — claims match ground truth
- **Completeness** — output covers requested aspects
- **Citation accuracy** — citations match claimed sources
- **Source quality** — uses appropriate primary sources
- **Tool efficiency** — right tools, reasonable call count

Calculate a weighted overall score; set a pass threshold appropriate to your use case (commonly 0.7).

**Eval curation is a product decision, not an engineering task.** The rubric dimensions you choose and the weights you assign determine what the agent optimizes toward — if you weight "source quality" at 30%, you are telling the agent that sourcing matters 3× more than tool efficiency. Before finalizing any rubric, get explicit approval from whoever owns the product outcome. A technically correct rubric that rewards the wrong behavior is worse than no rubric: the agent will faithfully climb the wrong hill. Treat rubric sign-off as a product gate, not an engineering checkbox.

## Evaluation Methodologies

**LLM-as-Judge**

Provide the judge: task description, agent output, ground truth (if available), evaluation scale with level descriptions, and a request for structured output. Use consistent judge prompts across runs — instability in the prompt causes variance that looks like agent variance.

**Human Evaluation**

Humans catch what automation misses: hallucinated answers on unusual queries, subtle biases, and failures that only manifest in context. Sample systematically, track patterns, and focus human time on edge cases and borderline automated scores.

**End-State Evaluation**

For agents that mutate persistent state, evaluate whether the final state matches expectations — not how the agent got there.

## Test Set Design

**Sample selection:** Start small during development (large effects appear early). Sample from real usage patterns; add known edge cases; ensure coverage across complexity levels.

**Complexity stratification:**

```python
test_set = [
    {"name": "simple_lookup",    "complexity": "simple",       "description": "Single tool call"},
    {"name": "medium_query",     "complexity": "medium",       "description": "Multiple tool calls, comparison"},
    {"name": "multi_step",       "complexity": "complex",      "description": "Many tool calls, aggregation"},
    {"name": "research_synth",   "complexity": "very_complex", "description": "Extended interaction, synthesis"},
]
```

## Context Engineering Evaluation

Run agents with different context strategies on the same test set. Compare quality scores, token usage, and efficiency. Also run degradation tests at different context sizes to find performance cliffs and safe operating limits.

## Continuous Evaluation

Build pipelines that run automatically on agent changes. Track results over time. Sample production interactions randomly; set alerts for quality drops.

## Pitfalls

- **Overfitting to paths** — evaluate outcomes, not specific execution steps
- **Ignoring edge cases** — include diverse test scenarios
- **Single-metric obsession** — use multi-dimensional rubrics
- **Neglecting context effects** — test with realistic context sizes
- **Skipping human review** — automated evaluation misses subtle issues

## Related Skills

- `[[evaluation/macro]]` — when you have many traces and want recurring failure patterns
- `[[evaluation/long-trajectory]]` — when a single run is too long for a standard judge
- `[[evaluation/funnel]]` — when deciding whether to run an A/B test
- `[[cma-outcomes]]` — when you want automated grade-and-revise loops via the CMA API
- `[[rl-agent-training]]` — when the eval signal is also the RL training signal (RULER)

## References

- [Metrics Reference](../references/metrics.md) — detailed evaluation metrics and implementation
