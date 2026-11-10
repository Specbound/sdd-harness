---
name: multi-agent-patterns
description: "Activate when designing multi-agent systems, implementing supervisor/swarm/hierarchical patterns, coordinating subagents, choosing a workflow pattern, or scoping agent permissions/autonomy. Also activate for ultracode, dynamic workflows, or avoiding agentic laziness / self-preferential bias / goal drift."
---

# Multi-Agent Architecture Patterns

Sub-agents exist primarily to isolate context, not to anthropomorphize role division. Multi-agent systems cost ~15x baseline tokens vs. a single-agent chat (~4x for single-agent-with-tools) — justify the cost before reaching for it. On BrowseComp, token usage alone explains 80% of performance variance; upgrading model choice often beats doubling token budget, so treat model selection and architecture as complementary, not either/or.

## Tool Selection: Agent vs. Workflow

| | `Agent` tool | `Workflow` tool |
|---|---|---|
| Orchestration | Ad-hoc, model-driven | Deterministic JS script |
| Scale | 2–10 parallel subagents | Tens to hundreds |
| Control flow | Model decides what to spawn next | `pipeline()` / `parallel()` / `phase()` |
| Resume | No | Yes — persists across interruptions |
| Best for | Independent investigations, targeted fixes | Service-wide audits, multi-hundred-file migrations |

**Decision:** 2–10 well-defined independent subtasks → `Agent` tool (see `dispatching-parallel-agents`). Tens-to-hundreds of units, or "audit/migrate everything matching X" → `Workflow` tool. Start scoped (one subsystem), measure token cost, then widen — never start with "audit everything."

`parallel()` is a barrier (waits for all); `pipeline()` streams each item through every stage independently. Need all results before the next step? `parallel`. Otherwise `pipeline` (cheaper, faster). Always set an explicit token budget (`"use 10k tokens"`) — uncapped workflows balloon 5–10x.

## Dynamic Workflow Patterns

Reach for a workflow only when a task shows one of these three failure modes; otherwise a regular session is faster and cheaper:

| Failure mode | Symptom | Fix |
|---|---|---|
| Agentic laziness | Stops at partial progress, declares done | Fan-out-and-synthesize — one agent per item |
| Self-preferential bias | Agent verifying its own output favors it | Adversarial verification — separate context, no shared history |
| Goal drift | Constraints vanish after compaction | Fan-out — each agent carries only its scoped goal |

**The 6 patterns:**

| # | Pattern | Shape | Use when |
|---|---|---|---|
| 1 | Classify-and-act | classifier → route → specialist(s) | Heterogeneous tasks; route cheap model to easy cases, expensive to hard |
| 2 | Fan-out-and-synthesize | `parallel(workers)` → synthesizer merges | Enumerable independent items, one final answer needed |
| 3 | Adversarial verification | worker → artifact → verifier(rubric, blind to authorship) | Claim-checking, code review, pre-ship gates |
| 4 | Generate-and-filter | generate(N) → filter(rubric) → dedup → top-K | Brainstorming, hypothesis generation — commit late, not early |
| 5 | Tournament | N workers → pairwise bracket → winner | Sorting 1,000+ items; taste-based ranking where absolute scoring fails |
| 6 | Loop until done | loop: agent → check stop_condition → accumulate | Unknown scope (flaky-test debugging, bug hunting); pair with `/goal` or it stops at first soft completion |

**Composition** (real workflows chain 2–4 patterns): migrations = fan-out → adversarial verification → loop; deep research = fan-out → adversarial verification (per claim) → synthesize; sorting 1,000+ items = tournament only, never absolute scoring. Selection heuristic: goal drift→fan-out, self-preference→adversarial, open scope→loop, hard-to-score→tournament.

**Quarantine pattern (untrusted input):** any workflow touching support tickets, scraped data, or user-submitted content must assume prompt injection. A read-only reader agent (no high-privilege tools) produces a structured summary; a separate actor agent never sees the raw input. ~30 lines removes an entire risk class.

**Common mistakes:** no token budget set · one agent does both work and verification (self-preference) · treating `parallel`/`pipeline` as interchangeable · skipping `/goal` on loop patterns · sorting by absolute score instead of tournament · letting untrusted content reach the actor agent.

## Hardening Review Output

**Contrarian persona ensemble:** convene named review personas plus contrarians, each assigned a distinct failure mode to guard, at a long thinking budget (e.g. "review as Linus Torvalds, + 4 contrarian personas, each thinks for a long time"). Unlike generic adversarial verification (one skeptical checker), each reviewer here owns a *specific pathology* — coverage is deliberate, not emergent.

**Redundant signal check:** before stacking a new review pass, verify it isn't empirically redundant with one already in place (Coinbase found 84% correlation between two "different" interview rounds). Fix is merging the redundant pass, not adding a third. Rule: a new pass must replace or catch something distinct — never just stack.

## Architectural Patterns

| Pattern | Shape | Best for | Known failure |
|---|---|---|---|
| Supervisor | supervisor → [specialists] → aggregate | Clear decomposition, human-in-the-loop needed | Context bottleneck; "telephone game" — supervisor paraphrases sub-agent output, losing fidelity (LangGraph: 50% worse before fix) |
| Swarm (peer-to-peer) | agents hand off via explicit transfer | Open-ended exploration, emergent requirements | Coordination complexity scales with agent count; needs convergence constraints |
| Hierarchical | strategy → planning → execution layers | Large projects mirroring org structure | Coordination overhead between layers; misalignment risk |

**Telephone-game fix:** give sub-agents a `forward_message(message, to_user=True)` tool so final/complete responses bypass supervisor synthesis entirely. With this, swarms slightly outperform supervisors because translation errors disappear.

**Functional role specialization** (orthogonal to the structural pattern above — any pattern can assign these): Synthesis (generate from spec), Understanding (analyze existing artifacts), Verification (pass/fail + failure context), Execution (run + report traces), Planning (decompose into testable contracts). One primary role per agent — an agent that both writes and tests its own output reintroduces the single-agent bottleneck.

**Context isolation mechanisms**, by how much the sub-agent needs: full context delegation (max capability, defeats isolation purpose), instruction passing (isolated, more rigid), file-system memory (shared state without context bloat, adds latency/consistency concerns). Pick by task complexity and acceptable latency, not by default.

## Consensus & Coordination

Unmoderated multi-agent discussion tends toward agreement on false premises (sycophancy bias), not correctness. Options: weighted voting (by confidence/expertise), debate protocols (multi-round critique — more accurate than collaborative consensus on hard reasoning), trigger-based intervention (stall/sycophancy detectors), dedicated adversarial agent (falsify only, not propose alternatives).

**Convergence taxonomy** — pick the type the system actually needs to guarantee:

| Type | Converges on | Signal |
|---|---|---|
| Correctness | Shared test suite passes | Test pass/fail |
| Security | Safety/constraint properties hold | Static analysis |
| Performance | Optimization target met | Benchmarks |
| Score-based | Objective function maximized | Reward signal |
| Consensus | Explicit agreement | Voting, debate |
| Implicit | Emergent alignment | Behavioral |

For code-generating systems prefer correctness/performance convergence — "all agents agree" is weaker than "all tests pass."

## Skill Routing Quality

Four requirements for auditable dispatch: **specificity** (explicit scope — what it handles AND refuses), **selectivity** (consistently correct routing), **composability** (output of A meets input contract of B, no manual reformatting), **verifiability** (deterministic post-condition check runs before downstream consumption — not model self-assessment).

Scale the verification gate to blast radius, not nesting depth: a leaf feeding one consumer tolerates a light check; a node that fans out to many consumers (a plan several executors follow) needs a dedicated verifier, schema-constrained output, or human approval before it propagates further. Log routing decisions (agent selected, why, post-condition result) as an audit trail. Curated rosters show diminishing returns past ~10 behaviorally-distinct agents; prefer rule-based routers over learned/similarity routers when robustness to task rephrasing matters more than peak accuracy (arXiv:2607.09197).

## Permissions & Scope

Authorization is architecture, not an afterthought — settle this before finalizing tools: **who** can authorize the agent (actual scope in the system of record), **what subset** it actually needs (least privilege), **where** permission authority lives (system of record, never agent-side config), **how** irreversible actions get a separate verification pass. For regulated domains (HR, finance, legal), do this before finalizing tools — permission errors compound silently across interconnected systems.

Enforce with a 4-level gate, assessed per call, not just per tool:

| Level | Meaning | Example tools |
|---|---|---|
| `AUTO` | No approval needed | read_file, list_directory, search_code |
| `ASK_ONCE` | Approve first use, remember for session | write_file, edit_file |
| `ASK_EACH` | Approve every call | run_command, delete_file |
| `NEVER` | Hard block | sudo_command, format_disk |

Risk-assess the actual arguments, not just the tool name — e.g. flag `run_command` as HIGH when the command string contains `rm -rf`, `sudo`, or `chmod`, MEDIUM otherwise. Pair with sandboxing: restrict writes to a workspace root (resolve symlinks before checking), allowlist executable commands rather than blocklisting.

## Autonomy Reliability

A 95%-per-step success rate compounds to ~60% by step 10 — autonomy is earned through proven reliability on a narrow task, not granted upfront. Start heavily constrained; widen scope only after the narrow version holds up. Guardrails and logging precede added capability, not the reverse.

**Four anti-patterns that fake progress** (Addy Osmani): **autonomy-as-status** (running agents to look advanced, not because the task needs them — autonomy is a cost, not a trophy), **permission laundering** (over-broad access granted through approval fatigue — each prompt looks reasonable, the accumulated grant isn't), **summary substitution** (trusting an agent's summary over the evidence it summarizes), **fleet cosplay** (running parallel agents while a human manually hand-coordinates their dependencies — that's not real orchestration).

## Async Peer-to-Peer on the Raw SDK

Building directly on the Anthropic SDK with no framework: a shared message Hub (per-agent inbox + `asyncio.Event`, event-driven not polled), two agent tools (`send_message`/`wait_for_message` as the only inter-agent channel), and a `spawn → status → collect → kill` lifecycle. Deliver peer messages by appending to the last tool result so agents read mail inline — zero polling. Full skeleton: `references/async-sdk-orchestration.md`.

When a coordinator spawns nested sub-coordinators (not just flat workers), cap iterations/depth/children/cost/time at spawn time — a circuit breaker against runaway recursive delegation.

## Orchestration Tax

Human review is the serial bottleneck (Amdahl's Law) — agent count is the producer, review rate is the consumer, and there's exactly one reviewer. Five parallel agents is not 1x work done five times; it's five cold-context reloads plus background tracking of which thread is failing.

1. **Scale fleet to review rate**, not to how many the UI can launch — usually a low single digit per human.
2. **Sort work**: parallelizable (isolated, final-gate-only — research, formatting) delegates freely; judgment-required (architecture, tricky bugs) does not parallelize.
3. **Batch reviews** — a cold context-switch costs more than a long leash followed by one batched pass.
4. **Spend review attention on judgment only** — let tests/type-checks/exit codes self-verify the boring 80%.
5. **Protect serial thinking time** — sometimes the most valuable move is to stop orchestrating and hold the lock on one problem.

Failure mode: a full dashboard of running agents feels productive but is decoupled from shipping correct code — unpaid orchestration tax surfaces later as stale mental models and production breaks.

## Failure Modes and Mitigations

| Failure | Cause | Mitigation |
|---|---|---|
| Supervisor bottleneck | Accumulates all worker context | Output schema constraints (distilled summaries only); checkpoint instead of carrying full history |
| Coordination overhead | Inter-agent communication costs tokens + latency | Minimize handoffs; batch results; async communication |
| Divergence | Agents drift without central coordination | Clear per-agent objective boundaries; convergence checks; TTL limits |
| Error propagation | One agent's bad output feeds downstream | Validate outputs before passing on; retries with circuit breakers; idempotent ops |

## Integration

Connects to `dispatching-parallel-agents` for the Agent-tool invocation mechanics, `context-optimization` for context partitioning as the isolation primitive, and `agent-memory-systems` for cross-agent shared state via files rather than context-passing.
