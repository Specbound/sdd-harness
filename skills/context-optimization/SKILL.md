---
name: context-optimization
description: This skill should be used when the user asks to "optimize context", "reduce token costs", "improve context efficiency", "implement KV-cache optimization", "partition context", or mentions context limits, observation masking, context budgeting, or extending effective context capacity.
---

# Context Optimization Techniques

Context optimization extends the effective capacity of limited context windows through strategic compression, masking, caching, and partitioning. The goal is not to magically increase context windows but to make better use of available capacity. Effective optimization can double or triple effective context capacity without requiring larger models or longer contexts.

## When to Activate

Activate this skill when:
- Context limits constrain task complexity
- Optimizing for cost reduction (fewer tokens = lower costs)
- Reducing latency for long conversations
- Implementing long-running agent systems
- Needing to handle larger documents or conversations
- Building production systems at scale

## Core Concepts

Context optimization extends effective capacity through four primary strategies: compaction (summarizing context near limits), observation masking (replacing verbose outputs with references), KV-cache optimization (reusing cached computations), and context partitioning (splitting work across isolated contexts).

The key insight is that context quality matters more than quantity. Optimization preserves signal while reducing noise. The art lies in selecting what to keep versus what to discard, and when to apply each technique.

## Detailed Topics

### Compaction Strategies

**What is Compaction**
Compaction is the practice of summarizing context contents when approaching limits, then reinitializing a new context window with the summary. This distills the contents of a context window in a high-fidelity manner, enabling the agent to continue with minimal performance degradation.

Compaction typically serves as the first lever in context optimization. The art lies in selecting what to keep versus what to discard.

**Compaction Implementation**
Compaction works by identifying sections that can be compressed, generating summaries that capture essential points, and replacing full content with summaries. Priority for compression goes to tool outputs (replace with summaries), old turns (summarize early conversation), retrieved docs (summarize if recent versions exist), and never compress system prompt.

**Summary Generation**
Effective summaries preserve different elements depending on message type:

Tool outputs: Preserve key findings, metrics, and conclusions. Remove verbose raw output.

Conversational turns: Preserve key decisions, commitments, and context shifts. Remove filler and back-and-forth.

Retrieved documents: Preserve key facts and claims. Remove supporting evidence and elaboration.

### Observation Masking

**The Observation Problem**
Tool outputs can comprise 80%+ of token usage in agent trajectories. Much of this is verbose output that has already served its purpose. Once an agent has used a tool output to make a decision, keeping the full output provides diminishing value while consuming significant context.

Observation masking replaces verbose tool outputs with compact references. The information remains accessible if needed but does not consume context continuously.

**Masking Strategy Selection**
Not all observations should be masked equally:

Never mask: Observations critical to current task, observations from the most recent turn, observations used in active reasoning.

Consider masking: Observations from 3+ turns ago, verbose outputs with key points extractable, observations whose purpose has been served.

Always mask: Repeated outputs, boilerplate headers/footers, outputs already summarized in conversation.

### KV-Cache Optimization

**Understanding KV-Cache**
The KV-cache stores Key and Value tensors computed during inference, growing linearly with sequence length. Caching the KV-cache across requests sharing identical prefixes avoids recomputation.

Prefix caching reuses KV blocks across requests with identical prefixes using hash-based block matching. This dramatically reduces cost and latency for requests with common prefixes like system prompts.

**Cache Optimization Patterns**
Optimize for caching by reordering context elements to maximize cache hits. Place stable elements first (system prompt, tool definitions), then frequently reused elements, then unique elements last.

Design prompts to maximize cache stability: avoid dynamic content like timestamps, use consistent formatting, keep structure stable across sessions.

### Context Partitioning

**Sub-Agent Partitioning**
The most aggressive form of context optimization is partitioning work across sub-agents with isolated contexts. Each sub-agent operates in a clean context focused on its subtask without carrying accumulated context from other subtasks.

This approach achieves separation of concerns—the detailed search context remains isolated within sub-agents while the coordinator focuses on synthesis and analysis.

**Result Aggregation**
Aggregate results from partitioned subtasks by validating all partitions completed, merging compatible results, and summarizing if still too large.

### Budget Management

**Context Budget Allocation**
Design explicit context budgets. Allocate tokens to categories: system prompt, tool definitions, retrieved docs, message history, and reserved buffer. Monitor usage against budget and trigger optimization when approaching limits.

**Trigger-Based Optimization**
Monitor signals for optimization triggers: token utilization above 80%, degradation indicators, and performance drops. Apply appropriate optimization techniques based on context composition.

## Practical Guidance

### Optimization Decision Framework

When to optimize:
- Context utilization exceeds 70%
- Response quality degrades as conversations extend
- Costs increase due to long contexts
- Latency increases with conversation length

What to apply:
- Tool outputs dominate: observation masking
- Retrieved documents dominate: summarization or partitioning
- Message history dominates: compaction with summarization
- Multiple components: combine strategies

### Performance Considerations

Compaction should achieve 50-70% token reduction with less than 5% quality degradation. Masking should achieve 60-80% reduction in masked observations. Cache optimization should achieve 70%+ hit rate for stable workloads.

Monitor and iterate on optimization strategies based on measured effectiveness.

## Examples

**Example 1: Compaction Trigger**
```python
if context_tokens / context_limit > 0.8:
    context = compact_context(context)
```

**Example 2: Observation Masking**
```python
if len(observation) > max_length:
    ref_id = store_observation(observation)
    return f"[Obs:{ref_id} elided. Key: {extract_key(observation)}]"
```

**Example 3: Cache-Friendly Ordering**
```python
# Stable content first
context = [system_prompt, tool_definitions]  # Cacheable
context += [reused_templates]  # Reusable
context += [unique_content]  # Unique
```

## Context Governance

Context optimization addresses *how* to reduce tokens. Context governance addresses *what to select and why*. Both are needed; governance precedes optimization.

**Treat context assembly as a selection policy, not a buffer fill.** The default failure mode is filling context until the limit triggers an optimization pass. Instead, build a selection policy that actively scores and filters candidates before any optimization is needed.

Four governance axes define a well-designed selection policy:

| Axis | Concern | Anti-pattern |
|---|---|---|
| **Relevance** | Semantic alignment to the current task — score each candidate, don't include by default | Adding all retrieved docs "in case they're useful" |
| **Compactness** | Minimize tokens without dropping critical signal — prefer summaries over raw output | Keeping full tool outputs after their purpose is served |
| **Traceability** | Every context item carries a source attribution (origin, timestamp, why included) — enables audit and failure analysis | Unmarked context where model can't distinguish retrieved facts from model-generated summaries |
| **Refresh Policy** | Stale content is updated or evicted; environment state is re-verified before high-stakes actions | Memory note referencing a function that was renamed two weeks ago |

**Staleness-aware retrieval ranking.** When pulling from memory or a knowledge store into context, rank candidates by:

```
rank_score = relevance_similarity
           - staleness_penalty × time_since_last_verification
           + confidence_weight
```

Higher staleness penalty for items that reference volatile state (code, APIs, config). Lower penalty for items that reference stable facts (architectural decisions, design principles).

**Provenance in practice.** Each context block should carry a lightweight header:
```
[Source: memory/hot-memory.md | Verified: 2026-05-30 | Relevance: current task]
```
This enables failure analysis ("the wrong context was included because…") and makes refresh decisions auditable.

## Two Independent Token Axes: Startup vs Runtime

Token cost splits into two independent levers that need different tools. Optimizing one
does nothing for the other.

| Axis | What it is | Reduced by | Measured by |
|---|---|---|---|
| **Runtime payload** | Variable per-turn cost: shell output, file reads, API context, tool observations | RTK (shell), lean-ctx (file reads), Headroom (API context), the techniques above | `rtk gain`, Headroom stats, `ctx_compress` |
| **Startup payload** | Fixed per-session tax paid *before you do anything*: layered `CLAUDE.md` + `@imports` + `.claude/rules/*` + auto-loaded `MEMORY.md` | Structuring what auto-loads; moving comprehensiveness to read-on-demand; pruning stale/ghost sections | `startup-payload-audit.sh` → dashboard **Context Health** tab |

#### Claude Code System Prompt Levers

Claude Code injects its own hidden startup payload before any user content: tool definitions, bundled skill catalogs, workflow engine descriptors. This is independent of your CLAUDE.md and cannot be reduced by RTK, lean-ctx, or compaction — those techniques never see it. Treat it as a separate tax with its own reduction controls.

**Step 1 — Measure first.** Run `/context` inside Claude Code to get the per-category token baseline. Note totals for Tools, Skills, and Workflows separately. Without a baseline, you cannot know which lever to pull.

**Step 2 — Investigate per-tool cost.** `/context` shows category totals, not per-tool breakdown. To see which individual tools are the largest offenders, set up a lightweight logging proxy (Node.js) that intercepts the Anthropic API request and emits a ranked table of tools by token size. Run one session through the proxy, read the table, identify the top 3 offenders.

**Step 3 — Apply the right lever.**

| Lever | `settings.json` key | Effect | When to use |
|---|---|---|---|
| Remove all bundled skills | `disableBundledSkills: true` | Removes entire Anthropic skill catalog | You use only custom skills; bundled ones are unused |
| Remove Workflow tool | `disableWorkflows: true` | Removes Workflow/multi-agent tool — typically the largest single item | Not using multi-agent workflows |
| Remove specific tool | `"permissions": {"deny": ["ToolName"]}` (bare name, not scoped) | Removes individual tool definition from payload entirely | Individual tool confirmed unused in your workflow |
| Remove specific bundled skill | `"skillOverrides": {"skill-name": "off"}` | Removes one bundled skill | Bundled skills partially useful — remove specific ones |
| Keep skill typeable but hidden | `"skillOverrides": {"skill-name": "user-invocable-only"}` | Skill is available when typed; hidden from autonomous reasoning | Want the skill available without burning startup tokens on every session |

**Step 4 — Verify.** Re-run `/context` after applying changes. Compare baseline to new totals. These are per-session savings that compound across every interaction.

**Key invariant:** RTK handles runtime payload; these levers handle startup payload. They are strictly independent axes. Optimizing one does nothing for the other, and you cannot compress your way out of a bloated startup payload using runtime techniques.

**The inversion principle (from claude-token-optimizer):** *comprehensiveness → archive
(read on demand); essentiality → startup payload.* Anything the agent needs only sometimes
should be a read-on-demand pointer, not auto-loaded prose. This is exactly the harness's own
"read on demand, not upfront" rule — the `startup-payload-audit` routine verifies the rule is
actually being followed by measuring the fixed payload, flagging over-budget growth, stale
files, and ghost references (referenced-but-missing paths).

You cannot compress your way out of a bloated startup payload — RTK and lean-ctx never see it.
Fix it by *structuring what loads*, then let the audit guard regressions.

### Claude Code Token-Economics Settings

Two settings-level levers with a directly measurable token payoff. Only verified items are listed here.

**MCP server `enabled` flag — toggle servers per session.** Each configured MCP server loads its full tool-schema block into context on every session: roughly **800–6,000 tokens** per server depending on tool count and description size. This is startup payload — it is paid before you do anything, and RTK/lean-ctx never see it. Keep servers you use rarely *configured but disabled* (`"enabled": false`) and flip them on only for the sessions that need them, rather than loading every server's schemas into every session. This is the MCP-specific case of the inversion principle above: essential → loaded; occasional → available-but-not-auto-loaded.

**Prompt-caching breakpoint placement — after the stable prefix.** Place `cache_control` breakpoints after the **stable prefix** (system prompt / stable context), never after the volatile user message — a breakpoint on content that changes every request guarantees a cache miss and wastes a lookback slot. For prefixes that stay byte-identical across a session, `"ttl": "1h"` keeps the entry alive across idle gaps longer than the default 5-minute TTL. **Economics:** cache reads cost ~10% of base input price; cache **writes** cost ~25% more than base (the default 5-minute TTL) — at that write premium a breakpoint pays for itself at **2+ reads** within its TTL.

> **Cross-check note (claude-api skill).** The "~25% write premium / 2-read break-even" figure above is specifically the **default 5-minute** TTL. The claude-api skill's caching guidance states that `"ttl": "1h"` writes cost **~2× base (≈100% more)**, not 25%, and therefore need **3+ reads** to break even — the 1-hour TTL is for surviving gaps in bursty traffic, not for hitting break-even sooner. Encoded here per that source rather than the flatter "2 reads pays off regardless of TTL" phrasing, which would contradict it. The breakpoint-placement rule and the ~10% read cost match the claude-api skill exactly.

> **Deliberately excluded.** Other "hidden settings" claims from the same source (e.g. an `inference_geo` control and data-residency pricing premiums) were **not verified** and are intentionally omitted. This section is documentation guidance only — it does not prescribe editing any `settings.json`.

## Anthropic API Prompt Caching

Server-side prefix caching for Anthropic API calls. This is a **third, orthogonal mechanism** to CAG (local KV cache preloading for HuggingFace models) and the KV-cache ordering heuristics above. All three reduce inference cost via caching, but operate at completely different layers.

**Mechanism:** Add `cache_control: {"type": "ephemeral"}` blocks at stable prefix boundaries. Anthropic's servers cache the KV state up to that point and reuse it on subsequent requests with the same prefix. Billed at 10% of normal input token rate on cache hits.

Source: Anthropic API documentation, platform.claude.com/docs/en/docs/build-with-claude/prompt-caching

### Minimum Token Thresholds (cache is a no-op below these)

| Model family | Minimum cacheable tokens |
|---|---|
| Claude Opus 4.8, Sonnet 5 | 1,024 tokens |
| Claude Opus 4.6/4.5, Haiku 3.5 | 4,096 tokens |
| Claude Fable/Mythos variants | 512 tokens |

If your stable prefix is under threshold, adding `cache_control` has zero effect and wastes tokens on the metadata.

### Breakpoint Placement Rules

**Automatic mode** (recommended for multi-turn conversations): Claude Code and the API manage breakpoints automatically. No `cache_control` needed. Use for chat-style agents where the conversation history is the stable prefix.

**Explicit mode** (recommended for multi-section prompts): Place `cache_control` at stable section boundaries:
1. System prompt boundary (after system message)
2. After tool definitions block (if tools are stable across requests)
3. After a large stable documents/examples block
4. Before the variable user message

**Ordering rule:** Place `cache_control` markers at the last stable token before content that changes. Everything before the marker is cached; everything after is re-encoded.

### The Lookback Window Gotcha

The API checks the last **20 `cache_control` blocks** to find a cache hit. If you place a breakpoint on frequently-changing content (e.g., a timestamp, session ID, or rotating examples), that breakpoint consumes a lookback slot and guarantees a miss — re-billing at full price.

**Anti-pattern:** Adding `cache_control` after content that changes every request defeats the purpose and wastes the lookback budget.

### Cache Invalidation Dependency Table

Changes are not independent — they cascade:

| What changed | What gets invalidated |
|---|---|
| Tool definitions | System prompt cache + all message caches |
| Tool choice only | Message caches only (system cache survives) |
| System prompt | All message caches |
| User message content | Only that message's cache and subsequent messages |

This is asymmetric and not guessable. Tool definition changes are the most expensive — they cascade to everything below them.

### Pre-Warming Pattern

Send a synthetic request with `max_tokens: 0` before latency-sensitive traffic starts. This forces the server to compute and cache the KV state for your stable prefix without generating any output tokens.

```python
# Warm the cache for 100ms, then serve real requests at cached latency
client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=0,          # No generation — pure cache warming
    system=[{
        "type": "text",
        "text": STABLE_SYSTEM_PROMPT,
        "cache_control": {"type": "ephemeral"}
    }],
    messages=[{"role": "user", "content": "warm"}]
)
```

Use before: batch processing jobs, request spikes, first request of a new server instance.

### Cache TTL

Default TTL is 5 minutes. Extended TTL (1 hour) is available on request. Design retry logic and session handling around the 5-minute default — a cache miss after TTL expiry costs the same as a cold request.

### Usage Monitoring

The API response includes `cache_creation_input_tokens` and `cache_read_input_tokens` in the usage block. Track these to measure cache hit rate and verify placement is working. A low `cache_read_input_tokens` ratio with high `cache_creation_input_tokens` indicates misplaced breakpoints or content too dynamic to cache.

---

## Guidelines

1. Measure before optimizing—know your current state
2. Apply compaction before masking when possible
3. Design for cache stability with consistent prompts
4. Partition before context becomes problematic
5. Monitor optimization effectiveness over time
6. Balance token savings against quality preservation
7. Test optimization at production scale
8. Implement graceful degradation for edge cases

## Integration

This skill builds on context-fundamentals and context-degradation. It connects to:

- multi-agent-patterns - Partitioning as isolation
- evaluation - Measuring optimization effectiveness
- memory-systems - Offloading context to memory

## References

Internal reference:
- [Optimization Techniques Reference](./references/optimization_techniques.md) - Detailed technical reference

Related skills in this collection:
- context-fundamentals - Context basics
- context-degradation - Understanding when to optimize
- evaluation - Measuring optimization

External resources:
- Research on context window limitations
- KV-cache optimization techniques
- Production engineering guides

---

## Skill Metadata

**Created**: 2025-12-20
**Last Updated**: 2026-07-08
**Author**: Agent Skills for Context Engineering Contributors; enhanced with arXiv:2605.26112
**Version**: 1.3.0
**Sources added**: Anthropic API Prompt Caching documentation (server-side prefix caching mechanics, breakpoint rules, invalidation table); Agent Cookbook Claude Code token-economics settings (MCP `enabled` flag + breakpoint placement — only the two verified items; unverified "hidden settings" claims excluded)
