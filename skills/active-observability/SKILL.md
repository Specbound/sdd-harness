---
name: active-observability
description: Surface unknown patterns in agent trace collections via facet-based analysis — batch-LLM-summarize traces, cluster summaries, report topic groups. Use when you want to discover what to look for before you know what questions to ask.
source: Braintrust Topics (Clio-inspired) — pasted article 2026-06-07
risk: low
---

# Active Observability

Discover patterns in agent trace collections you didn't know to look for, using the Braintrust Topics facet pipeline adapted for Raindrop Workshop + Claude.

## When to use

- You have ≥20 traces in Workshop and want to know "what are agents actually doing?"
- Before writing eval assertions — surface the most common task types and failure modes first
- After a production incident — cluster recent traces to find related failures
- Periodic pattern review — what new behaviors emerged this week?

## Do not use when

- You already know what to test → use `raindrop-eval-loop` instead
- Fewer than 20 traces available — clusters won't be meaningful
- You need real-time per-trace classification — this is batch analysis

## Core Pipeline (Braintrust Topics, adapted)

```
preprocess → facet → embed → cluster → name → classify
```

Adapted for this harness: replace embed + HDBSCAN with LLM-as-judge clustering — same outcome, no ML deps.

**Key optimizations:**
- Batch multiple facet dimensions into **one LLM call** — trace tokens paid once
- Summarize first, embed summary (not raw trace) — million-token traces don't embed cleanly
- Hard-cap preprocessed input at 128K tokens before facet model
- No LLM at classification time — nearest summary lookup only

## Standard Facets

| Facet | Prompt fragment |
|-------|----------------|
| **Task** | "What is the agent trying to accomplish in this trace? One sentence." |
| **Issues** | "What went wrong or showed friction? If nothing, write 'none'." |
| **Sentiment** | "Overall output quality: high / medium / low." |

Custom facets: add any domain dimension (product area, user type, feature touched).

---

## Phase 1 — Collect Traces

```bash
# Fetch recent traces from Workshop
curl -s "http://localhost:5899/api/events?event=<REPO_NAME>&limit=50" \
  | python3 -m json.tool > /tmp/ao_traces.json

python3 -c "import json; t=json.load(open('/tmp/ao_traces.json')); print(f'{len(t)} traces')"
```

Need ≥20. Below 20, skip — output would be noise.

Extract per-trace content: walk spans, deduplicate messages across spans, drop scorer/metric spans. Cap at 128K tokens.

---

## Phase 2 — Batch Facet (one call per trace)

For each trace make **one** LLM call requesting all facets simultaneously:

```
System: Analyze this agent execution trace. Return a JSON object with exactly these fields.

User: <trace_content — capped at 128K tokens>

Return JSON:
{
  "task": "one sentence: what the agent was trying to do",
  "issues": "one sentence: what went wrong or showed friction, or 'none'",
  "sentiment": "high | medium | low"
}
```

Cost: `trace_tokens + ~200 prompt tokens` per trace (not per facet).
Running 5 facets separately would cost `5 × trace_tokens`.

---

## Phase 3 — Cluster Summaries (LLM-as-judge)

Collect all `task` facets. Send to Claude in one batch (max 50 summaries):

```
Here are N one-sentence descriptions of what agents were doing in separate traces.
Group them into 5-8 meaningful topic clusters.
For each cluster: name it, count members, quote 2-3 representative examples.

Descriptions:
1. [task facet 1]
2. [task facet 2]
...

Return JSON:
[{"cluster": "name", "count": N, "examples": ["...", "..."]}]
```

For >50 traces: sample representatively (spread across time, not just most recent).

Repeat for `issues` facets (skip entries where value is `'none'`).

---

## Phase 4 — Report

```markdown
## Agent Trace Pattern Report
**Traces analyzed:** N | **Date:** YYYY-MM-DD | **Repo:** <name>

### By Task (what agents were asked to do)
1. **[Cluster Name]** (N traces, N%)
   Examples: "...", "..."

2. **[Cluster Name]** ...

### Issues Found
[Repeat cluster format — skip if all 'none']

### Quality Distribution
high: N% | medium: N% | low: N%

### Recommended Eval Targets
Top 2-3 task clusters → happy path scenarios for raindrop-eval-loop
Top issue clusters → edge cases and bug candidates
```

Save to `.claude/memory/trace-patterns-<YYYY-MM-DD>.md`.

---

## Acting on Results

| Finding | Action |
|---------|--------|
| High-volume task cluster | Write eval assertions → `raindrop-eval-loop` |
| Issue cluster | File as bug or UX improvement |
| Low sentiment cluster | Investigate agent output quality |
| Small unexpected cluster | Investigate — long-tail bugs live here |

**Stability note:** Re-running clustering on the same facets may produce different cluster names — the names are generative. Treat the *distribution* as stable, not the labels.
