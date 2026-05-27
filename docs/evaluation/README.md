# Evaluation

Skills and commands for LLM evaluation methodology — from general agent quality measurement to production experimentation pipelines.

---

## Skills

### `evaluation` — General Agent Evaluation
`~/.claude/skills/evaluation/SKILL.md`

The foundational evaluation skill. Covers:
- Multi-dimensional rubric design (relevance, coherence, factual accuracy, tool efficiency)
- LLM-as-judge implementation and prompt patterns
- Test set construction and complexity stratification
- Continuous evaluation pipelines and regression detection
- End-state vs. process evaluation for agent systems

**Activate with:** "evaluate agent performance", "build test framework", "measure agent quality", "LLM-as-judge", "evaluation rubric"

---

### `llm-eval-funnel` — Eval Funnel for A/B Experimentation
`~/.claude/skills/llm-eval-funnel/SKILL.md`

Extracted from: [Spotify Engineering — Better Experiments with LLM Evals: A Funnel, Not a Fork](https://engineering.atspotify.com/2026/5/better-experiments-with-llm-evals-a-funnel-not-a-fork) (2026-05-27)

Covers the three-stage methodology for integrating LLM evals into a product experimentation pipeline:

1. **Pre-experiment filtering** — run LLM judges on all candidate treatments to discard non-promising variants before committing an A/B test slot
2. **Experiment decision criteria** — tiered evidence framework: when eval alone is sufficient to ship vs. when A/B is required
3. **Post-experiment calibration** — score A/B data with the same judges to detect eval-outcome misalignment and feed findings back into judge design

**Key numbers from Spotify's production data:**
- 12% of A/B tests ship positive results
- 64% produce learning (validated knowledge even without shipping)
- 42% of launched experiments eventually reverse due to guardrail metric regression

**Activate with:** "eval funnel", "pre-experiment filter", "judge calibration", "A/B test LLM feature", "experiment bandwidth"

---

## Commands

### `/eval-funnel-check` — Pre-Launch Checklist
`~/.claude/commands/eval-funnel-check.md`

Interactive checklist command. Run before committing to an A/B test to verify:
- Evals have filtered candidate treatments (Stage 1)
- Guardrail metrics are defined (Stage 2)
- A calibration plan is in place post-experiment (Stage 3)

Produces a summary with ready/not-ready verdict and flags gaps.

**Usage:** `/eval-funnel-check [optional feature description]`

---

---

### `cma-outcomes` — Automated Grade-and-Revise Loops
`~/.claude/skills/cma-outcomes/SKILL.md`

Extracted from: [Anthropic Cookbook — Managed Agents: Verify with Outcome Grader](https://platform.claude.com/cookbook/managed-agents-cma-verify-with-outcome-grader) (2026-05-27)

Implements the full grade-and-revise loop using the Claude Managed Agents (CMA) Outcomes feature. Covers:
- When to use Outcomes vs. custom orchestration (the rubric-fit test)
- Creating writer agents, environments, and sessions via the CMA API
- `user.define_outcome` event structure and `max_iterations` control
- Writing rubrics that force the grader to fetch and verify evidence
- Event streaming loop monitoring (`span.outcome_evaluation_start/end`)
- Terminal state handling (`satisfied`, `max_iterations_reached`, `failed`, `interrupted`)
- Retrieving the final artifact from the event log
- Full Python template (setup → session → outcome → monitor → retrieve)

**Activate with:** "grade-and-revise loop", "CMA outcomes", "grader agent", "verify agent output automatically", "managed agents rubric"

---

## How the Skills Relate

```
evaluation          ← rubric design, judge implementation, test sets
    |
    ├── llm-eval-funnel   ← orchestration: when/how to deploy those judges
    |       |
    |       └── /eval-funnel-check   ← interactive checklist at experiment time
    |
    └── cma-outcomes      ← automated grade-and-revise using CMA Outcomes API

rl-agent-training   ← uses evaluation as a live training signal (RULER / reward fn)
    (see below)
```

The `evaluation` skill tells you *how* to build judges. `llm-eval-funnel` tells you *when* to run them across A/B experiments. `cma-outcomes` handles the case where the writer and grader run autonomously in a managed session loop — no custom orchestration needed.

---

## See Also: When Evaluation Becomes a Training Signal

If you want to use your evaluation/reward signal to **update model weights** — not just measure quality — see the `rl-agent-training` skill (`~/.claude/skills/rl-agent-training/skill.md`).

It covers online RL training with ART (Agent Reinforcement Trainer): run the agent many times, score each attempt with a reward function or RULER (comparative LLM judge), and update the model via GRPO. Small open-source models trained this way regularly outperform GPT-4/o3 on narrow tasks. Typical cost: $15–$200 in GPU time.

**Use `rl-agent-training` when:** you can run the agent and score outcomes, and want to bake the winning behavior into the model weights rather than just measure it.
