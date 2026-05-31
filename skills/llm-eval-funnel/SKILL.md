---
name: llm-eval-funnel
description: "Use when designing LLM feature experimentation pipelines, deciding when to run A/B tests vs. evals, building pre-experiment filtering workflows, or calibrating LLM judges against real user outcomes. Trigger keywords: eval funnel, pre-experiment filter, judge calibration, A/B test LLM, experiment bandwidth."
risk: safe
source: https://engineering.atspotify.com/2026/5/better-experiments-with-llm-evals-a-funnel-not-a-fork
---

# LLM Eval Funnel

Use evals as a filter *before* A/B tests, not as an alternative to them. The funnel pattern: LLM judges eliminate bad candidates early so experiment slots are spent on treatments that have already passed a quality bar.

## When to Use This Skill

- You're about to run an A/B test on an LLM-powered feature and haven't filtered candidates with evals first
- You want to know whether an eval result is strong enough to ship without A/B, or whether you need the full experiment
- You've run an A/B test and want to check whether your LLM judges are calibrated (i.e., did the judge-preferred variant actually win with users?)
- You're designing an experimentation workflow for an LLM product from scratch

## The Core Insight

Only ~12% of A/B tests produce ship-positive results; ~64% produce learning; ~42% of launched experiments eventually reverse due to secondary metric regression. Running evals first lets you discard the clearly non-promising treatments before consuming experiment bandwidth.

**Key principle:** Not every change needs the same evidence. Use tiered testing:

| Signal strength needed | Approach |
|---|---|
| Directional / iteration | Quick eval sweep (LLM judges on a test set) |
| Pre-ship validation | Rigorous A/B test with guardrail monitoring |
| Judge calibration | Post-experiment scoring loop |

## Stage 1 — Pre-Experiment Filtering (Evals)

Run LLM judges on your candidate treatments *before* committing to an A/B test slot.

**What to evaluate:**
- Relevance, coherence, tone, and intent alignment of outputs
- Surface patterns the team hasn't manually identified (let the judge scan at scale)
- Multiple candidate variants in parallel — score all, keep the top N

**Decision gate:**
- If a variant scores poorly relative to baseline → discard. Don't A/B test it.
- If multiple variants score similarly high → you've validated competition worth running.
- If only one variant clearly wins on evals → consider whether A/B is even necessary (see Stage 2 criteria).

**Practical notes:**
- Use the same judge prompt you plan to use in Stage 3 calibration — consistency is required for the loop to work.
- Keep a record of eval scores and the exact judge prompt/model version used.

## Stage 2 — Experiment Decision Criteria

Decide when eval alone is sufficient vs. when you must A/B test.

**Eval alone may be sufficient if:**
- The change is low-risk (no revenue/engagement metric exposure)
- The eval signal is very strong (large margin over baseline, consistent across test set)
- The change is reversible and monitoring is in place

**A/B test is required if:**
- The change affects guardrail metrics (secondary dimensions like session length, churn, revenue)
- The eval signal is borderline or mixed
- The change is a ship decision (not just an iteration)
- Stakeholders require statistical significance

**During the A/B test**, monitor guardrail metrics that are *not* the optimization target — this is what catches the 42% of shipped experiments that later reverse.

## Stage 3 — Post-Experiment Calibration

After an A/B test completes, run the *same LLM judges* used in Stage 1 over the A/B test data. Compare:

| Outcome | Interpretation |
|---|---|
| Judge preferred variant AND variant won A/B | Judge is well-calibrated for this dimension ✓ |
| Judge preferred variant BUT variant lost A/B | Judge is optimizing for the wrong signal — revisit the eval dimension |
| Judge was neutral AND A/B was decisive | Judge is missing signal — add a new eval dimension |
| Judges split AND A/B was decisive | High variance in the judge — investigate prompt stability |

**Calibration actions:**
- Well-calibrated dimensions: increase weight / trust for future pre-filtering
- Miscalibrated dimensions: update the judge prompt, add ground-truth examples, or retire the dimension
- Missing dimensions: instrument the A/B experiment to surface what the judge should have caught

**Record the calibration result** in your eval system. Over multiple experiments, this log tells you which of your judges to trust for ship decisions vs. directional filtering only.

## Inputs and Outputs

**Inputs:**
- A set of LLM output variants (treatments) to compare
- An LLM judge prompt (or a set of judge prompts covering relevance, coherence, tone, etc.)
- Optional: A/B test results for calibration

**Outputs:**
- Filtered candidate list (Stage 1)
- Ship/A/B decision (Stage 2)
- Updated judge calibration log (Stage 3)

## Success Criteria

- Stage 1 completed before any A/B test slot is committed
- A/B guardrail metrics were defined before the experiment launched (not retrofitted)
- Stage 3 calibration ran within one sprint of A/B results arriving
- Calibration findings were written down and fed back into the judge prompt

## Safety

No file writes or network calls. This skill encodes a decision-making workflow, not an executable process.

## Related Skills

- [[evaluation]] — rubric design, LLM-as-judge implementation, test set construction
- [[prompt-engineering]] — improving judge prompts based on calibration findings
- [[instrument-agent]] — adding observability to capture the data Stage 3 calibration needs
