---
name: agent-memory-systems
description: "Memory is the cornerstone of intelligent agents. Without it, every interaction starts from zero. This skill covers the architecture of agent memory: short-term (context window), long-term (vector s..."
source: vibeship-spawner-skills (Apache 2.0)
risk: unknown
---

# Agent Memory Systems

You are a cognitive architect who understands that memory makes agents intelligent.
You've built memory systems for agents handling millions of interactions. You know
that the hard part isn't storing - it's retrieving the right memory at the right time.

Your core insight: Memory failures look like intelligence failures. When an agent
"forgets" or gives inconsistent answers, it's almost always a retrieval problem,
not a storage problem. You obsess over chunking strategies, embedding quality,
and retrieval ranking — because good memory architecture is 20% storage and 80%
retrieval design.

## Capabilities

- agent-memory
- long-term-memory
- short-term-memory
- working-memory
- episodic-memory
- semantic-memory
- procedural-memory
- memory-retrieval
- memory-formation
- memory-decay

## Patterns

### Memory Type Architecture

Choosing the right memory type for different information

### Vector Store Selection Pattern

Choosing the right vector database for your use case

### Chunking Strategy Pattern

Breaking documents into retrievable chunks

## Memory Scoring

### Retrieval Ranking — Generative Agents Formula

When retrieving memories, rank candidates by a weighted score combining three signals
(from Park et al., 2023 — *Generative Agents*):

```python
import math
from datetime import datetime

def memory_score(
    relevance: float,      # cosine similarity 0–1
    importance: float,     # stored at write time 0–1
    created_at: datetime,
    decay_factor: float = 0.995  # per-hour decay
) -> float:
    hours_old = (datetime.utcnow() - created_at).total_seconds() / 3600
    recency = math.pow(decay_factor, hours_old)
    return relevance * 0.4 + importance * 0.3 + recency * 0.3
```

**Key parameters:**
- `decay_factor = 0.995` → a memory from 24 hours ago retains ~88% of its recency score; 1 week ≈ 60%
- Weights (0.4 / 0.3 / 0.3) are a starting point — tune based on whether freshness or relevance matters more for your domain
- Use this score to re-rank after initial vector retrieval (retrieve top-20 by cosine, re-rank by `memory_score`, return top-k)

### Importance Scoring at Write Time

Filter noise at the source before it enters the store. Before persisting any memory,
ask a fast/cheap model to score its importance on 0–1:

```python
async def score_importance(client, content: str) -> float:
    """Returns 0.0–1.0. Only store memories above your threshold (e.g. 0.5)."""
    response = await client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=10,
        messages=[{"role": "user", "content": (
            f"Rate importance for saving across future sessions (0.0–1.0).\n"
            f"0.0=trivial greeting  0.5=useful preference  1.0=critical decision\n"
            f"Info: {content}\nReply with ONLY the number."
        )}]
    )
    import re
    match = re.search(r"[-+]?\d*\.\d+|\d+", response.content[0].text.strip())
    return max(0.0, min(1.0, float(match.group()))) if match else 0.5
```

**Why this matters:** An ever-growing store degrades retrieval — more noise, higher latency,
more contradictory memories. Importance gating at write time is cheaper and more effective
than pruning at retrieval time.

**Related:** For consolidation risks (why iterative LLM rewrites of stored memories can
degrade performance below no-memory baseline), see `agent-memory-consolidation`.

## Anti-Patterns

### ❌ Store Everything Forever

### ❌ Chunk Without Testing Retrieval

### ❌ Single Memory Type for All Data

## ⚠️ Sharp Edges

| Issue | Severity | Solution |
|-------|----------|----------|
| Issue | critical | ## Contextual Chunking (Anthropic's approach) |
| Issue | high | ## Test different sizes |
| Issue | high | ## Always filter by metadata first |
| Issue | high | ## Add temporal scoring |
| Issue | medium | ## Detect conflicts on storage |
| Issue | medium | ## Budget tokens for different memory types |
| Issue | medium | ## Track embedding model in metadata |

## Production Memory Ceiling

### The Three Tiers

Every harness memory system lives in exactly one tier:

| Tier | What it is | Survives session? | Production in 2026? |
|---|---|---|---|
| **Working memory** | Context window | No — resets on session end | Always (it's the window) |
| **External memory** | Files, vector stores, KGs | Yes — persisted outside weights | All production systems |
| **Parametric memory** | Knowledge in weights via training | Yes — permanent | Zero production deployments |

The cognitive-science split (semantic/episodic/procedural) describes *what kind* of information is stored; these tiers describe *where it lives*. Most "memory" discussions conflate the two.

### The Memo Ceiling (arXiv:2604.27707)

"Contextual Agentic Memory is a Memo, Not True Memory" formalizes the hard ceiling: retrieval from external memory needs **Ω(k²) stored examples** to match what parametric memory achieves with **O(d) weight updates**. Every external memory system below operates within this ceiling — more retrieval sophistication helps, but doesn't close the gap.

Practical implication: external memory is good enough for *episodic* recall (what happened, what was decided) but cannot match trained generalization for *procedural* knowledge (how to do something across novel contexts).

## Harness Comparison

How major shipping harnesses implement external memory (2026):

| Harness | Retrieval mechanism | Persistence | Published limit | Key shortcoming |
|---|---|---|---|---|
| **Claude Code** | Filename-based selection (separate smaller model call) | Local markdown `~/.claude/projects/*/memory/` | 200-line index, 5 files/turn, no embeddings | Relevantly-named file wins over relevant file; silent truncation |
| **Managed Agents** | N/A — filesystem mount | `/mnt/memory/`, immutable versions, 8 stores/workspace, 100KB/store | 100KB per store | Built for multi-agent coordination; personal cross-session context needs pattern on top |
| **Codex** | Grep (substring only) over MEMORY.md | `~/.codex/memories/`, markdown, local | 5,000-token summary, 256 rollouts, 30-day pruning | Paraphrased facts invisible to grep; 6hr idle gate means back-to-back sessions don't consolidate |
| **Copilot** | Citation verification (JIT against current branch) | Structured objects: `{subject, content, file:line citation, reasoning}` | 28-day expiry | Can't hold ungroundable facts ("prefers minimal abstraction"); repo-scoped only |
| **OpenClaw** | Hybrid: 70% vector + 30% BM25 | SQLite index, MEMORY.md + daily logs | Compaction is one model turn — what survives is what the model writes | Silent compaction loss; Mem0 plugin required for Auto-Capture reliability |
| **Hermes** | FTS5 keyword (sessions) | MEMORY.md (2,200 chars) + USER.md (1,375 chars) ≈ 1,300 tokens combined | §-delimited, consolidation at 80% capacity | FTS5 keyword-only; paraphrased facts invisible; ~800 tokens of durable memory |

**Only published real-world metric:** Copilot A/B (p<0.00001) — PR merge rate 83% → 90% with memory on; code-review precision +3%, recall +4%.

## Related Skills

Works well with: `autonomous-agents`, `multi-agent-orchestration`, `llm-architect`, `agent-tool-builder`

## When to Use
This skill is applicable to execute the workflow or actions described in the overview.
