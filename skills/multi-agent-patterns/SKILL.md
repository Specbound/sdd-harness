---
name: multi-agent-patterns
description: "Activate when designing multi-agent systems, implementing supervisor/swarm/hierarchical patterns, coordinating subagents, or choosing a workflow pattern (classify-and-act, fan-out-and-synthesize, adversarial verification, generate-and-filter, tournament, loop-until-done). Also activate when the user mentions ultracode, dynamic workflows, workflow patterns, or asks how to avoid agentic laziness / self-preferential bias / goal drift."
---

# Multi-Agent Architecture Patterns

Multi-agent architectures distribute work across multiple language model instances, each with its own context window. When designed well, this distribution enables capabilities beyond single-agent limits. When designed poorly, it introduces coordination overhead that negates benefits. The critical insight is that sub-agents exist primarily to isolate context, not to anthropomorphize role division.

## When to Activate

Activate this skill when:
- Single-agent context limits constrain task complexity
- Tasks decompose naturally into parallel subtasks
- Different subtasks require different tool sets or system prompts
- Building systems that must handle multiple domains simultaneously
- Scaling agent capabilities beyond single-context limits
- Designing production agent systems with multiple specialized components

## Tool Selection: Agent vs. Workflow

Before designing architecture, pick the right tool. Two mechanisms exist in Claude Code:

| | `Agent` tool | `Workflow` tool |
|---|---|---|
| **Orchestration** | Ad-hoc, model-driven | Deterministic JS script |
| **Scale** | 2–10 parallel subagents | Tens to hundreds |
| **Control flow** | Model decides what to spawn next | `pipeline()` / `parallel()` / `phase()` primitives |
| **Token cost** | ~15× baseline | Substantially higher — start scoped |
| **Resume** | No | Yes — progress persists across interruptions |
| **Best for** | Independent investigations, targeted fixes, research queries | Service-wide audits, multi-hundred-file migrations, adversarial verification sweeps |

**Decision rule:**

```
Task scope?
├── 2–10 independent subtasks, each well-defined
│   → Agent tool  →  load superpowers:dispatching-parallel-agents
│
└── Tens-to-hundreds of parallel units, or task shape is:
    - "audit every X across the entire service"
    - "migrate all Y files matching pattern Z"
    - "run N independent verification passes then converge"
    → Workflow tool  (script with agent()/pipeline()/parallel())
```

**ultracode mode:** Claude Code's effort menu includes an `ultracode` setting that sets effort to `xhigh` and automatically deploys workflows for complex tasks. Enable for sessions where you want Claude to self-select the Workflow tool without an explicit instruction. Start with scoped tasks first to gauge token consumption before enabling it broadly.

**First-workflow confirmation:** The first time a Workflow fires in a session, Claude shows the planned execution and waits for user confirmation before spawning agents.

**`parallel()` vs `pipeline()`:** `parallel()` is a barrier — fans out, waits for ALL results before returning. `pipeline()` is streaming — each item flows through every stage independently. Decision: *do I need all results before I can do anything next?* Yes → `parallel`. No → `pipeline` (cheaper, faster overall).

**Token budget guidance:** Workflows consume substantially more tokens than typical sessions. The right strategy: start with a narrow scope (one subsystem, one file pattern), measure cost, then widen. Never start with "audit everything" — start with "audit the auth module."

---

## Dynamic Workflow Patterns

Dynamic Workflows (shipped Claude Code May 28, 2026) let Claude write its own custom harness for a task — a JavaScript file using `agent()`, `parallel()`, `pipeline()` plus standard JS. Trigger by asking "make a workflow that…" or using the `ultracode` keyword. Interrupted workflows resume from where they left off.

### The 3 Failure Modes Workflows Fix

Reach for a workflow when your task shows any of these:

| Failure mode | Symptom | Structural fix |
|---|---|---|
| **Agentic laziness** | Stops at partial progress, calls it done (reviewed 20 of 50 items, declares "handled") | Fan-out-and-synthesize — each item gets its own agent |
| **Self-preferential bias** | Claude verifying its own output favors that output; can't be a fair judge of its own work | Adversarial verification — separate context, no shared history |
| **Goal drift** | Original constraints quietly disappear after compaction; "don't do X" vanishes at turn 47 | Fan-out — each agent carries only its scoped goal, not the full accumulated history |

If none of these apply → a regular Claude Code session is faster and cheaper.

### The 6 Patterns

#### 1. Classify-and-Act
A classifier agent decides task type first, then the workflow routes to different agents or behaviors.

**When to use:**
- Heterogeneous task set — different sub-types need different treatment
- Want to spend expensive model only where complexity demands it (cheap classifier → route to Opus only for hard cases)
- Decomposition itself is non-trivial

**Shape:** `classifier agent → route decision → specialist agent(s)`

**Example:** Explain a module. Classifier reads codebase first, estimates complexity, routes to Sonnet (≤10 files) or Opus (>10 files).

---

#### 2. Fan-Out-and-Synthesize
Split into many independent steps, run an agent per step in parallel, merge results into one answer.

**When to use:**
- Clearly enumerable list of work items (50 files, 200 endpoints, 100 reviews)
- Each item is independent — no item needs another's output to begin
- Want a single consolidated answer at the end

```javascript
// Fan out: one agent per file. parallel() = barrier.
const reviews = await parallel(
  files.map(file => () => agent(
    `Review ${file} for security issues`,
    { model: "haiku", schema: IssueList }
  ))
)

// Synthesize: Opus merges everything after barrier completes.
const report = await agent(
  `Merge these reviews into one prioritized report:\n${JSON.stringify(reviews)}`,
  { model: "opus" }
)
```

---

#### 3. Adversarial Verification
For each worker agent, spawn a separate verifier that checks output against a rubric. The verifier has never seen the original work — it cannot favor it.

**When to use:**
- Claim-checking (each factual statement in a report gets its own verifier)
- Code review (author agent writes the fix, reviewer agent reviews — never the same Claude)
- Quality gates before shipping an artifact

**Pairing rule:** The verifier must know only the rubric and the artifact — not who produced it. Any hint of authorship reintroduces self-preference.

**Shape:** `worker → [artifact] → verifier(rubric) → [pass/fail + failure context]`

---

#### 4. Generate-and-Filter
Generate N candidates, filter by rubric, dedupe, return only the highest-quality verified set.

**When to use:**
- Brainstorming (30 names → verifier kills clichés/conflicts → you see 3)
- Hypothesis generation (5 approaches → score against constraints → winner has earned it)
- Any problem where "the best answer" suffers from premature commitment

**Key insight:** Asking for "the best answer" makes Claude commit early. Generate-and-filter commits late — after every option has been challenged.

**Shape:** `generator(N candidates) → filter(rubric) → dedup → top-K`

---

#### 5. Tournament (Pairwise Comparison)
Spawn N agents each attempting the same task differently, then judge results in pairwise fashion until one wins.

**When to use:**
- Sorting 1,000+ items where absolute scoring degrades
- Taste-based ranking (design choices, naming, UI options, candidate selection)
- Any domain where comparative judgment is more reliable than absolute scoring

**Why pairwise beats sort-by-score:** Sorting 1,000 items in one prompt fails on quality and context. A tournament splits the bracket across fresh agents, each comparing just two items. The bracket lives in deterministic loop code — not in context.

**Shape:** `N worker agents → pairwise comparison bracket → winner`

---

#### 6. Loop Until Done
For tasks with unknown scope, loop spawning agents until a stop condition is met instead of running a fixed number of passes.

**When to use:**
- Flaky test debugging (reproduce → theories → test until one holds)
- Bug hunting (keep finding bugs until a full pass returns zero)
- Pattern mining (cluster → identify rules → until no new clusters appear)

**Critical:** Pair with `/goal` to set a hard completion requirement. Without `/goal`, the workflow stops at the first soft completion point.

**Shape:**
```
loop:
  findings = agent(investigate_next_item)
  if stop_condition(findings): break
  accumulate(findings)
```

---

### Pattern Composition Matrix

Real workflows compose 2–4 patterns. Map failure mode → pattern combination:

| Use case | Primary patterns | Notes |
|---|---|---|
| Migrations / refactors | Fan-out → adversarial verification → loop until done | Anthropic's Bun Zig→Rust rewrite used this shape |
| Deep research | Fan-out (parallel searches) → adversarial verification (per claim) → synthesize | Each claim verified independently |
| Deep verification of a draft | Classify (find all claims) → fan-out (one verifier per claim) → meta-verifier | Checks verifier source quality too |
| Sorting 1,000+ items | Tournament | Pairwise comparison only — never absolute scoring |
| Root-cause investigation | Fan-out (disjoint evidence sources) → loop until done (theories survive) | Each agent reads logs/files/data independently |
| Triage at scale | Classify-and-act → generate-and-filter (dedupe) → loop | Pair with `/loop` for continuous triage |
| Exploration / taste | Generate-and-filter → tournament with rubric | Design choices, naming, UI options |
| Lightweight evals | Run candidate in worktree → comparison agents grade → refine + re-grade | Same as tournament but for grading, not ranking |

**Selection heuristic:**
- Goal drift? → fan-out
- Self-preference? → adversarial verification
- Open-ended / unknown scope? → loop until done
- Hard to score? → tournament

---

### Workflow Controls

**`/goal`** — sets a hard completion requirement. Without it, a workflow stops at the first soft completion. Use with loop patterns: "don't stop until one theory works."

**`/loop`** — runs the entire workflow on a recurring schedule. Use for continuous triage, weekly research updates, recurring verification.

**Token budget** — always specify explicitly: `"use 10k tokens"`. Without a cap, ambitious workflows balloon to 5–10× expected.

```
> ultracode quick adversarial review of this assumption:
  "moving to Postgres eliminates our shard rebalancing."
  Use 5k tokens. /goal don't stop until you have either
  a counterexample or three independent confirmations.
```

---

### Quarantine Pattern (Untrusted Input)

Any workflow processing untrusted content — support tickets, bug reports, user feedback, scraped data — must assume prompt injection risk.

**Rule:** Bar agents that read untrusted content from taking any high-privilege actions. Separate agents (with no exposure to raw content) do the acting.

**Applies to:** user-submitted content, scraped web pages, third-party API output.

**Cost:** ~30 lines for a read-only reader agent. Removes an entire class of prompt injection risk.

```
[untrusted input] → reader agent (read-only, no high-privilege tools)
                         ↓ structured summary only
                    actor agent (never sees raw input)
```

---

### Saving Workflows as Skills

1. When a workflow succeeds: press `s` in the workflow menu → saved to `~/.claude/workflows/`
2. To ship as a Skill: bundle the JS file inside a Skill folder, reference it in `SKILL.md`
3. **Template mode:** when packaging, tell Claude to treat the workflow as a template, not a verbatim script. This lets Claude adapt the shape to each task while preserving overall structure.

---

### Common Mistakes

| Mistake | Fix |
|---|---|
| Reaching for a workflow when regular session would do | Ask: does this task suffer from laziness, self-preference, or drift? If no → don't use workflow |
| No token budget | Always specify: `"use Xk tokens"` |
| One agent does both work and verification | Split — self-preferential bias makes the verifier favor the worker |
| Treating `parallel()` and `pipeline()` as interchangeable | `parallel` = barrier (wait all), `pipeline` = streaming (each item flows through) |
| Skipping `/goal` on loop patterns | Workflow stops at first soft completion without it |
| Untrusted content reaching the actor | Quarantine is not optional for user-submitted or scraped content |
| Sorting with absolute scores | Use tournament (pairwise comparison) |
| Never saving working workflows | Save with `s`, ship as a Skill |

---

### Contrarian Persona Ensemble

A review pattern for hardening output: convene several *named* review personas plus a set of *contrarian* personas, each assigned a specific loop pathology to counteract, and run them over multiple iterations at a long thinking budget.

Verbatim kickoff (Dan Luu):
> "use independent agents to review as linus torvalds, kyle kingsbury, marc brooker, tptacek, dan luu, and 4 contrarian personas. have each think for a long time."

Why it works: each persona guards a *named failure mode*. A "Torvalds" persona pushes back on complexity spirals; a "measure-first" persona forces evidence before conclusions; contrarian personas surface objections the primary reasoning suppressed. At **equal token / wall-clock budget**, the persona ensemble produces better output than an undifferentiated review pass.

Distinct from `#### 3. Adversarial Verification`: generic adversarial verification runs one skeptical checker against the worker. Here every reviewer owns a *distinct pathology it is responsible for catching*, so coverage is deliberate rather than emergent.

---

## Core Concepts

Multi-agent systems address single-agent context limitations through distribution. Three dominant patterns exist: supervisor/orchestrator for centralized control, peer-to-peer/swarm for flexible handoffs, and hierarchical for layered abstraction. The critical design principle is context isolation—sub-agents exist primarily to partition context rather than to simulate organizational roles.

Effective multi-agent systems require explicit coordination protocols, consensus mechanisms that avoid sycophancy, and careful attention to failure modes including bottlenecks, divergence, and error propagation.

## Detailed Topics

### Why Multi-Agent Architectures

**The Context Bottleneck**
Single agents face inherent ceilings in reasoning capability, context management, and tool coordination. As tasks grow more complex, context windows fill with accumulated history, retrieved documents, and tool outputs. Performance degrades according to predictable patterns: the lost-in-middle effect, attention scarcity, and context poisoning.

Multi-agent architectures address these limitations by partitioning work across multiple context windows. Each agent operates in a clean context focused on its subtask. Results aggregate at a coordination layer without any single context bearing the full burden.

**The Token Economics Reality**
Multi-agent systems consume significantly more tokens than single-agent approaches. Production data shows:

| Architecture | Token Multiplier | Use Case |
|--------------|------------------|----------|
| Single agent chat | 1× baseline | Simple queries |
| Single agent with tools | ~4× baseline | Tool-using tasks |
| Multi-agent system | ~15× baseline | Complex research/coordination |

Research on the BrowseComp evaluation found that three factors explain 95% of performance variance: token usage (80% of variance), number of tool calls, and model choice. This validates the multi-agent approach of distributing work across agents with separate context windows to add capacity for parallel reasoning.

Critically, upgrading to better models often provides larger performance gains than doubling token budgets. Claude Sonnet 4.5 showed larger gains than doubling tokens on earlier Sonnet versions. GPT-5.2's thinking mode similarly outperforms raw token increases. This suggests model selection and multi-agent architecture are complementary strategies.

**The Parallelization Argument**
Many tasks contain parallelizable subtasks that a single agent must execute sequentially. A research task might require searching multiple independent sources, analyzing different documents, or comparing competing approaches. A single agent processes these sequentially, accumulating context with each step.

Multi-agent architectures assign each subtask to a dedicated agent with a fresh context. All agents work simultaneously, then return results to a coordinator. The total real-world time approaches the duration of the longest subtask rather than the sum of all subtasks.

**The Specialization Argument**
Different tasks benefit from different agent configurations: different system prompts, different tool sets, different context structures. A general-purpose agent must carry all possible configurations in context. Specialized agents carry only what they need.

Multi-agent architectures enable specialization without combinatorial explosion. The coordinator routes to specialized agents; each agent operates with lean context optimized for its domain.

### Architectural Patterns

**Pattern 1: Supervisor/Orchestrator**
The supervisor pattern places a central agent in control, delegating to specialists and synthesizing results. The supervisor maintains global state and trajectory, decomposes user objectives into subtasks, and routes to appropriate workers.

```
User Query -> Supervisor -> [Specialist, Specialist, Specialist] -> Aggregation -> Final Output
```

When to use: Complex tasks with clear decomposition, tasks requiring coordination across domains, tasks where human oversight is important.

Advantages: Strict control over workflow, easier to implement human-in-the-loop interventions, ensures adherence to predefined plans.

Disadvantages: Supervisor context becomes bottleneck, supervisor failures cascade to all workers, "telephone game" problem where supervisors paraphrase sub-agent responses incorrectly.

**The Telephone Game Problem and Solution**
LangGraph benchmarks found supervisor architectures initially performed 50% worse than optimized versions due to the "telephone game" problem where supervisors paraphrase sub-agent responses incorrectly, losing fidelity.

The fix: implement a `forward_message` tool allowing sub-agents to pass responses directly to users:

```python
def forward_message(message: str, to_user: bool = True):
    """
    Forward sub-agent response directly to user without supervisor synthesis.
    
    Use when:
    - Sub-agent response is final and complete
    - Supervisor synthesis would lose important details
    - Response format must be preserved exactly
    """
    if to_user:
        return {"type": "direct_response", "content": message}
    return {"type": "supervisor_input", "content": message}
```

With this pattern, swarm architectures slightly outperform supervisors because sub-agents respond directly to users, eliminating translation errors.

Implementation note: Implement direct pass-through mechanisms allowing sub-agents to pass responses directly to users rather than through supervisor synthesis when appropriate.

**Pattern 2: Peer-to-Peer/Swarm**
The peer-to-peer pattern removes central control, allowing agents to communicate directly based on predefined protocols. Any agent can transfer control to any other through explicit handoff mechanisms.

```python
def transfer_to_agent_b():
    return agent_b  # Handoff via function return

agent_a = Agent(
    name="Agent A",
    functions=[transfer_to_agent_b]
)
```

When to use: Tasks requiring flexible exploration, tasks where rigid planning is counterproductive, tasks with emergent requirements that defy upfront decomposition.

Advantages: No single point of failure, scales effectively for breadth-first exploration, enables emergent problem-solving behaviors.

Disadvantages: Coordination complexity increases with agent count, risk of divergence without central state keeper, requires robust convergence constraints.

Implementation note: Define explicit handoff protocols with state passing. Ensure agents can communicate their context needs to receiving agents.

**Pattern 3: Hierarchical**
Hierarchical structures organize agents into layers of abstraction: strategic, planning, and execution layers. Strategy layer agents define goals and constraints; planning layer agents break goals into actionable plans; execution layer agents perform atomic tasks.

```
Strategy Layer (Goal Definition) -> Planning Layer (Task Decomposition) -> Execution Layer (Atomic Tasks)
```

When to use: Large-scale projects with clear hierarchical structure, enterprise workflows with management layers, tasks requiring both high-level planning and detailed execution.

Advantages: Mirrors organizational structures, clear separation of concerns, enables different context structures at different levels.

Disadvantages: Coordination overhead between layers, potential for misalignment between strategy and execution, complex error propagation.

### Functional Role Specialization

Beyond structural patterns (supervisor/swarm/hierarchical), assign agents to *functional roles* that describe what cognitive work they perform. These are orthogonal to structure: you can have a swarm of verification agents, or a supervisor whose workers specialize by function.

| Role | Function | Accountability |
|---|---|---|
| **Synthesis** | Generate new code/content from specifications | Produces artifacts meeting spec |
| **Understanding** | Analyze existing code/artifacts for structure and intent | Produces accurate representations |
| **Verification** | Check correctness, safety, compliance | Produces pass/fail signals with failure context |
| **Execution** | Run code in environments and surface results | Produces execution traces and state |
| **Planning** | Decompose goals into executable steps with success criteria | Produces plans as testable contracts |

**Design rule:** Each agent should have a single primary functional role. An agent that both synthesizes and verifies its own output reintroduces the single-agent bottleneck. When you find yourself writing "it writes code and then tests it", split those into synthesis and verification agents.

### Context Isolation as Design Principle

The primary purpose of multi-agent architectures is context isolation. Each sub-agent operates in a clean context window focused on its subtask without carrying accumulated context from other subtasks.

**Isolation Mechanisms**
Full context delegation: For complex tasks where the sub-agent needs complete understanding, the planner shares its entire context. The sub-agent has its own tools and instructions but receives full context for its decisions.

Instruction passing: For simple, well-defined subtasks, the planner creates instructions via function call. The sub-agent receives only the instructions needed for its specific task.

File system memory: For complex tasks requiring shared state, agents read and write to persistent storage. The file system serves as the coordination mechanism, avoiding context bloat from shared state passing.

**Isolation Trade-offs**
Full context delegation provides maximum capability but defeats the purpose of sub-agents. Instruction passing maintains isolation but limits sub-agent flexibility. File system memory enables shared state without context passing but introduces latency and consistency challenges.

The right choice depends on task complexity, coordination needs, and acceptable latency.

### Consensus and Coordination

**The Voting Problem**
Simple majority voting treats hallucinations from weak models as equal to reasoning from strong models. Without intervention, multi-agent discussions devolve into consensus on false premises due to inherent bias toward agreement.

**Weighted Voting**
Weight agent votes by confidence or expertise. Agents with higher confidence or domain expertise carry more weight in final decisions.

**Debate Protocols**
Debate protocols require agents to critique each other's outputs over multiple rounds. Adversarial critique often yields higher accuracy on complex reasoning than collaborative consensus.

**Trigger-Based Intervention**
Monitor multi-agent interactions for specific behavioral markers. Stall triggers activate when discussions make no progress. Sycophancy triggers detect when agents mimic each other's answers without unique reasoning.

**Adversarial Validation**
Assign a dedicated adversarial agent whose sole job is to find failures in peer-generated outputs — not to produce alternatives, just to break things. This is distinct from critique in debate protocols: the adversarial agent is not trying to reach consensus, it is trying to falsify. Use when correctness guarantees matter and the cost of shipping a wrong output is high.

```text
Synthesis Agent → [output] → Adversarial Agent → [failure report] → Synthesis Agent (repair)
                                    ↓ (no failures found)
                              Verification Agent → [pass/fail signal]
```

**Convergence Mechanisms Taxonomy**

Not all multi-agent convergence looks like voting. Six types, by what they converge on:

| Type | What converges | Signal used |
|---|---|---|
| **Correctness** | Shared test suite all agents pass | Test pass/fail |
| **Security** | Shared safety/constraint properties hold | Static analysis, constraint checks |
| **Performance** | Shared optimization target met | Benchmarks, profiling |
| **Score-based** | Objective function maximized | Reward signal |
| **Consensus** | Explicit agreement across agents | Voting, debate |
| **Implicit** | Emergent alignment without explicit protocol | Behavioral convergence |

Choose the type based on what property the system needs to guarantee. Correctness convergence (shared tests) is the most verifiable; implicit convergence is the least. For code-generating systems, prefer correctness or performance convergence over consensus — "all agents agree" is weaker than "all tests pass."

### Skill Routing Quality

When a multi-agent system dispatches work to specialized agents, the routing decisions themselves are a design surface. Four requirements distinguish auditable, reliable routing from ad-hoc dispatch:

| Requirement | Description | Failure if absent |
|---|---|---|
| **Specificity** | Each skill/agent has an explicit capability scope — what it handles AND what it refuses | Ambiguous dispatch: two agents both "could" handle a task, routing is arbitrary |
| **Selectivity** | Routing decisions are consistently correct — the right agent is invoked for the right task | Silent misroutes: wrong agent handles a task, produces a confident wrong result |
| **Composability** | Agent A's output format meets agent B's input contract — no implicit translation needed | Interface rot: orchestrator manually reformats every handoff, becomes the bottleneck |
| **Verifiability** | Post-condition checks run after execution, before downstream consumption | "Confident-but-unchecked" outputs: a specialized agent produces wrong output that looks correct |

**Post-condition coupling pattern.** Never let a routing decision be the last check. Couple each skill invocation to an explicit post-condition that runs before results flow downstream:

```text
Orchestrator → route(task) → Agent → [output] → verify(post_condition) → downstream
                                                         ↓ (fail)
                                              diagnose + replan or escalate
```

The post-condition can be lightweight: a schema check, an assertion, a test, or a confidence threshold. The key is that it is deterministic — not model self-assessment.

**Routing as a first-class audit trail.** Log routing decisions as events: which agent was selected, why, what the post-condition result was. This makes routing failures diagnosable after the fact, not just during live debugging.

### Framework Considerations

Different frameworks implement these patterns with different philosophies. LangGraph uses graph-based state machines with explicit nodes and edges. AutoGen uses conversational/event-driven patterns with GroupChat. CrewAI uses role-based process flows with hierarchical crew structures.

### Implementing Async Peer-to-Peer Agents (raw SDK)

Building a multi-agent app directly on the Anthropic SDK (no framework)? The plumbing reduces to a shared message **Hub** (per-agent inbox + `asyncio.Event`, event-driven not polled), two agent tools (`send_message` / `wait_for_message` as the *only* inter-agent channel), and a `spawn → status → collect → kill` lifecycle. Key trick: deliver peer messages by **appending them to the last tool result** so agents read mail inline in their tool-use loop — zero polling.

Full skeleton (Hub class, append-delivery, lifecycle, mitigations): see [references/async-sdk-orchestration.md](references/async-sdk-orchestration.md).

## Practical Guidance

### Failure Modes and Mitigations

**Failure: Supervisor Bottleneck**
The supervisor accumulates context from all workers, becoming susceptible to saturation and degradation.

Mitigation: Implement output schema constraints so workers return only distilled summaries. Use checkpointing to persist supervisor state without carrying full history.

**Failure: Coordination Overhead**
Agent communication consumes tokens and introduces latency. Complex coordination can negate parallelization benefits.

Mitigation: Minimize communication through clear handoff protocols. Batch results where possible. Use asynchronous communication patterns.

**Failure: Divergence**
Agents pursuing different goals without central coordination can drift from intended objectives.

Mitigation: Define clear objective boundaries for each agent. Implement convergence checks that verify progress toward shared goals. Use time-to-live limits on agent execution.

**Failure: Error Propagation**
Errors in one agent's output propagate to downstream agents that consume that output.

Mitigation: Validate agent outputs before passing to consumers. Implement retry logic with circuit breakers. Use idempotent operations where possible.

### Autonomy Anti-Patterns

Four ways multi-agent autonomy fakes progress instead of producing it (Addy Osmani). Watch for each:

- **Autonomy-as-status** — running agents to look advanced, not because the task needs them. Autonomy is a cost, not a trophy.
- **Permission laundering** — over-broad access granted through approval fatigue; each prompt looks reasonable, the accumulated grant is not.
- **Summary substitution** — trusting an agent's summary over the bundled evidence it summarizes. Read the artifact, not the abstract.
- **Fleet cosplay** — running parallel agents while *you* manually orchestrate their dependencies. That is hand-coordination in an orchestration costume, not real orchestration.

## Examples

**Example 1: Research Team Architecture**
```text
Supervisor
├── Researcher (web search, document retrieval)
├── Analyzer (data analysis, statistics)
├── Fact-checker (verification, validation)
└── Writer (report generation, formatting)
```

**Example 2: Handoff Protocol**
```python
def handle_customer_request(request):
    if request.type == "billing":
        return transfer_to(billing_agent)
    elif request.type == "technical":
        return transfer_to(technical_agent)
    elif request.type == "sales":
        return transfer_to(sales_agent)
    else:
        return handle_general(request)
```

## Guidelines

1. Design for context isolation as the primary benefit of multi-agent systems
2. Choose architecture pattern based on coordination needs, not organizational metaphor
3. Implement explicit handoff protocols with state passing
4. Use weighted voting or debate protocols for consensus
5. Monitor for supervisor bottlenecks and implement checkpointing
6. Validate outputs before passing between agents
7. Set time-to-live limits to prevent infinite loops
8. Test failure scenarios explicitly

## Integration

This skill builds on context-fundamentals and context-degradation. It connects to:

- `agent-execution-control` - Execution control patterns for long-horizon autonomous agents (Plan-Execute-Verify, gatekeeper, trace grounding)
- `para-memory-files` - Shared state management across agents (use relationship-first patterns; no standalone memory-systems skill exists)
- tool-design - Tool specialization per agent
- context-optimization - Context partitioning strategies
- progressive-complexity-ladder - Use before designing multi-agent systems; Levels 4–5 of the ladder introduce multi-agent patterns. Load this skill after scoping to the appropriate level.

## References

Internal reference:
- [Frameworks Reference](./references/frameworks.md) - Detailed framework implementation patterns

Related skills in this collection:
- context-fundamentals - Context basics
- `para-memory-files` - Cross-agent memory via PARA + relationship-first patterns
- context-optimization - Partitioning strategies
- agent-execution-control - Long-horizon execution control

External resources:
- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/) - Multi-agent patterns and state management
- [AutoGen Framework](https://microsoft.github.io/autogen/) - GroupChat and conversational patterns
- [CrewAI Documentation](https://docs.crewai.com/) - Hierarchical agent processes
- [Research on Multi-Agent Coordination](https://arxiv.org/abs/2308.00352) - Survey of multi-agent systems
- [Code as Agent Harness](https://arxiv.org/abs/2605.18747) - Ning et al. 2026; source for functional role taxonomy, convergence mechanisms, adversarial validation
- [Async Multi-Agent Orchestration (Anthropic Cookbook)](https://platform.claude.com/cookbook/patterns-agents-async-multi-agent-orchestration) - SDK Hub/inbox/Event skeleton, spawn→status→collect→kill lifecycle, append-to-tool-result delivery

---

## Orchestration Tax

Human attention is the GIL (Global Interpreter Lock) of a multi-agent system. Agents can all run at once, but any work requiring genuine architectural judgment must acquire the human lock — and there is exactly one of it.

**Amdahl's Law applied to agent orchestration:** The speedup from parallelizing agents is capped by the fraction of work that stays serial. In agent development, the serial fraction is the review step. Adding more agents grows the queue depth without increasing review throughput. The orchestration tax is the structural gap between agent production and what the human can actually merge.

### The Hidden Asymmetry

| Operation | Cost |
|---|---|
| Starting an agent | One keystroke |
| Closing the loop (review, merge, reconcile) | Minutes of focused attention |

Five agents is not 1× workload done five times. It is 5 cold context reloads, plus background cognition tracking which thread is failing. Trying harder doesn't fix a structural limit — it just shows up as shallow reviews or cognitive surrender (accepting agent output without forming an opinion).

### 5 Design Rules

**1. Scale fleet to review rate, not the UI.** Apply backpressure: agent count is the producer, your review rate is the consumer. The right number of parallel agents is how many you can code-review properly. For most developers this is a low single digit.

**2. Sort work into two piles.** 
- *Parallelizable*: isolated tasks where the output just needs a final gate (research, formatting, boilerplate generation) → delegate to background agents
- *Judgment-required*: architecture decisions, tricky bugs, complex tradeoffs → these do NOT parallelize; thrashing the lock makes every one worse

**3. Batch your reviews.** Context-switching is expensive — a full brain flush and cold reload. Reviewing 4 agents in one session beats checking one, leaving, and returning cold 4 times. Give agents a long leash; process the batch.

**4. Spend the lock only on judgment.** Let the machine self-verify the boring 80%: passing tests, screenshots, type checks, exit codes. Reserve your attention for the 20% that genuinely requires a human read.

**5. Protect serial time.** The bottleneck needs your best hours, not the leftover minutes between check-ins. Sometimes the highest-leverage move is to stop orchestrating entirely and think hard about one problem with the lock held. Orchestrating is overhead, not the work itself.

**Failure mode:** Twenty running agents feels like massive productivity. The dashboard is full. But that feeling is decoupled from shipping correct code. The orchestration tax left unpaid accumulates as cognitive debt (Margaret-Anne Storey): you merge things you didn't read, your mental model of the codebase goes stale, and it surfaces when production breaks.

**Source:** Google I/O 2026 panel (Seroter, Hammerly, Jaspan); Amdahl's Law framing applied to human-in-the-loop agent systems.

---

## Loop Health: Three Failure Modes That Worsen as Loops Improve

The harness daily loop (orchestrator → runners → observations spine) is already a loop in Cherny/Steipete's sense. Three failure modes become *sharper*, not easier, as the loop runs more reliably:

### 1. Cognitive Surrender — `[loop-debt]` signal
**Definition:** Accepting loop output without forming an opinion about it. The loop runs, skill updates get written, reports generate — and the human never reads them. Feels like productivity; is actually delegation of judgment.

**Harness detection:** `[loop-debt]` observation, written by stop-hook when `[skill-update]` entries are ≥3 days old with no `[session-charge]` since. Penalizes trust score (−1 per occurrence, max −2/day) via `trust_score.py auto-score`.

**Counter-move:** When you see `[loop-debt]`, read the skill update that triggered it. Take a position on whether it's correct before the next session.

### 2. Comprehension Debt — `keep-rate` proxy
**Definition:** The faster the loop ships code you didn't write, the bigger the gap between what the codebase contains and what you understand. Unlike cognitive surrender (you chose not to engage), comprehension debt is structural — it accumulates even when you're reading, just slower.

**Harness detection:** `[keep-rate]` observations track lines-added vs lines-still-in-HEAD per Claude-co-authored commit. Keep-rate < 80% is a leading indicator: code the loop shipped is being deleted, which usually means it didn't fit the engineer's mental model.

**Counter-move:** When keep-rate drops, don't increase review cadence — increase *comprehension* first. Understand the module before running the loop against it again.

### 3. Self-Preferential Maker — Step F adversarial check
**Definition:** The agent that wrote the skill update is too lenient grading its own output. `skill-augment-agent` (Step E of daily maintenance) is the maker; without a checker it grades its own homework.

**Harness detection:** Step F in the daily maintenance loop spawns a fresh verification agent with no loyalty to Step E's output. It checks: does the update address the gap? Does it contradict existing guidance? Flags failures as `[skill-update-flagged]`, confirms passes as `[skill-update-verified]`. Steps E and F use separate agent contexts by construction.

### Loop Health Signal Table

| Failure mode | Observation tag | Trust score effect | Counter-move |
|---|---|---|---|
| Cognitive surrender | `[loop-debt]` | −1 each, max −2/day | Read the flagged update; form an opinion |
| Comprehension debt | `[keep-rate]` < 80% | Existing penalty applies | Understand module before re-running loop |
| Self-preferential maker | `[skill-update-flagged]` | Informational only | Review flagged update manually |

**Source:** Loop Engineering (@bcherny / @steipete framing), 2026-06-11.

---

## Skill Metadata

**Created**: 2025-12-20
**Last Updated**: 2026-06-11
**Author**: Agent Skills for Context Engineering Contributors; enhanced with arXiv:2605.18747, arXiv:2605.26112, claude.com/blog dynamic-workflows, movez.substack.com dynamic-workflow-patterns article, loop-engineering article (@bcherny/@steipete)
**Version**: 1.5.0
