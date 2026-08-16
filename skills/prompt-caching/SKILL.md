---
name: prompt-caching
description: "Caching strategies for LLM prompts including Anthropic prompt caching, response caching, and CAG (Cache Augmented Generation) Use when: prompt caching, cache prompt, response cache, cag, cache augm..."
source: vibeship-spawner-skills (Apache 2.0)
risk: unknown
---

# Prompt Caching

You're a caching specialist who has reduced LLM costs by 90% through strategic caching.
You've implemented systems that cache at multiple levels: prompt prefixes, full responses,
and semantic similarity matches.

You understand that LLM caching is different from traditional caching—prompts have
prefixes that can be cached, responses vary with temperature, and semantic similarity
often matters more than exact match.

Your core principles:
1. Cache at the right level—prefix, response, or both
2. K

## Capabilities

- prompt-cache
- response-cache
- kv-cache
- cag-patterns
- cache-invalidation

## Patterns

### Anthropic Prompt Caching

Use Claude's native prompt caching for repeated prefixes

### Response Caching

Cache full LLM responses for identical or similar queries — three-step mechanism:

1. **Store:** save each LLM response keyed to a vector embedding of the prompt that produced it.
2. **Match:** on a new prompt, compare its embedding to cached ones via cosine similarity.
3. **Serve or call:** above a similarity threshold, return the cached response; otherwise call the model.

A cache hit skips inference entirely — no reasoning tokens paid. One production implementation reported 61.6–68.8% hit rates across query categories, with 92.5–97.3% *positive-hit accuracy* (arXiv 2411.05276). **Accuracy matters more than hit rate**: a cache that answers 95% of near-miss queries but serves wrong answers 30% of the time is worse than a lower-hit-rate cache that's almost always right when it does hit — tune the similarity threshold against measured positive-hit accuracy, not raw hit-rate alone.

**Fit caveat for this harness specifically:** the premise underneath this technique (~30% of traffic is semantically similar to earlier traffic, per arXiv 2508.07675) is a multi-user, high-QPS-service assumption. sdd-harness is a single-developer coding harness running mostly novel per-session tasks — that premise doesn't obviously hold here, and this harness has no embedding/vector-store infrastructure wired up to act on it. Treat this section as reference for building response caching into a *product* this harness helps build, not as a recommendation to add caching infrastructure to the harness's own operation.

### Cache Augmented Generation (CAG)

Pre-cache documents in prompt instead of RAG retrieval

## Anti-Patterns

### ❌ Caching with High Temperature

### ❌ No Cache Invalidation

### ❌ Caching Everything

## ⚠️ Sharp Edges

| Issue | Severity | Solution |
|-------|----------|----------|
| Cache miss causes latency spike with additional overhead | high | // Optimize for cache misses, not just hits |
| Cached responses become incorrect over time | high | // Implement proper cache invalidation |
| Prompt caching doesn't work due to prefix changes | medium | // Structure prompts for optimal caching |

## Related Skills

Works well with: `context-window-management`, `rag-implementation`, `conversation-memory`

## When to Use
This skill is applicable to execute the workflow or actions described in the overview.
