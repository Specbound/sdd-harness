# Context Optimization Reference

This document provides detailed technical reference for context optimization techniques and strategies.

## Compaction Strategies

### Summary-Based Compaction

Summary-based compaction replaces verbose content with concise summaries while preserving key information. The approach works by identifying sections that can be compressed, generating summaries that capture essential points, and replacing full content with summaries.

The effectiveness of compaction depends on what information is preserved. Critical decisions, user preferences, and current task state should never be compacted. Intermediate results and supporting evidence can be summarized more aggressively. Boilerplate, repeated information, and exploratory reasoning can often be removed entirely.

### Token Budget Allocation

Effective context budgeting requires understanding how different context components consume tokens and allocating budget strategically:

| Component | Typical Range | Notes |
|-----------|---------------|-------|
| System prompt | 500-2000 tokens | Stable across session |
| Tool definitions | 100-500 per tool | Grows with tool count |
| Retrieved documents | Variable | Often largest consumer |
| Message history | Variable | Grows with conversation |
| Tool outputs | Variable | Can dominate context |

### Compaction Thresholds

Trigger compaction at appropriate thresholds to maintain performance:

- Warning threshold at 70% of effective context limit
- Compaction trigger at 80% of effective context limit
- Aggressive compaction at 90% of effective context limit

The exact thresholds depend on model behavior and task characteristics. Some models show graceful degradation while others exhibit sharp performance cliffs.

## Observation Masking Patterns

### Selective Masking

Not all observations should be masked equally. Consider masking observations that have served their purpose and are no longer needed for active reasoning. Keep observations that are central to the current task. Keep observations from the most recent turn. Keep observations that may be referenced again.

### Masking Implementation

```python
def selective_mask(observations: List[Dict], current_task: Dict) -> List[Dict]:
    """
    Selectively mask observations based on relevance.
    
    Returns observations with mask field indicating masked content.
    """
    masked = []
    
    for obs in observations:
        relevance = calculate_relevance(obs, current_task)
        
        if relevance < 0.3 and obs["age"] > 3:
            # Low relevance and old - mask
            masked.append({
                **obs,
                "masked": True,
                "reference": store_for_reference(obs["content"]),
                "summary": summarize_content(obs["content"])
            })
        else:
            masked.append({
                **obs,
                "masked": False
            })
    
    return masked
```

## KV-Cache Optimization

### Prefix Stability

KV-cache hit rates depend on prefix stability. Stable prefixes enable cache reuse across requests. Dynamic prefixes invalidate cache and force recomputation.

Elements that should remain stable include system prompts, tool definitions, and frequently used templates. Elements that may vary include timestamps, session identifiers, and query-specific content.

### Cache-Friendly Design

Design prompts to maximize cache hit rates:

1. Place stable content at the beginning
2. Use consistent formatting across requests
3. Avoid dynamic content in prompts when possible
4. Use placeholders for dynamic content

```python
# Cache-unfriendly: Dynamic timestamp in prompt
system_prompt = f"""
Current time: {datetime.now().isoformat()}
You are a helpful assistant.
"""

# Cache-friendly: Stable prompt with dynamic time as variable
system_prompt = """
You are a helpful assistant.
Current time is provided separately when relevant.
"""
```

## Context Partitioning Strategies

### Sub-Agent Isolation

Partition work across sub-agents to prevent any single context from growing too large. Each sub-agent operates with a clean context focused on its subtask.

### Partition Planning

```python
def plan_partitioning(task: Dict, context_limit: int) -> Dict:
    """
    Plan how to partition a task based on context limits.
    
    Returns partitioning strategy and subtask definitions.
    """
    estimated_context = estimate_task_context(task)
    
    if estimated_context <= context_limit:
        return {
            "strategy": "single_agent",
            "subtasks": [task]
        }
    
    # Plan multi-agent approach
    subtasks = decompose_task(task)
    
    return {
        "strategy": "multi_agent",
        "subtasks": subtasks,
        "coordination": "hierarchical"
    }
```

## Optimization Decision Framework

### When to Optimize

Consider context optimization when context utilization exceeds 70%, when response quality degrades as conversations extend, when costs increase due to long contexts, or when latency increases with conversation length.

### What Optimization to Apply

Choose optimization strategies based on context composition:

If tool outputs dominate context, apply observation masking. If retrieved documents dominate context, apply summarization or partitioning. If message history dominates context, apply compaction with summarization. If multiple components contribute, combine strategies.

### Evaluation of Optimization

After applying optimization, evaluate effectiveness:

- Measure token reduction achieved
- Measure quality preservation (output quality should not degrade)
- Measure latency improvement
- Measure cost reduction

Iterate on optimization strategies based on evaluation results.

## Common Pitfalls

### Over-Aggressive Compaction

Compacting too aggressively can remove critical information. Always preserve task goals, user preferences, and recent conversation context. Test compaction at increasing aggressiveness levels to find the optimal balance.

### Masking Critical Observations

Masking observations that are still needed can cause errors. Track observation usage and only mask content that is no longer referenced. Consider keeping references to masked content that could be retrieved if needed.

### Ignoring Attention Distribution

The lost-in-middle phenomenon means that information placement matters. Place critical information at attention-favored positions (beginning and end of context). Use explicit markers to highlight important content.

### Premature Optimization

Not all contexts require optimization. Adding optimization machinery has overhead. Optimize only when context limits actually constrain agent performance.

## Monitoring and Alerting

### Key Metrics

Track these metrics to understand optimization needs:

- Context token count over time
- Cache hit rates for repeated patterns
- Response quality metrics by context size
- Cost per conversation by context length
- Latency by context size

### Alert Thresholds

Set alerts for:

- Context utilization above 80%
- Cache hit rate below 50%
- Quality score drop of more than 10%
- Cost increase above baseline

## Integration Patterns

### Integration with Agent Framework

Integrate optimization into agent workflow:

```python
class OptimizingAgent:
    def __init__(self, context_limit: int = 80000):
        self.context_limit = context_limit
        self.optimizer = ContextOptimizer()
    
    def process(self, user_input: str, context: Dict) -> Dict:
        # Check if optimization needed
        if self.optimizer.should_compact(context):
            context = self.optimizer.compact(context)
        
        # Process with optimized context
        response = self._call_model(user_input, context)
        
        # Track metrics
        self.optimizer.record_metrics(context, response)
        
        return response
```

### Integration with Memory Systems

Connect optimization with memory systems:

```python
class MemoryAwareOptimizer:
    def __init__(self, memory_system, context_limit: int):
        self.memory = memory_system
        self.limit = context_limit
    
    def optimize_context(self, current_context: Dict, task: str) -> Dict:
        # Check if information is in memory
        relevant_memories = self.memory.retrieve(task)
        
        # Move information to memory if not needed in context
        for mem in relevant_memories:
            if mem["importance"] < threshold:
                current_context = remove_from_context(current_context, mem)
                # Keep reference that memory can be retrieved
        
        return current_context
```

## Context Governance

Context optimization addresses *how* to reduce tokens. Context governance addresses *what to select and why*. Both are needed; governance should precede optimization.

### Context as Selection Policy

The default failure mode is treating context as a buffer that fills until an optimization pass is triggered. Instead, build a selection policy that actively scores and filters candidates before optimization is needed.

Key distinction:
- **Buffer fill**: "Add everything potentially relevant, then compact if too big"
- **Selection policy**: "Score each candidate against current task; include only what passes the relevance threshold"

### Four Governance Axes

Every item included in a context window should be evaluated against all four:

| Axis | Concern | Anti-pattern |
|---|---|---|
| **Relevance** | Semantic alignment to the current task — score and filter, don't include by default | Adding all retrieved docs "in case they're useful" |
| **Compactness** | Minimize tokens without dropping critical signal — prefer summaries over raw output | Keeping full tool outputs after their purpose is served |
| **Traceability** | Every context item carries source attribution (origin, timestamp, why included) — enables audit and failure analysis | Unmarked context where the model can't distinguish retrieved facts from model-generated summaries |
| **Refresh Policy** | Stale content is updated or evicted; environment state is re-verified before high-stakes actions | Memory note referencing a function that was renamed two weeks ago |

### Staleness-Aware Retrieval Ranking

When pulling from memory or a knowledge store into context, rank candidates by:

```
rank_score = relevance_similarity
           - staleness_penalty × time_since_last_verification
           + confidence_weight
```

Tune staleness_penalty by volatility:
- High penalty: items referencing code, APIs, config (change frequently)
- Low penalty: items referencing architectural decisions, design principles (change rarely)

### Provenance Tagging

Each context block should carry a lightweight header to enable traceability:

```
[Source: memory/hot-memory.md | Verified: 2026-05-30 | Relevance: current task]
```

This makes refresh decisions auditable and failure analysis tractable ("wrong context included because verification date was 3 weeks ago").

## Performance Benchmarks

### Compaction Performance

Compaction should reduce token count while preserving quality. Target:

- 50-70% token reduction for aggressive compaction
- Less than 5% quality degradation from compaction
- Less than 10% latency increase from compaction overhead

### Masking Performance

Observation masking should reduce token count significantly:

- 60-80% reduction in masked observations
- Less than 2% quality impact from masking
- Near-zero latency overhead

### Cache Performance

KV-cache optimization should improve cost and latency:

- 70%+ cache hit rate for stable workloads
- 50%+ cost reduction from cache hits
- 40%+ latency reduction from cache hits

