---
name: model-tiers
description: Pick the Claude model tier when spawning an Agent, writing an SDK call, or designing a pipeline — haiku (utility), sonnet (reasoning/subagents), opus (deep), fable (long autonomous).
triggers:
  - About to spawn a subagent via Agent tool
  - Choosing which Claude model to use in an API call or agent definition
  - Building a multi-agent system or pipeline
  - Deciding between claude-haiku, claude-sonnet, or claude-opus
  - Any agent architecture decision involving model selection
  - Writing code that calls the Anthropic SDK with a model parameter
  - Creating a new agent with a specific model requirement
---

# Model Tiers

Spend tokens where they compound. Waste none where they don't.

## The Five Tiers

| Tier | Task type | Default model | Typical tasks |
|---|---|---|---|
| **utility** | classification, expansion, validation, dedup | `claude-haiku-4-5-20251001` | query expansion, dedup verdict, format validation, input classification |
| **reasoning** | generation, synthesis, chat, planning | `claude-sonnet-4-6` | code generation, research synthesis, default agent work |
| **deep** | complex multi-step reasoning, high-stakes judgment | `claude-opus-4-8` | cross-modal eval, architectural decisions, when sonnet consistently falls short |
| **autonomous** | long, multi-sitting autonomous sessions | `claude-fable-5` | root-cause investigations, outage debugging, multi-hour refactors — work too large for one sitting |
| **subagent** | multi-turn tool loops, orchestrated agents | `claude-sonnet-4-6` | Agent() calls, worker agents, tool-heavy workflows |

**Key insight:** Subagents should use `sonnet`, not `opus`. Subagents run multi-turn tool loops where latency compounds and the bottleneck is tool-call reliability, not raw reasoning depth. Opus doesn't meaningfully improve tool use at 3× the cost.

**Fable 5 (autonomous tier):** Claude Code's most capable model — sustains long autonomous sessions, investigates before acting, and self-verifies more often than smaller models. Reach for it (alias `fable`, id `claude-fable-5`) when a task is larger than a single sitting or hands the agent an ambiguous, open-ended problem. Not the default; select with `/model fable`. For bounded reasoning that fits one session, `opus` is still the right deep-tier pick.

## Override Priority (highest wins)

1. Explicit user instruction ("use opus for this")
2. Task-specific override in code/config
3. Global default
4. Tier default (the table above)

## Decision Heuristics

**Use haiku when:**
- Single classification or scoring call
- Query expansion or reformulation
- Deduplication or similarity verdict
- Input validation (structure, format)
- Any task where latency matters and the quality bar is "good enough"
- Batch processing where cost compounds across thousands of calls

**Use sonnet when:**
- Generating code, prose, or structured output
- Synthesizing multiple sources
- Orchestrating tool calls in a conversation
- Running as an agent in a loop
- When in doubt — start here, upgrade to opus only if quality fails

**Use opus when:**
- The task requires sustained multi-step reasoning with many dependencies
- Cross-modal evaluation where subtle judgment calls determine quality
- Sonnet has demonstrably failed on a class of inputs after iteration
- Stakes are high and latency is acceptable (batch/offline work)

**Keep subagents on sonnet because:**
- They run loops — latency compounds across turns
- Tool-call accuracy (not reasoning depth) is the bottleneck in most agentic work
- Opus doesn't improve tool reliability meaningfully at 3× cost

## The Rubric Test

Before routing any task, ask: **"Can I write a rubric that a machine could grade the output against?"**

| Answer | Routing |
|---|---|
| **Yes** — pass/fail criteria are deterministic (word count, schema, citation format, test results, file count) | Execution tier → haiku or sonnet subagent |
| **No** — judgment required (is this architecture sound? does this analysis hold up?) | Reasoning tier → sonnet or opus |

**Why this works:** If you can write the rubric, the task has a deterministic quality bar. The execution agent produces output; the rubric grades it; the orchestrator only steps in on failures. If you cannot write the rubric, the quality judgment IS the task — route to the highest tier that can make that call.

**Catches what complexity scoring misses:** The rubric test is semantic where complexity scoring (above) is syntactic. Examples:
- "Write 50 personalized emails" → complexity signals say sonnet; rubric test says haiku (one per input, clear format, machine-gradable)
- "Review this architecture decision" → complexity signals say haiku (short prompt); rubric test says opus (architectural soundness cannot be machine-graded)

**Apply when:** complexity scoring gives ambiguous results, or task shape is execution-heavy but appears complex due to volume.

## Practical Patterns

```python
# Multi-agent pipeline: haiku for routing, sonnet for work, opus for judgment
router_model    = "claude-haiku-4-5-20251001"   # classify/route inputs
worker_model    = "claude-sonnet-4-6"            # do the actual work
evaluator_model = "claude-opus-4-8"             # judge quality of outputs (only if needed)

# Agent spawning — use sonnet, not opus
Agent(
    description="Research agent",
    prompt="...",
    model="sonnet"   # not "opus"
)

# API call — pick tier by task
client.messages.create(
    model="claude-haiku-4-5-20251001",  # validation/classification
    # or
    model="claude-sonnet-4-6",           # generation/synthesis
    # or
    model="claude-opus-4-8",            # deep reasoning only
    ...
)
```

## Complexity Scoring Signals

Before routing, score the task against these signals to determine which tier it warrants. More signals firing = higher tier.

| Signal | What to check | Weight |
|---|---|---|
| **Message length** | Short prompt (< ~50 words) → simpler task | Low |
| **Code block presence** | Contains code, stack traces, or file diffs → technical depth needed | Medium |
| **Keyword density** | Words like *architect, design, analyze, debug, refactor, evaluate* → reasoning tier; words like *summarize, list, format, validate, classify* → utility tier | High |
| **Dependency count** | How many prior context items / files does this reference? Many deps → higher tier | Medium |
| **Output novelty** | Is the answer derivable from a single source, or requires synthesis across multiple? Synthesis → sonnet/opus | High |
| **Reversibility** | High-stakes or hard-to-undo action (deploy, delete, schema change)? → at minimum sonnet | High |

**Scoring heuristic (inspired by OpenSquilla's SquillaRouter):**
- 0–1 signals firing → **haiku**
- 2–3 signals firing → **sonnet**
- 4+ signals firing, or any high-weight signal alone → **sonnet**, consider **opus** if quality matters greatly

Use this table when writing agent code that selects models, designing multi-agent pipelines, or deciding whether to upgrade a tier mid-session.

## Cost vs Quality Trade-off

When uncertain, start with sonnet. Upgrade to opus only after observing consistent quality failure on a class of inputs — not preemptively. Downgrade to haiku for any task where sonnet is overkill (most single-step classification work).

Before escalating to a higher tier, also check whether a better-curated skill would close the gap instead: SkillsBench (arXiv 2602.12670) found smaller model + curated skill ≥ larger model, no skill. Skill curation and model escalation are two competing levers — try tightening the skill first; it's usually cheaper than bumping the tier.

## Effort Level — An Orthogonal Dial

In Claude Code, reasoning **effort** is a separate lever from model choice. Levels: `low`, `medium`, `high`, `xhigh`, `max` (set via `/effort`, `CLAUDE_CODE_EFFORT_LEVEL`, or `effortLevel` in settings; this harness runs `high`). It governs how much the active model thinks per turn — independent of which tier you picked.

Use it before reaching for a bigger model: a `sonnet` task that fails on reasoning depth may succeed at `high`/`xhigh` effort without paying opus cost. Conversely, drop effort for cheap utility work. If a level exceeds what the active model supports, Claude Code falls back to the highest supported level. `max` removes the token ceiling on reasoning — pair it with the deep/autonomous tiers, not utility work. Note: this is a Claude Code session lever, not an Anthropic SDK `messages.create` parameter — don't write `effort=` into API calls.

### Model vs. Effort — Which Dial to Turn

The two dials fix different failures:
- **Model** changes what Claude *knows* — knowledge and reasoning ceiling.
- **Effort** changes how much *work* it does before checking back — files read, tests run, verification loops.

When Claude gets it wrong, ask: **"did it not know enough, or did it not try hard enough?"**
- **Not-knowing** — confidently wrong no matter how much context you add → bump the **model** tier.
- **Not-trying** — skipped a file, didn't run the tests, stopped early → raise the **effort** level.

Fix the context *first* — a clear prompt, the right tools/skills, and a way for Claude to self-verify — **before** touching either dial. A context gap can masquerade as either failure. (source: official ClaudeDevs post)
