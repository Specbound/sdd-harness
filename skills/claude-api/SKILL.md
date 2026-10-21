---
name: claude-api
description: Anthropic SDK usage guidance — prompt-instruction anti-patterns that hurt frontier-model cost/accuracy, effort-calibration methodology, and model-selection pointers. Referenced by cma-advisor and cma-outcomes.
source: "archive.codenewsletter.ai/2097369738968195513"
---

# Claude API

Referenced by `cma-advisor` and `cma-outcomes` as "Anthropic SDK usage and model selection guidance" — this is that skill. Scope is prompt-authoring anti-patterns and effort calibration; model *tier* selection lives in `model-tiers`, and prompt caching economics live in `context-optimization` (see Prompt Caching Cost Note below for the one figure cross-referenced from there).

## When to Use

- Writing or auditing a system prompt / tool-use prompt for a frontier Claude model
- A prompt is verbose with verification rituals, thoroughness boosters, or scratchpad scaffolding and you're unsure whether any of it is still earning its keep
- Choosing an effort/reasoning setting for a task, or deciding whether a task needs a different model tier vs. a different effort level (see `model-tiers`' "Model vs. Effort" section for that specific decision)

## Prompt-Instruction Anti-Patterns

Frontier models (opus/sonnet-tier) already do these things by default. Instructing them to do it again adds tokens without adding behavior — and in some cases actively degrades output by making the model perform the instruction theatrically instead of doing the underlying work well.

| Anti-pattern | What it looks like | Why it hurts |
|---|---|---|
| **Verification rituals** | "Double-check your work before responding," "verify this is correct three times" | Frontier models already self-check within a response; explicit ritual instructions add tokens and can produce performative "checking" text instead of an actual second look |
| **Thoroughness boosters** | "Be extremely thorough," "leave no stone unturned," "think very carefully" | Vague intensifiers don't change what the model checks — they inflate output length without inflating rigor. A concrete rubric or checklist changes behavior; an adverb doesn't |
| **Scratchpad scaffolds** | "First think step by step in a section, then answer" boilerplate bolted onto every prompt regardless of task | Useful for genuinely hard reasoning tasks; costly boilerplate for tasks that don't need it. Reserve for tasks that demonstrably fail without it, not as a default prefix |

**Rule of thumb:** if removing the instruction wouldn't change what a frontier model actually does, it's a hollow instruction — cut it. Keep instructions that name a *specific, checkable* requirement (a schema, a rubric, a list of things to verify) over ones that just ask for more effort in the abstract.

## Effort-Calibration / Hillclimb Methodology

When a prompt's output quality is genuinely uncertain, don't guess at a model+effort combination — search it:

1. Build a train/test split of representative inputs for the task (even 10-20 examples is enough to start).
2. Grid a small set of (model tier, effort level) combinations against the **train** split — score with a rubric, not vibes (see `model-tiers`' Rubric Test for whether a rubric is even possible here).
3. Pick the cheapest combination that clears the quality bar on train.
4. Confirm on **test** — a combination that only works on the examples you tuned against is overfit to those examples, not to the task.
5. Re-run the sweep when the task's input distribution shifts meaningfully, not on a fixed schedule.

This is the same escalate-only-when-needed principle as `model-tiers`' cascade escalation section, applied at prompt-design time instead of per-call runtime.

## Prompt Caching Cost Note

Full prompt-caching guidance (breakpoint placement, TTL selection, `context-optimization`'s "read on demand" inversion principle) lives in `context-optimization` — this is a pointer, not a duplicate. The one figure `context-optimization` cross-checks against this skill: a `"ttl": "1h"` cache write costs **~2× base price (≈100% more)**, not the default 5-minute TTL's ~25% write premium — so a 1-hour breakpoint needs **3+ reads** within its TTL to pay for itself, not 2. Choose the 1-hour TTL to survive gaps in bursty traffic, not because it hits break-even sooner — it doesn't.

## Related Skills

- `model-tiers` — which model tier to use, and the separate effort-level dial
- `context-optimization` — prompt caching mechanics and economics, startup-payload budgeting
- `cma-advisor`, `cma-outcomes` — Claude Managed Agents features that reference this skill for SDK/model guidance
