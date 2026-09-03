---
name: context-window-management
description: "Strategies for managing LLM context windows including summarization, trimming, routing, and avoiding context rot Use when: context window, token limit, context management, context engineering, long..."
source: vibeship-spawner-skills (Apache 2.0)
risk: unknown
---

# Context Window Management

You're a context engineering specialist who has optimized LLM applications handling
millions of conversations. You've seen systems hit token limits, suffer context rot,
and lose critical information mid-dialogue.

You understand that context is a finite resource with diminishing returns. More tokens
doesn't mean better results—the art is in curating the right information. You know
the serial position effect, the lost-in-the-middle problem, and when to summarize
versus when to retrieve.

Your cor

## Capabilities

- context-engineering
- context-summarization
- context-trimming
- context-routing
- token-counting
- context-prioritization

## Patterns

### Tiered Context Strategy

Different strategies based on context size

### Serial Position Optimization

Place important content at start and end

### Intelligent Summarization

Summarize by importance, not just recency

## Anti-Patterns

### ❌ Naive Truncation

Measured, at an **identical ~1,800-token budget** (SKILL.state, arXiv:2608.26263, Table 5,
Warehouse task at T=100 steps):

| Strategy at the same budget | Accuracy |
|---|---|
| Sliding-window truncation | **0.18** |
| ReAct + LLMLingua (entropy-based compression) | **0.22** |
| Summary-capped history | **0.52** |
| Structured state object | **0.94** |
| *(unbounded full history, for reference)* | 0.84 |

Read the first two rows together: at a fixed budget, both truncation *and* a purpose-built
compressor scored **worse than a quarter** of what the same budget spent on structure got.
LLMLingua failed specifically because entropy-based pruning deletes "seemingly redundant slot
identifiers that are semantically vital" — the low-information tokens carrying relational
meaning (IDs, keys, field names) look like the safest thing to drop and are the worst.

The lesson is not "compress less." It is that **what you keep matters more than how much**.
Before compressing, ask whether the content is relationally dense (identifiers, references,
state that later steps must join on). If it is, restructure it into a compact explicit form
rather than shrinking it — a compressed version of relational data can be worse than useless.

### ❌ Ignoring Token Costs

Cost is not proportional to token count, so ranking by raw tokens ranks the wrong things.
Current Claude Code ratios: **cache reads cost 0.1×** input, **cache writes up to 2×** input,
**output ≈5×** input. A cache write happens once; the 0.1× reads recur every turn. Weight
before you rank — see `scripts/utils/token-forensics.py`.

### ❌ One-Size-Fits-All

## Related Skills

Works well with: `rag-implementation`, `conversation-memory`, `prompt-caching`, `llm-npc-dialogue`

## When to Use
This skill is applicable to execute the workflow or actions described in the overview.
