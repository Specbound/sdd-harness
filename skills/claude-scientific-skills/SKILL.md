---
name: claude-scientific-skills
description: Use when running scientific research or data-analysis tasks that require documented uncertainty, reproducibility, and a clear separation between raw observations and inferred conclusions — literature review, experiment design, statistical analysis, or reporting results.
source: "https://github.com/K-Dense-AI/claude-scientific-skills"
risk: safe
---

# Claude Scientific Skills

## When to Use
Apply this skill whenever a task involves scientific analysis: interpreting data, designing an experiment, evaluating a hypothesis, or writing up results for a technical audience.

## Core Rules

1. **Separate observation from inference.** State what the data shows before stating what it means. Label inferred conclusions explicitly ("This suggests..." not "This proves...").
2. **Quantify uncertainty.** Report confidence intervals, sample sizes, or error bars wherever a claim rests on data — never a bare point estimate when variance is knowable.
3. **Document reproducibility.** For any computed result, record the method, parameters, and random seed used, so someone else could rerun it and get the same answer.
4. **Pick the tool for the data type**: descriptive stats for summarizing, hypothesis tests for comparing groups, regression for relationships — and flag when sample size is too small for the test chosen.
5. **Surface limitations up front** — confounds, small N, non-random sampling — rather than burying them after the conclusion.

## Anti-patterns
- Stating a correlation as causation without a controlled design.
- Reporting a mean with no variance measure.
- Claiming a result was "verified experimentally" with no stated protocol.

For background, see the [source repository](https://github.com/K-Dense-AI/claude-scientific-skills).
