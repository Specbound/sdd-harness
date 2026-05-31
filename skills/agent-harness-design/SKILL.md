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

## When to Activate

- Invoked automatically by `skill-extraction` in Phase 3 (harness alignment check)
- Designing a new agentic system or multi-agent architecture
- Diagnosing unexplained agent underperformance — identify which component is the bottleneck
- Evaluating whether a proposed skill, hook, or tool fills a real architectural gap

## Phase 1: Component Audit

For each component, ask: **is this explicitly designed, or implicitly handled (left to the model's discretion)?**

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
