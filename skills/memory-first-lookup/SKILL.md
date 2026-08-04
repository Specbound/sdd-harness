---
name: memory-first-lookup
description: Always search claude-mem before calling any external API, web search, or spawning an agent. Brain-first lookup protocol — check memory, then external sources.
triggers:
  - About to call WebFetch or WebSearch
  - Starting any research or entity lookup task
  - User asks you to find out about a person, project, topic, or decision
  - About to spawn an agent that will research something
  - Phrases like "look up", "research", "find out", "who is", "what do we know about"
  - Before briefing a subagent with context
  - Any question that could be answered by prior work
---

# Memory-First Lookup

The brain often already knows. Check it before burning API calls or spawning research agents.

## The Lookup Chain (MANDATORY ORDER)

1. **`mcp__plugin_claude-mem_mcp-search__search`** — keyword search, fast, zero cost
2. **`mcp__plugin_claude-mem_mcp-search__search`** with semantic phrasing — if keyword search is thin
3. **`mcp__plugin_claude-mem_mcp-search__get_observations`** — read full observations for slugs found in step 1–2
4. **`mcp__plugin_claude-mem_mcp-search__timeline`** — for time-ordered context on a topic
5. **External APIs (WebFetch, WebSearch, gh) only after steps 1–4 return nothing useful**

Never skip to WebFetch, WebSearch, or a research agent without completing steps 1–2 first.

## Decision Rule

- **Clearly relevant hit → use it.** Don't reach for external APIs when memory has the answer.
- **Memory empty or stale → proceed to external.** Don't manufacture an answer from nothing.
- **Memory partial → enrich it.** Search externally, then write what's new back to memory.

## Briefing Agents with Memory

When spawning a subagent for research: run memory lookup first, then include relevant findings in the agent's prompt. An agent that re-discovers what's already known wastes tokens and may diverge from established decisions.

```
# Pattern: memory-aware agent prompt
Search memory for "topic" first.
Then write the agent brief:

Context from memory:
[paste relevant findings]

Your task: [goal — extend what we know, don't re-derive it]
```

## Source Precedence

Memory types ranked by authority (highest first):
1. User's direct statements
2. Project decisions and established rationale
3. Prior research synthesis
4. External sources (always verify freshness before trusting)

If memory conflicts with external sources, surface both with dates. Prefer the more recent source but note the conflict.

## What This Prevents

- Calling web search to find something already in memory from last week
- Spawning a research agent that re-derives decisions already made
- Giving a subagent stale or missing context that memory already has
- Writing conflicting observations because earlier ones weren't checked
