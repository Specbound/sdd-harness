---
name: agent-memory-systems
description: "Use when designing or debugging agent memory: choosing a memory tier/type, scoring or ranking retrieved memories, picking file vs. structured (vector/graph) storage, or avoiding cross-session/cross-user memory failures."
---

# Agent Memory Systems

Memory failures look like intelligence failures. When an agent "forgets" or gives inconsistent answers, it's almost always a **retrieval** problem, not a storage problem — good memory architecture is 20% storage, 80% retrieval design.

## The Three Tiers

Every memory system lives in exactly one tier. The cognitive-science split (semantic/episodic/procedural) describes *what kind* of information is stored; tiers describe *where it lives* — most "memory" discussions conflate the two.

| Tier | What it is | Survives session? | Production in 2026? |
|---|---|---|---|
| **Working memory** | Context window | No — resets on session end | Always (it's the window) |
| **External memory** | Files, vector stores, KGs | Yes — persisted outside weights | All production systems |
| **Parametric memory** | Knowledge in weights via training | Yes — permanent | Zero production deployments |

**The Memo Ceiling** (arXiv:2604.27707): retrieval from external memory needs Ω(k²) stored examples to match what parametric memory achieves with O(d) weight updates. More retrieval sophistication helps but doesn't close the gap — external memory is good for *episodic* recall (what happened, what was decided), not a substitute for trained generalization of *procedural* knowledge.

## Memory Layers (within external memory)

| Layer | Persists | Use for |
|---|---|---|
| Short-term | Current session only | Conversation state, tool-call intermediates, task checklists |
| Long-term | Cross-session | User preferences, reusable patterns, growing domain knowledge |
| Entity | Cross-session | Identity/property/relationship consistency for named entities |
| Temporal (KG) | Cross-session + time-indexed | "What was true on date X" — valid-from/valid-until queries; prevents stale facts contradicting new ones |

## Benchmarks

**Deep Memory Retrieval (DMR):**

| System | DMR Accuracy | Notes |
|---|---|---|
| Zep (Temporal KG) | 94.8% | Best accuracy; 90% latency reduction vs. full-context baseline |
| MemGPT | 93.4% | Good general performance |
| GraphRAG | ~75–85% | 20–35% gain over baseline RAG; up to 30% less hallucination |
| Vector RAG | ~60–70% | Loses relationship structure |
| Recursive Summarization | 35.3% | Severe information loss |

**Files vs. structured stores (LongMemEval-S)** — files trade accuracy for cost, not the reverse of common assumption:

| Metric | File-based | Structured | Gap |
|---|---|---|---|
| Accuracy | 44.9% | 73.6% | 29pts (widens to 15pts further at 500-session scale) |
| Tokens per correct answer | 665k | 27k | ~25x |
| Abstention accuracy | 88.9% | 77.8% | files win |

Raw dated-fact stores (no LLM-distillation step) beat LLM-distilled knowledge graphs (Zep 74.6%, Graphiti 53.4%) at 6x less context, 400x less ingest cost — the win is "undistilled structure beats files on cross-session joins/temporal aggregation," not "structure beats files" generally. File-based memory is fine for session-scoped recall, small fact counts, human-readable audit trails; it degrades on cross-session joins and temporal aggregation across many sessions — that's the signal to add a structured layer, not before. (Source: pinglin.tw, "The Shapes of Agent Memory"; benchmarked on LongMemEval/LoCoMo.)

## How Shipping Harnesses Do It (2026)

| Harness | Retrieval | Persistence | Key shortcoming |
|---|---|---|---|
| Claude Code | Filename-based selection (separate model call) | Local markdown, 200-line index, 5 files/turn | Relevantly-named file wins over relevant file; silent truncation |
| Managed Agents | Filesystem mount | `/mnt/memory/`, immutable versions, 100KB/store | Built for multi-agent coordination, not personal cross-session context |
| Codex | Grep (substring only) | `~/.codex/memories/` markdown, 30-day pruning | Paraphrased facts invisible to grep; 6hr idle gate blocks back-to-back consolidation |
| Copilot | Citation verification (JIT vs. current branch) | Structured `{subject, content, file:line, reasoning}`, 28-day expiry | Can't hold ungroundable facts; repo-scoped only |
| OpenClaw | Hybrid 70% vector + 30% BM25 | SQLite index + MEMORY.md | Silent compaction loss; needs plugin for reliable auto-capture |
| Hermes | FTS5 keyword only | MEMORY.md + USER.md, ~1.3k tokens combined | Keyword-only misses paraphrases; very small durable budget |

Only published real-world A/B: Copilot, p<0.00001 — PR merge rate 83%→90% with memory on, code-review precision +3%/recall +4%.

## Scoring: Rank Retrieved Memories

Generative Agents formula (Park et al. 2023) — re-rank after initial vector retrieval (top-20 by cosine → re-rank by this → return top-k):

```python
def memory_score(relevance, importance, created_at, decay_factor=0.995):
    hours_old = (datetime.utcnow() - created_at).total_seconds() / 3600
    recency = decay_factor ** hours_old
    return relevance * 0.4 + importance * 0.3 + recency * 0.3
```

`decay_factor=0.995` → a 24h-old memory retains ~88% of recency score, ~60% at 1 week. Weights (0.4/0.3/0.3) are a starting point — tune per domain.

**Gate at write time, not just retrieval time.** Score importance (0–1) with a cheap model before persisting; only store above a threshold (e.g. 0.5). An ever-growing store degrades retrieval (more noise, higher latency, more contradictions) — gating at write is cheaper than pruning later.

## Which Type, When

| Information type | Use |
|---|---|
| Preferences, behavior, identity | Memory block, inline in prompt, < 500 chars |
| Data, knowledge, facts | Files with hierarchical paths |
| Procedures, workflows, how-to | Skills (indexed SKILL.md files) |
| Cross-session episodic log | Append-only file (observations.md pattern) |

## Anti-Patterns

- **Knowledge graphs for agent memory** — benchmark-appealing but underperform in practice: LLM weights don't know your KG's schema, so traversal requires prompt engineering that breaks at scale. The loss is specific to *LLM-distilled* graphs, not structure itself — raw dated-fact stores beat both files and distilled KGs. Prefer files + vector search unless relationship reasoning is the explicit requirement.
- **SQL-backed memory stores** — same problem as KGs: schema is arbitrary to the model, every query becomes prompt engineering against an opaque structure.
- **Memory blocks over 500 chars** — inline prompt memory beyond ~500 chars/block crowds out working context; push data to files instead.
- **Cross-user memory leakage (critical)** — memories from one user accessible to another is a severity-critical bug class, not an edge case. Enforce strict user isolation in the store, not just in the prompt.
- **Store everything forever** — unbounded growth degrades retrieval; apply the write-time importance gate above.
- **Shipping a chunking/retrieval strategy untested** — chunk size and retrieval quality interact; validate retrieval on real queries before trusting a chunking choice.

## MCP-Backed Memory (API Shape)

A common pattern for giving an agent durable memory without building storage yourself: expose it as 4 MCP tools — `memory_search(query, type?, tags?)`, `memory_write(key, type, content, tags?)`, `memory_read(key)`, `memory_stats()`. Keying by `key` + `type` + `tags` gives cheap filtering without a full query language. Treat the underlying store as a black box; the 4-verb shape (search/write/read/stats) is the reusable part, not any specific implementation.

## Integration

Builds on context fundamentals (for budgeting what enters context). Connects to multi-agent-patterns for cross-agent shared state, and to context-optimization for memory-based just-in-time loading.
