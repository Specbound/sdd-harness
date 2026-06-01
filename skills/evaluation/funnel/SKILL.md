---
name: evaluation/funnel
description: LLM eval funnel — use evals as a pre-filter before A/B tests, decide when eval alone is sufficient to ship, and calibrate LLM judges against real user outcomes. Trigger keywords: eval funnel, pre-experiment filter, judge calibration, A/B test LLM, experiment bandwidth. Part of the evaluation skill family (see evaluation/SKILL.md for routing).
risk: safe
source: https://engineering.atspotify.com/2026/5/better-experiments-with-llm-evals-a-funnel-not-a-fork
---

# Eval Funnel — Pre-Experiment Filtering & Judge Calibration

> **Scope:** LLM feature experimentation pipelines, A/B test vs. eval decisions, judge calibration. For per-run rubric grading see `evaluation/micro`. For population failure patterns see `evaluation/macro`.

Use evals as a filter *before* A/B tests, not as an alternative to them. The funnel pattern: LLM judges eliminate bad candidates early so experiment slots are spent on treatments that have already passed a quality bar.

## When to Activate

- You're about to run an A/B test on an LLM feature and haven't filtered candidates with evals first
- You want to know whether an eval result is strong enough to ship without A/B
- You've run an A/B test and want to check whether your LLM judges are calibrated
- You're designing an experimentation workflow for an LLM product from scratch

## The Core Insight

Only ~12% of A/B tests produce ship-positive results; ~64% produce learning; ~42% of launched experiments eventually reverse due to secondary metric regression. Running evals first lets you discard clearly non-promising treatments before consuming experiment bandwidth.

**Tiered testing:**

| Signal strength needed | Approach |
|---|---|
| Directional / iteration | Quick eval sweep (LLM judges on a test set) |
| Pre-ship validation | Rigorous A/B test with guardrail monitoring |
| Judge calibration | Post-experiment scoring loop |

## Stage 1 — Pre-Experiment Filtering (Evals)

Run LLM judges on candidate treatments *before* committing to an A/B test slot.

**What to evaluate:** relevance, coherence, tone, intent alignment. Surface patterns the team hasn't manually identified. Score all variants in parallel, keep the top N.

**Decision gate:**
- Variant scores poorly vs. baseline → discard. Don't A/B test it.
- Multiple variants score similarly high → validated competition worth running.
- Only one variant clearly wins → consider whether A/B is even necessary (see Stage 2).

**Practical notes:** Use the same judge prompt you plan to use in Stage 3 calibration — consistency is required for the loop to work. Keep a record of eval scores and the exact judge prompt/model version used.

## Stage 2 — Experiment Decision Criteria

**Eval alone may be sufficient if:**
- The change is low-risk (no revenue/engagement metric exposure)
- The eval signal is very strong (large margin, consistent across test set)
- The change is reversible and monitoring is in place

**A/B test is required if:**
- The change affects guardrail metrics (session length, churn, revenue)
- The eval signal is borderline or mixed
- The change is a ship decision (not just an iteration)
- Stakeholders require statistical significance

During the A/B test, monitor guardrail metrics that are *not* the optimization target — this is what catches the 42% of shipped experiments that later reverse.

## Stage 3 — Post-Experiment Calibration

After an A/B test, run the *same LLM judges* from Stage 1 over the A/B data:

| Outcome | Interpretation |
|---|---|
| Judge preferred variant AND variant won A/B | Judge is well-calibrated ✓ |
| Judge preferred variant BUT variant lost A/B | Judge optimizing wrong signal — revisit eval dimension |
| Judge was neutral AND A/B was decisive | Judge is missing signal — add a new dimension |
| Judges split AND A/B was decisive | High variance in judge — investigate prompt stability |

**Calibration actions:**
- Well-calibrated: increase weight/trust for future pre-filtering
- Miscalibrated: update judge prompt, add ground-truth examples, or retire dimension
- Missing: instrument the A/B to surface what the judge should have caught

Record calibration results. Over multiple experiments this log tells you which judges to trust for ship decisions vs. directional filtering only.

## Success Criteria

- Stage 1 completed before any A/B test slot is committed
- A/B guardrail metrics defined before the experiment launched (not retrofitted)
- Stage 3 calibration ran within one sprint of A/B results arriving
- Calibration findings fed back into the judge prompt

## Related Skills

- `[[evaluation/micro]]` — rubric design, LLM-as-judge implementation, test set construction
- `[[prompt-engineering]]` — improving judge prompts based on calibration findings
- `[[instrument-agent]]` — adding observability to capture the data Stage 3 calibration needs
