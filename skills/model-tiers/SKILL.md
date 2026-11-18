---
name: model-tiers
description: Pick the Claude model tier when spawning an Agent, writing an SDK call, or designing a pipeline — haiku (high-volume/side tasks), sonnet (scoped), opus (default), fable (hardest/unattended).
triggers:
  - About to spawn a subagent via Agent tool
  - Choosing which Claude model to use in an API call or agent definition
  - Building a multi-agent system or pipeline
  - Deciding between claude-haiku, claude-sonnet, claude-opus, or claude-fable
  - Any agent architecture decision involving model selection
  - Writing code that calls the Anthropic SDK with a model parameter
  - Creating a new agent with a specific model requirement
---

# Model Tiers

Spend tokens where they compound. Waste none where they don't.

**Name models by alias** (`haiku`, `sonnet`, `opus`, `fable`) in agent definitions, `claude --model`, and examples. Aliases track the current lineup; a pinned ID goes stale at the next release. Pin an ID only where reproducibility matters more than currency (a metric baseline, a benchmark), and list that pin in `scripts/utils/model-mention-allow.txt` with the reason.

## The Four Tiers

Current lineup as of 2026-11-11: Haiku 5.5, Sonnet 5.5, Opus 5.5, Fable 5.2. Per-million-token input/output: $0.10/$0.50 (Haiku, prompts ≤100K; 5× above), $2/$10, $4/$20, $8/$40 — each step up is ~2×. The weekly `model-staleness` routine flags this line and every other model mention in the harness when the live lineup moves on (see **Staying Current**).

| Tier | Alias | Start here for | Starting effort |
|---|---|---|---|
| **utility** | `haiku` | classification, routing, tagging, high-volume extraction; **subagents that search files, read logs, or summarize** | model default |
| **scoped** | `sonnet` | well-scoped coding (bug fixes, spec-driven features), repeated agent tasks (review, investigation, drafting), chat, everyday docs | `medium`, then `high` |
| **default** | `opus` | everyday engineering and debugging, multi-PR features, computer use / vision loops — **and anything you're unsure about** | `medium` (its default) |
| **frontier** | `fable` | major refactors and migrations, architecture planning, leading many subagents, deep research, long unattended runs | `medium`, then `high` |

**Subagents:** a subagent that only reads and reports belongs on `haiku` (or `sonnet`) — wrong answers are cheap to spot and the main model keeps the judgment calls. A subagent that makes judgment calls of its own needs the tier that judgment needs. Keep the expensive model's context for decisions; let cheap subagents do the verbose reading — a lean main context matters more the bigger the main model is.

**A clear spec is not a reason to drop to sonnet.** A migration or performance optimization can be fully specified and still hard enough for `opus`, or `fable` for a major one.

(source: Osmani, "Which Claude model should you build with?", claude.dev, 2026-11-09)

## Override Priority (highest wins)

1. Explicit user instruction ("use opus for this")
2. Task-specific override in code/config
3. Global default
4. Tier default (the table above)

## The Rubric Test

Before routing any task, ask: **"Can I write a rubric that a machine could grade the output against?"**

| Answer | Routing |
|---|---|
| **Yes** — pass/fail criteria are deterministic (word count, schema, citation format, test results, file count) | Execution tier → haiku or sonnet subagent |
| **No** — judgment required (is this architecture sound? does this analysis hold up?) | Reasoning tier → opus, or fable for the hardest |

**Why this works:** If you can write the rubric, the task has a deterministic quality bar. The execution agent produces output; the rubric grades it; the orchestrator only steps in on failures. If you cannot write the rubric, the quality judgment IS the task — route to the highest tier that can make that call.

**Catches what complexity scoring misses:** The rubric test is semantic where complexity scoring (below) is syntactic. Examples:
- "Write 50 personalized emails" → complexity signals say sonnet; rubric test says haiku (one per input, clear format, machine-gradable)
- "Review this architecture decision" → complexity signals say haiku (short prompt); rubric test says opus (architectural soundness cannot be machine-graded)

## Practical Patterns

```python
# Multi-agent pipeline: haiku routes, sonnet does scoped work, opus judges
router_model    = "haiku"    # classify/route inputs
worker_model    = "sonnet"   # well-scoped work
evaluator_model = "opus"     # judge quality of outputs

# Read-and-report subagent — cheapest tier that can do it
Agent(description="Log reader", prompt="...", model="haiku")

# Claude Code agent definition (.claude/agents/<name>.md frontmatter)
#   model: haiku
# CLAUDE_CODE_SUBAGENT_MODEL sets the default for agents that name none.
```

For Anthropic SDK calls, use the current API ID from the live models page (platform.claude.com/docs/en/models/overview) — dateless IDs from the 4.6 generation on are pinned snapshots, so the `model-staleness` routine will flag them when superseded.

## Complexity Scoring Signals

Before routing, score the task against these signals. More signals firing = higher tier.

| Signal | What to check | Weight |
|---|---|---|
| **Message length** | Short prompt (< ~50 words) → simpler task | Low |
| **Code block presence** | Contains code, stack traces, or file diffs → technical depth needed | Medium |
| **Keyword density** | Words like *architect, design, analyze, debug, refactor, evaluate* → reasoning tier; words like *summarize, list, format, validate, classify* → utility tier | High |
| **Dependency count** | How many prior context items / files does this reference? Many deps → higher tier | Medium |
| **Output novelty** | Is the answer derivable from a single source, or requires synthesis across multiple? Synthesis → opus | High |
| **Reversibility** | High-stakes or hard-to-undo action (deploy, delete, schema change)? → at minimum opus | High |

**Scoring heuristic (inspired by OpenSquilla's SquillaRouter):**
- 0–1 signals firing → **haiku**
- 2–3 signals firing → **sonnet**
- 4+ signals firing, or any high-weight signal alone → **opus**; **fable** if the task is a major migration or runs unattended

## Cost vs Quality Trade-off

When uncertain, start on `opus` at `medium`. Move down to `sonnet` for well-scoped work and to `haiku` for high-volume checkable work; move up to `fable` when `opus` at `high` still falls short.

**Price per token is not cost per task.** A bigger model at lower effort can beat a smaller one at higher effort on both score and spend: Opus 5.5 at `high` matched Fable 5.1 at `max` on Terminal-Bench 3.0 with half the tokens, and Fable 5.2 at `high` matched Opus 5.5 at `max` on FrontierCode 2.0 for about half the cost per task. When comparing two models, price the hardest tasks in your set — on one 20-problem benchmark, two problems carried 43% of the spend.

Before escalating to a higher tier, also check whether a better-curated skill would close the gap instead: SkillsBench (arXiv 2602.12670) found smaller model + curated skill ≥ larger model, no skill. Try tightening the skill first; it's usually cheaper than bumping the tier.

### When the model falls short — escalate in this order

1. **Self-verification.** Give it a test, a build, or a script that calls the endpoint. Usually cheaper and lower-latency than any dial.
2. **Effort +1.**
3. **Next model up, at a lower effort** than you used on the smaller one. Past `high`, one more effort level can cost as much as the bigger model — test the next model up at lower effort instead of going to `xhigh`/`max`.

### Cascade Escalation — Per-Call, Not Per-Session

The guidance above is a *session-level* judgment call. Cascade escalation is the *per-call* version — run the cheap setting first on every call, and re-run only the calls that fail a check. When outcomes are checkable automatically, this beats running everything high: Opus 5.5 at `low` with failures re-run at `high` passed ~97% of a SWE-bench Pro subset at ~$0.17/task, against 95.3% at $0.29 with every task at `high`. Router research reports savings up to 98% of top-tier cost at matched quality (arXiv 2305.05176).

**Scope note:** that research is typically cross-provider. This harness only routes across Claude's own tiers — apply the cascade *shape* (cheap-first, escalate-on-failure), not trained cross-provider classifiers.

**When it's worth building:** a high-volume task class with a cheap, reliable failure signal (a verifier check, a test, a downstream failure) — not a one-off task where the session-level judgment above is simpler.

### Switching models mid-task

The prompt cache belongs to the model that wrote it — the first turn on a new model pays the cache-write price on the whole conversation. Switch at a natural break: `/compact` first, or start a fresh session from a short written plan. A move down a tier also loses earlier reasoning (a model never reads thinking blocks from a model above it).

## Effort Level — An Orthogonal Dial

Reasoning **effort** is a separate lever from model choice. Levels: `low`, `medium`, `high`, `xhigh`, `max`. In Claude Code set via `/effort` (`/effort status` shows yours), `CLAUDE_CODE_EFFORT_LEVEL`, or `effortLevel` in settings; on the Claude API it is the `effort` parameter. The harness sets none of these, so each session runs the active model's default — in Claude Code that is `medium` for all four current models (on the API, Sonnet and Fable default to `high`). Don't carry a level tuned on an older model to a newer one.

Raise effort only when it saves a retry: ~20K extra thinking tokens cost about the same as a ten-turn retry loop. (source: Osmani, "What a task costs on Opus 5.5", 2026-09-25) Effort also adds latency: on SWE-bench Pro, Opus 5.5 at `medium` scored ~2.5 points below `high` for ~70% of the cost; `xhigh` added ~1.4 points for 2.5× the cost of `high`. Drop effort for cheap utility work. `max` removes the ceiling on reasoning — pair it with the default/frontier tiers, not utility work.

### Model vs. Effort — Which Dial to Turn

The two dials fix different failures:
- **Model** changes what Claude *knows* — knowledge and reasoning ceiling. Higher effort never adds knowledge the model lacks.
- **Effort** changes how much *work* it does before checking back — files read, tests run, verification loops.

When Claude gets it wrong, ask: **"did it not know enough, or did it not try hard enough?"**
- **Not-knowing** — confidently wrong no matter how much context you add → bump the **model** tier.
- **Not-trying** — skipped a file, didn't run the tests, stopped early → raise the **effort** level.

Fix the context *first* — a clear prompt, the right tools/skills, and a way for Claude to self-verify — **before** touching either dial. A context gap can masquerade as either failure. (source: official ClaudeDevs post)

## Staying Current

`scripts/routines/model-staleness-runner.sh` runs weekly from the daily orchestrator (harness repo only). It fetches the live lineup from platform.claude.com, scans skills/agents/commands/hooks/scripts/templates for model names and IDs, and writes `.claude/reports/model-staleness.json`. `session-start-hook.sh` prints `[MODEL-STALE]` while new findings remain. To resolve one: update the mention (prefer an alias), or — if it is intentional history or a fixture — add it to `scripts/utils/model-mention-allow.txt`. Known-stale mentions not yet paid down live in `scripts/utils/model-mention-debt.txt`. Run it now with `python3 scripts/utils/model-staleness.py .`.
