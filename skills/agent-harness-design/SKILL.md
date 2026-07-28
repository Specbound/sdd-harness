---
name: agent-harness-design
description: "Activate when designing or auditing an agentic system, diagnosing underperformance, or during skill-extraction Phase 3 to evaluate architectural fit. Provides the 6-component harness framework (reasoning/memory/context/skill-routing/orchestration/governance), temporal scaling tiers, and process metrics."
source: arXiv:2605.26112
---

# Agent Harness Design

An agent harness is the structured execution layer that translates foundation model capability into agent behavior. Performance is a function of all six components together:

```
𝒫_H = Φ(ℛ, ℳ, 𝒞, 𝒮, 𝒪, 𝒢)
```

Where:
- **ℛ** = Reasoning substrate (the foundation model)
- **ℳ** = Memory store
- **𝒞** = Context constructor
- **𝒮** = Skill-routing layer
- **𝒪** = Orchestration loop
- **𝒢** = Verification and governance

Each component is an independent point of intervention. A gap in one cannot be fully compensated by strengthening another.

> **The harness matters as much as the model.** On a fixed model, swapping only the harness produced a >2× cost swing (measured up to 2.4×) at equivalent quality — one setup used ~3× less context per turn than another for the same result. So rank agent setups by **cost-per-completed-task, not per-token price**. (source: Databricks agent-harness benchmark)

## When to Activate

- Invoked automatically by `skill-extraction` in Phase 3 (harness alignment check)
- Designing a new agentic system or multi-agent architecture
- Diagnosing unexplained agent underperformance — identify which component is the bottleneck
- Evaluating whether a proposed skill, hook, or tool fills a real architectural gap

## Phase 1: Component Audit

For each component, ask: **is this explicitly designed, or implicitly handled (left to the model's discretion)?**

### Improvement Layer Decision (start here when diagnosing a failure)

Before assuming a failure requires weight-level intervention (model upgrade, fine-tuning), explicitly route through the two layers that are always within your control:

| Layer | What it covers | Leverage |
|---|---|---|
| **Harness layer** | Prompts, tools, instructions, skill routing, orchestration logic | Fixes apply to every instance simultaneously — one change benefits all users |
| **Context layer** | Per-user memory, per-org preferences, personalized state | Fixes apply to one user/org — compounding per individual interaction |

**Decision rule:** Work harness-layer first. A harness fix that addresses the root failure mode is free for all instances — it compounds across the entire user base from the next deploy. A context-layer fix helps only the users for whom specific state is available. Model-layer fixes (weight updates, fine-tuning) are usually unavailable with closed frontier models and should be considered last.

**The non-obvious reframe:** Most teams experiencing agent underperformance default to "the model isn't smart enough." In the vast majority of cases, the actual failure is harness-layer (a prompt gap, a missing skill, a routing error) or context-layer (stale or absent personalization). The model's capability is rarely the binding constraint.

Apply this routing at the start of any diagnostic session before opening a component audit:
1. Is the failure consistent across all users/orgs? → harness layer
2. Is the failure isolated to specific users or inputs? → context layer (check memory, personalization state)
3. Is the failure present even with perfect harness and context? → escalate to model-layer consideration

### ℛ — Reasoning Substrate

The foundation model. Usually fixed, but affects what other components must compensate for.

Design questions:
- Is model selection matched to task tier? (Haiku for atomic ops, Sonnet for reasoning, Opus for planning)
- Is model selection a conscious decision per agent role, or defaulted everywhere?

Failure mode: same model for all agents regardless of task complexity — wastes cost on simple ops, undershoots on complex ones.

### ℳ — Memory Store

Persistent, retrievable knowledge that survives context resets.

Design questions:
- Does each memory entry carry (timestamp, confidence, source, verification_status)?
- Is staleness-penalty weighting applied at retrieval? (`rank = relevance − staleness_penalty × time_delta + confidence_weight`)
- Are memories verified against live state before acting on them?
- Is there a hygiene policy — when do memories expire or get demoted?

Failure mode: "stale-but-confident" memory — entries remain semantically high-ranked even after their referents are deleted or renamed.

Trust axes for memory quality:

| Axis | Definition |
|---|---|
| Precision | Accuracy within defined scope |
| Durability | Stability despite environment changes |
| Verifiability | Testability against live environment |
| Retrievability | Access cost and recall quality |

**Typed memory relationships.** Flat memory entries lose relationship context — a feedback entry might reference a project that no longer exists, or a user entry might reference a pattern that was superseded. Add one design question to the audit:

> *Are cross-references between memory entries typed and bidirectional?*

In the harness's auto-memory system (`~/.claude/projects/*/memory/`), this means:
- Use `[[slug]]` links with an inline relationship label: `[[feedback-testing]] (contradicts)`, `[[project-auth-rewrite]] (triggered by)` — not bare `[[slug]]` with no context
- When entry A links to entry B, entry B should link back to A with the inverse relationship
- Valid cross-type relationships: `feedback → project` (what triggered this rule), `project → user` (whose preference drives this), `reference → project` (what system this pointer belongs to). Avoid `user → feedback` (redundant — feedback files are already user-scoped) or `reference → reference` (circular; flatten instead)
- The `memory-discipline-hook.sh` transfer test applies to links too: only link if the cross-reference would help a *different future task*, not just to be complete

This requires no new infrastructure — the `[[name]]` convention is already in the system. The addition is the discipline: typed labels + bidirectionality + the same transfer test the hook already enforces for content.

**Proactive vs. reactive memory.** A second axis beyond freshness: *where memory comes from*.
- **Reactive** — the agent only remembers what the user explicitly hands it.
- **Proactive** — the agent fetches and maintains its own structured context from connected sources on a schedule, without being asked.

Proactive memory runs on **connectors**, of two kinds:

| Connector type | Behavior | Examples |
|---|---|---|
| **Deterministic** | Auto-fetches a feed on a schedule | Gmail, RSS |
| **Agentic** | Goal-directed search tool, invoked to satisfy an intent | web search, Notion |

**Harness↔model coupling is portability risk.** The tighter a connector or memory path couples to model-native integrations, the more the workflow breaks when that model gets expensive, goes down, or is pulled. Prefer coupling that can be re-pointed at another model. (source: LangChain OpenWiki; portability framing from Aparna Dhinakaran)

### 𝒞 — Context Constructor

The policy that assembles what goes into the context window for any given step.

Design questions:
- Is context assembly a **selection policy** (active filtering with criteria) or a **buffer fill** (append until full)?
- Are the four governance axes addressed?
- Does each context item carry provenance (source, timestamp, why included)?
- Is there a refresh policy for stale content?

Failure mode: "exposure without access" — the model sees more tokens but task-critical signal is diluted by irrelevant content.

Four governance axes:

| Axis | Design concern |
|---|---|
| Relevance | Semantic alignment to current task — score and filter, don't include by default |
| Compactness | Minimize tokens without dropping critical signal — prefer summaries over raw output |
| Traceability | Every context item has a source attribution for audit and failure analysis |
| Refresh Policy | Stale content is updated or evicted; environment state is checked before high-stakes actions |

#### Context as a Layered Cache (L1/L2/L3)

The governance axes say *what* good context looks like; this says *where* each capability should live. A user's task distribution is long-tailed — a few bread-and-butter operations dominate every session, a handful of capabilities recur occasionally, and a long tail of rare needs each still has to work. You cannot hold the union of everything in context at once. So the objective is sharper than "have everything available": **place each capability at the tier that minimizes total cost across the task distribution** — where cost = resident tokens (paid every task) + discovery tokens (paid on a miss).

| Tier | Placement | Pays | Use for |
|---|---|---|---|
| **L1** — resident | Always in context (CLAUDE.md, SKILL.md body, system prompt) | Tokens on *every* task | The 80%: bread-and-butter ops. Make them token-compressed and **consequence-reporting** (return what changed + what looks wrong, not just success). |
| **L2** — on demand | Fetched in one step (a `resources/` spec, a `getXInfo()`-style lookup, a deferred tool loaded via ToolSearch) | One cheap discovery call on a miss; zero until needed | The ~15%: important-but-occasional. Write curated, gotcha-aware specs — the canonical recipe and constraints, not just signatures. |
| **L3** — escape hatch | Raw complete substrate on disk; a short skill maps it with grep recipes | A bounded handful of tool calls on a rare miss | The long tail: the obscure need you can't anticipate. Don't paste the tome — ship the ~100-line skill that teaches how to mine it. The agent must never be truly stuck. |

Placement is the craft: push to L1 and it's instant but taxes every task; push to L3 and it's free until needed but costs several calls to find. This maps directly onto harness artifacts — L1 = CLAUDE.md + SKILL.md bodies, L2 = `resources/` files and deferred tools, L3 = on-disk references + a grep-recipe skill.

The boundary is not fixed — it slides with model strength. Stronger models absorb larger L2 specs and reason over more raw L3 detail in one shot, so yesterday's L3 becomes tomorrow's L2 and L2 collapses into L1. The hierarchy itself never disappears: context is always scarce relative to what could fill it, and noise always costs accuracy. (For the eviction/summarization mechanics within a tier, see `context-optimization`; for *when* interventions act over time, see the temporal-scaling tiers below.)

### 𝒮 — Skill-Routing Layer

The mechanism that selects which skill, tool, or subagent handles a given subtask.

Design questions:
- Does each skill have an explicit capability scope (what it handles and what it does not)?
- Are routing decisions auditable — can you trace why a skill was invoked?
- Are post-conditions verified after skill execution before results flow downstream?
- Can skills compose — does skill A's output meet skill B's input contract?

Failure mode: "confident-but-unchecked" — a specialized subagent produces output that looks correct but is never validated before the orchestrator acts on it.

Four routing quality requirements:

| Requirement | Description |
|---|---|
| Specificity | Explicit capability scope per skill — what it handles and what it refuses |
| Selectivity | Routing decisions are correct — the right skill is invoked for the right task |
| Composability | Skill outputs meet the input contracts of downstream skills |
| Verifiability | Post-condition checks run after execution, before downstream consumption |

### 𝒪 — Orchestration Loop

The control flow that drives multi-step execution: planning, step sequencing, error handling, recovery.

Design questions:
- Is there an explicit Plan-Execute-Verify loop, or does the model improvise step-by-step?
- Are failure modes handled at the loop level (retry, replan, escalate)?
- Is there a maximum iteration limit and graceful exit?
- Are intermediate checkpoints stored so recovery doesn't restart from zero?

Failure mode: no circuit breaker — a bad plan executes to completion before failure is detected.

Related skill: `agent-execution-control` covers Plan-Execute-Verify and gatekeeper patterns in depth.

### 𝒢 — Verification and Governance

The layer that validates outputs, enforces constraints, and measures harness health over time.

Design questions:
- Are verification checks deterministic (tests, assertions, type checks) rather than model self-assessment?
- Is there a distinction between soft gates (warnings) and hard gates (blocks)?
- Are process metrics being collected, not just outcome metrics?

Failure mode: governance is only outcome-based ("did the task complete?") — process failures go undetected.

#### Agent-Run Contract (define before granting autonomy)

Before granting any agent autonomy, write its contract:
- **Goal** — an *outcome*, not an activity ("auth tests pass on CI", not "work on auth")
- **Scope / non-goals** — what it must not touch
- **Tools / permissions** — the exact affordances granted
- **Stopping conditions** — when it halts (done, blocked, budget exhausted)
- **Evidence requirements** — the proof of success it must produce
- **Escalation path** — who/what it calls when stuck
- **Budget** — tokens, attempts, parallelism ceiling

**Three questions before granting high autonomy:**
1. How fast will problems surface?
2. How cleanly can the work be undone?
3. What independently verifies success?

If any answer is "slowly / not cleanly / nothing," lower the autonomy or tighten the contract first. (source: Addy Osmani)

## Anti-Patterns in Governance (𝒢)

### ❌ Portability Guard That Isn't Portable
A guard against platform-specific regressions must itself run on all target platforms — bash-4-only features fail on macOS default 3.2. (source: 2026-06-14)

### ❌ Governance Without Enforcement
Documenting an anti-pattern without enforcement (pre-commit, CI checks, bug tracking) lets known issues compound indefinitely. (source: 2026-07-09)

## Phase 2: Temporal Scaling Tiers

Every intervention operates at one of three timescales. Mismatching a solution to the wrong tier is a common source of fragility.

| Tier | Timescale | Role | Failure Mode |
|---|---|---|---|
| **Prompt** | Per-turn | Specifies current goal and constraints | Brittle — works for one task, breaks on variation |
| **Skill** | Per-task | Reusable workflow pattern invoked by routing | Wrong routing or poor composition |
| **Memory** | Cross-session | Preserves durable facts across resets | Drift, over-generalization, staleness |

Design rule: if solving a problem by making a prompt longer, ask whether it belongs in a skill. If repeating a skill result across sessions, ask whether it belongs in memory.

## Phase 3: Harness Alignment Check (used by skill-extraction)

When called from `skill-extraction` Phase 3, evaluate each proposed integration:

```
For each proposed item:
  1. Which component(s) does it strengthen? (ℛ/ℳ/𝒞/𝒮/𝒪/𝒢)
  2. Is that component currently weak/absent, or already covered?
  3. What temporal tier does it operate at? (prompt/skill/memory)
  4. Does it overlap with an existing skill — extend rather than duplicate?
  5. Does it introduce a dependency that weakens an adjacent component?
```

Output format per item:
```
- [Item]: strengthens [component(s)], operates at [tier] tier
  Current coverage: [weak / partial / covered]
  Verdict: [implement / extend existing / skip — reason]
```

## Process Metrics

Outcome metrics (task pass/fail) are necessary but insufficient. Collect per trajectory:

| Metric | What it catches |
|---|---|
| Context efficiency (tokens per decision point) | Bloated context assembly |
| Memory retrieval hit rate | Over-reliance on live lookup vs. memory |
| Staleness detection rate | Memory hygiene failures |
| Routing accuracy (correct skill ÷ total invocations) | Skill routing gaps |
| Verification failure rate | Governance gaps |
| Failed actions / retries per session | Orchestration loop fragility |
| Human interventions per session | Autonomy ceiling |

## Phase 4: Operational Diagnostics

### Fresh Session Test

The quickest way to assess harness completeness: start a new agent session with only repository
access and ask five baseline questions. Count how many are answerable without human input:

1. What is this system? (project purpose and boundaries)
2. How is it organized? (directory structure and module responsibilities)
3. How do I run it? (install + start commands)
4. How do I verify it? (test + lint commands)
5. What's the current progress? (active features, completed work, next steps)

**Score interpretation:**
- 5/5 answerable → harness complete; agent can operate autonomously
- 3–4 answerable → partial; expect re-exploration overhead on missed dimensions
- ≤2 answerable → harness incomplete; expect high failure rate on multi-session tasks

Questions 3 and 4 (run and verify) have the highest ROI to fix first — they unblock all other work.

### Controlled Ablation Methodology

To quantify which harness component is most valuable (vs. which is dead weight):

1. Define a baseline task set (5–10 representative tasks)
2. Run the full harness: record success rate, rebuild time, context efficiency
3. Remove **one component** and run the same tasks
4. Compare metrics; attribute the delta to that component
5. Restore the component; repeat for each component in turn

**Ablation order (by typical ROI, highest first):**
1. Feedback subsystem (verification commands) — usually highest return
2. Instruction quality (AGENTS.md content) — second highest
3. State persistence (PROGRESS.md) — critical for multi-session tasks
4. Environment specification (dependency lock files) — critical for fresh environments
5. Tool access breadth — often already correct; ablation reveals over-restriction

**Interpreting results:**
- Component removed, performance unchanged → component is dead weight at current capability level
- Component removed, performance drops >20% → component is load-bearing; protect it
- Component removed, performance *improves* → component is adding noise; refactor or remove

Harness rot check: if no component ablation causes a >20% drop, the harness is over-engineered for
current model capability. Run the simplification cadence (see `session-clean-state` skill).

### Affordance Analysis

After a failed or partial session, identify **execution gaps** vs. **evaluation gaps**:

| Type | Definition | Fix |
|---|---|---|
| Execution gap | Agent "wanted" to do something but couldn't (missing tool, permission, command) | Expand harness capability |
| Evaluation gap | Agent could have done the task but didn't know it was needed | Improve specification or verification |

Affordance questions:
- What did the agent attempt and fail due to tooling/permission errors?
- What did the agent not attempt that would have detected the bug?
- What information did the agent request but couldn't find?

Each identified gap maps to a specific harness component intervention.

### Harness Rot Detection (Quarterly)

Harness rot = components that existed for a good reason that no longer applies. Signs:

- Rules referencing deleted files or deprecated APIs
- Verification commands that always pass (no longer testing anything meaningful)
- Progress tracking files that agents no longer update
- State persistence mechanisms that model capability has made redundant

Monthly: ablation test one component.
Quarterly: full fresh-session test + component audit across all five subsystems.

## Phase 5: Harness Bottleneck Checklist

Seven structural failure modes that become sharper (not easier) as the harness runs more reliably. From Lilian Weng's agent harness survey (2026-07-04). Run this checklist when diagnosing unexplained quality plateaus or when a well-functioning harness starts producing diminishing returns.

| # | Bottleneck | Symptom | Diagnostic question |
|---|---|---|---|
| 1 | **Weak/fuzzy evaluators** | The judge says things are good; quality is not actually improving | Can the eval fail on a plausibly wrong output? If not, the evaluator is measuring presence, not quality |
| 2 | **Memory lifecycle management** | Artifacts (logs, diffs, summaries) grow beyond context windows; agent can't load its own history | Is there an explicit eviction or summarization policy? Are long-horizon artifacts chunked? |
| 3 | **Incentive misalignment** | Negative results are not logged; the loop only records wins | Does the loop persist failure cases? Are failed experiments part of the recipe? |
| 4 | **Diversity collapse** | Loop iterations converge on the same type of fix; novel solutions stop appearing | Are successive iterations seeded with distinct starting points, or does each start from the last successful state? |
| 5 | **Reward hacking** | Metrics improve but downstream quality does not | Is there a held-out eval set that the loop cannot optimize against? |
| 6 | **Short-term optimization bias** | Loop makes incremental gains but misses large restructuring wins | Is there a periodic "full rewrite" budget, or only local refinement? |
| 7 | **Inappropriate human oversight points** | Human is asked to approve every micro-decision (too many gates) or only at the very end (too few) | Map where the human lock is acquired. Does each gate require genuine judgment, or could it be automated? |

**When to run:** quarterly harness audit, after a loop runs 10+ iterations without improvement, when harness feels "stuck" despite technically correct execution.

**Relationship to process metrics:** Each bottleneck maps to a measurable signal. Bottleneck 1 → evaluator calibration test; Bottleneck 2 → `[loop-debt]` tag; Bottleneck 4 → diversity score on outputs; Bottleneck 5 → holdout eval vs. training eval gap.

---

## Meta Context Engineering (MCE)

A meta-level pattern where a dedicated agent optimizes *how context is managed*, not just what context contains. From Lilian Weng (2026) and AlphaEvolve-style harness optimization research.

**The reframe:** Most harness optimization improves task performance directly (better prompts, better tools, better memory). MCE adds a layer above: an agent that evolves the *context management strategy itself*.

**Three MCE shapes:**

**1. Agentic crossover over prior skills**
The meta-agent reads the history of which skills fired and how they performed, then proposes mutations to the skill routing or skill content. Each generation: select survivors (high-performing skills), mutate (adjust triggers, add cases, merge similar skills), evaluate on a benchmark task set, retain improvements.

**2. Context flow strategy evolution**
Instead of manually tuning L1/L2/L3 tier placement, a meta-agent runs ablations and reclassifies skills between tiers based on measured task-distribution hit rates. Output: updated tier assignments. Human reviews the proposed reclassifications, not each individual invocation.

**3. Harness self-repair loop**
The `evolve-agent` already does behavioral audit (Step D of daily maintenance). MCE extends it: after identifying a failure pattern, the evolve-agent proposes a structural change to the harness (not just a content fix) and submits it for human review. The change itself goes through the normal skill-extraction proposal flow.

**When to activate MCE:**
- The harness has been stable for >1 month and gains are incremental
- Multiple bottlenecks from the Phase 5 checklist are present simultaneously
- Skill routing errors are recurring (same wrong skill fires repeatedly despite fixes)

**MCE is not:** running the loop faster or adding more agents. It is changing the *rules the loop follows*. This requires human-in-the-loop review — MCE proposals are inputs to decisions, not autonomous rewrites.

---

## Integration

Related skills:
- `agent-execution-control` — Plan-Execute-Verify and gatekeeper patterns (𝒪 and 𝒢 in depth)
- `multi-agent-patterns` — Coordination and functional roles (𝒮 and 𝒪)
- `context-optimization` — Techniques for 𝒞
- `context-degradation` — Failure modes for 𝒞
- `instruction-architecture` — Lean entry file design and SNR maintenance (𝒮 routing efficiency)
- `feature-list-primitive` — Machine-readable feature state for 𝒢 governance
- `session-clean-state` — Session boundary discipline for ℳ and 𝒢

**Sources:**
- arXiv:2605.26112 — "From Model Scaling to System Scaling: Scaling the Harness in Agentic AI", Shangding Gu (2026)
- walkinglabs.github.io/learn-harness-engineering — Operational diagnostics and ablation methodology
- lilianweng.github.io/posts/2026-07-04-harness/ — Seven bottleneck checklist; Meta Context Engineering pattern; plan→execute→observe→improve loop framing
