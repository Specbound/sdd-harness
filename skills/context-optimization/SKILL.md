---
name: context-optimization
description: "Use when designing, debugging, or cutting cost in context-constrained agent systems — covers context anatomy, degradation patterns, compression/compaction strategies, caching economics, and governance for what enters context."
---

# Context Optimization

Context is the complete state available to a model at inference: system prompt, tool
definitions, retrieved docs, message history, tool outputs. It is a finite resource with
diminishing returns — the goal is the smallest high-signal token set, not the largest window
filled. Tool outputs alone can reach 83.9% of tokens in a typical agent trajectory.

## Anatomy of Context

| Component | Notes |
|---|---|
| System prompt | Loaded once, persists all session. Right altitude: specific enough to guide, adjustable enough not to be brittle. |
| Tool definitions | Near front of context. If a human can't say which tool applies, neither can the agent — fix descriptions, not the model. |
| Retrieved docs | Just-in-time: keep lightweight pointers (paths, queries), load content on demand, not pre-loaded. |
| Message history | Scratchpad memory — tracks task state/reasoning across turns; dominates token usage in long tasks. |
| Tool outputs | Majority of tokens in typical trajectories (83.9%). Served their purpose fast — mask or drop after the decision they informed. |

**Progressive disclosure**: load only names/descriptions at startup; full content on activation. Applies to skills, docs, and tool results alike.

**Placement**: attention is U-shaped — beginning and end are reliable, middle is not (10-40% lower recall for mid-context info). Put critical facts at the edges.

## Degradation Patterns (diagnose, then pick a fix)

| Pattern | Symptom | Fix |
|---|---|---|
| Lost-in-middle | Info buried mid-context not recalled | Move critical facts to start/end; resurface key findings at the end of summaries |
| Poisoning | Hallucination/error compounds via repeated reference | Truncate to before the poison point, or restart with verified-only content |
| Distraction | Model over-weights provided info over training knowledge; even 1 irrelevant doc hurts | Relevance-filter before loading; prefer tool calls over pre-loading |
| Confusion | Irrelevant/mismatched context shapes wrong tool calls or answers | Segment tasks into separate context windows; clear transitions |
| Clash | Multiple correct-but-contradictory facts coexist | Priority rules, version filtering, explicit conflict marking |

**RULER benchmark**: only ~50% of models claiming 32K+ context hold quality at 32K.

| Model | Onset | Severe | Notes |
|---|---|---|---|
| GPT-5.2 | ~64K | ~200K | best degradation resistance w/ thinking mode |
| Claude Opus 4.5 | ~100K | ~180K | 200K window |
| Claude Sonnet 4.5 | ~80K | ~150K | agent/coding-tuned |
| Gemini 3 Pro | ~500K | ~800K | 1M window |
| Gemini 3 Flash | ~300K | ~600K | 3x speed vs prior gen |

**Four-bucket mitigation**: Write (externalize to scratchpad/file), Select (retrieve/filter relevant), Compress (summarize/mask), Isolate (sub-agent/session split — most aggressive, often most effective).

## Compression

**Judge changes by tokens-per-task, not tokens-per-request** — a strategy that saves 0.5% more tokens but forces 20% more re-fetching costs more overall.

Measured at an identical ~1,800-token budget (SKILL.state, arXiv:2608.26263, Table 5, 100-step task):

| Strategy | Accuracy |
|---|---|
| Sliding-window truncation | 0.18 |
| LLMLingua (entropy-based) | 0.22 |
| Summary-capped history | 0.52 |
| Structured state object | 0.94 |
| *(unbounded full history, reference)* | 0.84 |

Structure beat unbounded history. LLMLingua failed because entropy-based pruning drops low-information-*looking* but relationally load-bearing tokens (IDs, keys, field names) — exactly what later steps join on. **Rule**: before compressing a span, ask if it's relationally dense; if yes, restructure into a compact explicit form instead of summarizing.

**Artifact trail is the weakest dimension** across all compression methods (2.2-2.5/5.0) — file-create/modify/read tracking degrades even with structured summaries. Treat it as needing a separate index, not general summarization.

Structured summary sections (forces preservation — each must be explicitly populated):
```
## Session Intent / ## Files Modified / ## Decisions Made / ## Current State / ## Next Steps
```

| Compression method | Ratio | Quality | Trade-off |
|---|---|---|---|
| Anchored iterative (merge new into existing sections) | 98.6% | 3.70 | best quality |
| Regenerative (full re-summary each time) | 98.7% | 3.44 | moderate |
| Opaque (max density, uninterpretable) | 99.3% | 3.35 | quality loss |

**Trigger**: 70-80% utilization, or at workflow-phase boundaries (coherent state, nothing in-flight) — never mid-turn, which risks truncating a partial reasoning chain.

**Evaluate with probes, not ROUGE/embedding similarity** — ask post-compression questions (recall, artifact, continuation, decision) and check whether the agent answers correctly or guesses.

## Observation Masking

Never mask: current-task-critical, most-recent-turn, or actively-reasoned-over observations.
Mask: 3+ turns old, already-summarized, repeated/boilerplate outputs.
```python
if len(observation) > max_length:
    ref_id = store_observation(observation)
    return f"[Obs:{ref_id} elided. Key: {extract_key(observation)}]"
```

## Context Governance

Optimization is *how* to reduce tokens; governance is *what to select and why* — governance comes first. Score and filter candidates before they enter context, don't fill-then-trim.

| Axis | Concern | Anti-pattern |
|---|---|---|
| Relevance | Score each candidate, don't include by default | Adding all retrieved docs "in case" |
| Compactness | Prefer summaries over raw output | Keeping full tool output after its purpose is served |
| Traceability | Source attribution per block (origin, timestamp, why) | Can't tell retrieved fact from model-generated summary |
| Refresh | Re-verify before high-stakes use; evict stale | Memory note citing a function renamed weeks ago |

Staleness-aware ranking: `rank_score = relevance_similarity - staleness_penalty × time_since_verification + confidence_weight`. Higher penalty for volatile state (code/APIs/config); lower for stable facts (decisions, principles).

## Partitioning / Isolation

Split work across sub-agents with clean, isolated contexts — the most aggressive optimization, separating concerns so the coordinator only handles synthesis. See `dispatching-parallel-agents` and `multi-agent-patterns` for mechanics; aggregate by validating all partitions completed, merging compatible results, summarizing if still too large.

## Two Independent Token Axes: Startup vs Runtime

Fixing one does nothing for the other — they need different tools.

| Axis | What it is | Reduced by | Measured by |
|---|---|---|---|
| Runtime payload | Per-turn: shell output, file reads, API context, tool observations | RTK, lean-ctx, Headroom, techniques above | `rtk gain`, Headroom stats, `ctx_compress` |
| Startup payload | Fixed per-session tax: CLAUDE.md + @imports + rules + auto-loaded MEMORY.md, plus Claude Code's own hidden tool/skill/workflow schemas | Structuring what auto-loads; read-on-demand; pruning stale sections | `startup-payload-audit.sh` → dashboard Context Health |

**Claude Code startup levers** (`/context` to baseline first):

| Lever | `settings.json` key | Effect |
|---|---|---|
| Drop bundled skills | `disableBundledSkills: true` | removes Anthropic skill catalog |
| Drop Workflow tool | `disableWorkflows: true` | removes multi-agent tool, often largest item |
| Drop one tool | `"permissions": {"deny": ["ToolName"]}` | removes that tool's definition |
| Drop one bundled skill | `"skillOverrides": {"skill-name": "off"}` | removes it |
| Hide but keep typeable | `"skillOverrides": {"skill-name": "user-invocable-only"}` | available on type, not auto-loaded |

MCP servers cost ~800-6,000 tokens each in startup payload — set `"enabled": false` on ones used rarely, flip on per-session rather than loading every schema always.

## Anthropic API Prompt Caching

Server-side prefix cache: `cache_control: {"type": "ephemeral"}` at stable boundaries. Hits bill at ~10% of input price.

Minimum cacheable tokens: Opus 4.8/Sonnet 5 → 1,024; Opus 4.6/4.5, Haiku 3.5 → 4,096; Fable/Mythos → 512. Below threshold, `cache_control` is a no-op.

Breakpoints: after system prompt, after stable tool-defs, after a large stable doc block, before the variable user message — place at the **last stable token** before content changes. The API only checks the last **20 cache_control blocks** for a hit; a breakpoint on frequently-changing content (timestamp, session id) wastes a lookback slot and guarantees a miss.

Invalidation cascades, not independent:

| Changed | Invalidates |
|---|---|
| Tool definitions | system cache + all message caches |
| Tool choice only | message caches only |
| System prompt | all message caches |
| User message content | that message's cache + subsequent |

TTL: 5 min default (~25% write premium, break-even at 2+ reads); `"ttl": "1h"` (~2x write cost, break-even at 3+ reads) for surviving bursty-traffic gaps. Claude Code subscriptions get 1h cache automatically; API key/credits get 5 min.

Pre-warm with a `max_tokens: 0` request before latency-sensitive traffic to force KV computation without generating output.

Monitor `cache_creation_input_tokens` / `cache_read_input_tokens` in usage — high creation with low read ratio means misplaced breakpoints or content too dynamic to cache.

## Guidelines

1. Measure before changing anything — baseline with `/context`, know current state
2. Governance before compression — filter what enters before compressing what's there
3. Compaction before masking; mask before partitioning
4. Judge changes by tokens-per-task, not tokens-per-request
5. Trigger compaction at 70-80% utilization or clean phase boundaries, never mid-turn
6. Never strip file paths, error messages, or relationally-dense identifiers when compressing
7. Verify with probes (recall/artifact/continuation/decision), not ROUGE or embedding similarity
8. Startup and runtime payload are independent — fix each with its own lever

## Integration

Builds on the context-anatomy and degradation material above. Connects to `agent-memory-systems` for offloading context to durable memory, `dispatching-parallel-agents` and `multi-agent-patterns` for partitioning/isolation, and `context-management-context-restore` for what to capture before a compaction event actually fires.
