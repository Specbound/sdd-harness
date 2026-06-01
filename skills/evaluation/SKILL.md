---
name: evaluation
description: Router for the evaluation skill family. Use when any kind of agent evaluation is needed — per-run grading, population patterns, long trajectories, or A/B test decisions. Reads the trigger conditions below and loads one or more sub-skills as needed.
---

# Evaluation Skill Router

This skill is the entry point for all evaluation work. It routes to the right sub-skill(s) based on your situation. You may need more than one — load all that apply.

## Sub-Skills

| Sub-skill | Invoke via | Use when |
|---|---|---|
| **micro** | `Skill("evaluation/micro")` | Grading individual runs — LLM-as-judge, rubric design, quality gates, continuous monitoring |
| **macro** | `Skill("evaluation/macro")` | Many runs — cluster recurring failure patterns, rank by impact, diagnose suspect workflow steps |
| **long-trajectory** | `Skill("evaluation/long-trajectory")` | Single run too long for a standard judge, agent mutates external state, or rubric needs calibration |
| **funnel** | `Skill("evaluation/funnel")` | Deciding whether to run an A/B test, pre-experiment filtering, or calibrating judges against user outcomes |

### Loading Multiple Sub-Skills

When a task spans more than one layer, load all relevant sub-skills before proceeding. Common multi-skill combos:

- **"Evaluate my agent and find patterns"** → `micro` + `macro`
- **"Set up an eval pipeline before we A/B test"** → `micro` + `funnel`
- **"My agent does 200-turn runs with DB writes"** → `long-trajectory` (verify) + `micro` (grade slices)
- **"Full eval system from scratch"** → `micro` + `long-trajectory` + `macro` + `funnel` (load in that order)

To load multiple, invoke each `Skill()` call in sequence before beginning implementation.

## Quick Decision Tree

```
Does a single run exceed context limits, or does the agent mutate external state?
  YES → load evaluation/long-trajectory (+ micro for grading the verified slices)
  NO  ↓

Do you have many runs (≥24) and want to find recurring failure patterns?
  YES → load evaluation/macro (+ micro if you also need per-run rubrics)
  NO  ↓

Are you deciding whether to run an A/B test, or calibrating a judge against user outcomes?
  YES → load evaluation/funnel
  NO  ↓

You need per-run grading, rubric design, or a quality gate.
      → load evaluation/micro
```

## Related Skills (Outside This Family)

- `[[cma-outcomes]]` — automated grade-and-revise loops via the Claude Managed Agents API; use alongside `micro` when you want the grader to loop automatically
- `[[rl-agent-training]]` — when the evaluation signal is also the RL training signal (RULER)
- `[[instrument-agent]]` — adding observability so long-trajectory verification is possible
- `[[multi-agent-patterns]]` — agent topology design (upstream of evaluation)
