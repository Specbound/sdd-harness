# Macro Evals — Pipeline Reference

Extended reference for the `macro-evals` skill. Source: OpenAI Cookbook, "Macro Evals for Agentic Systems."

## Rubric taxonomy (micro layer)

The reference system grades each run pass/fail on five rubrics. Adapt the *names* to your domain; keep the *shape* (small set of orthogonal, checkable criteria):

| Rubric | Question |
|---|---|
| `final_decision_quality` | Is the final decision supported by the active issues, terminal state, and agent outputs? |
| `policy_compliance_correctness` | Were policy / tariff / incentive / regional constraints handled correctly? |
| `routing_specialist_activation` | Did specialist routing match the issues actually present? |
| `market_drift_awareness` | Were changing conditions and dated signals noticed? |
| `review_appropriateness` | Was review/escalation proportionate to case risk? (Unnecessary escalation is itself a finding.) |

## Outcome → severity taxonomy

```
case_type (generated/observed setup)
  → run_outcome   (completed | awaiting_review | blocked | failed)
  → eval_finding  (which rubric failed)
  → behavior_pattern (discovered post-clustering)
```

| Outcome group | Severity weight |
|---|---|
| successful_completion | 1.0 |
| review_escalation | 2.0 |
| hard_failure | 2.5 |

## Scoring formulas (all decomposable on purpose)

Class-aware term labeling (distinctive vocabulary per cluster):
```
score(term, cluster) = tf(term, cluster) × log((1 + N) / (1 + df(term)))
```

Pattern impact (population ranking):
```
impact_score = prevalence_share × severity_weighted_prevalence
# variant used in the notebook:
impact_score = severity_weight × (1.0 + findings_count) × (1.0 + loop_count / 4.0)
```

Backward suspect score (diagnosis):
```
suspect_score = 0.4·proximity + 0.3·frequency + 0.2·bridge + 0.1·role
```

## Focus-event signals (where backward walks start)

- `review finding` — a review surface recorded an issue
- `awaiting_review` / `review_required` — workflow paused for a human
- `failed` / `blocked` — degraded terminal state
- `triage route` / reroute — workflow changed direction
- tool warnings / policy markers — structured output indicating risk

## Clustering stack (BERTopic-style)

- **Embedder** — transformer document encoder (BERT family)
- **Reducer** — UMAP, preserve local neighborhood structure
- **Clusterer** — HDBSCAN, `min_cluster_size` ≥ 24 for population studies
- **Labeler** — class-aware TF-IDF variant for distinctive cluster terms

When N is small or you lack embedding infra, substitute an LLM grouping pass: feed the compressed trace documents and ask for named behavior-pattern groups with run-id membership and a one-line rationale each. The downstream impact/suspect math is identical.

## Visualization patterns

- **Sankey** — flow case_type → outcome → finding → pattern
- **Leaderboard** — behavior patterns ranked by impact
- **Heatmap** — pattern concentration across case-type slices, with lift
- **Scatter** — trace geometry in reduced vector space, colored by pattern
- **Swimlane** — focus-event-anchored trajectory with suspect scoring

## Runnable pipeline sketch over Raindrop Workshop traces

The harness automates this against Raindrop's read-only trace tables. Key tables (via `mcp__raindrop__query_traces`, a read-only SQLite SELECT surface):

- `runs_with_hints(id, name, event_name, started_at, metadata, model, finished, span_count, live_event_count, payload_total_chars)`
- `spans(id, run_id, parent_span_id, name, span_type, status, input_payload, output_payload, duration_ms, model, attributes)`
- `annotations(id, run_id, span_id, kind, note, source, created_at)` — kind ∈ {issue, good, note}

### Phase 1 — population window
```sql
SELECT id, name, event_name, started_at, finished, span_count, metadata
FROM runs_with_hints
WHERE started_at >= :window_start
ORDER BY started_at DESC;
```

### Phase 1b — failure signal per run (error spans, non-OK status)
```sql
SELECT run_id,
       COUNT(*)                                            AS span_count,
       SUM(CASE WHEN status NOT IN ('ok','OK','') THEN 1 ELSE 0 END) AS error_spans,
       SUM(CASE WHEN span_type = 'tool' THEN 1 ELSE 0 END) AS tool_calls
FROM spans
WHERE run_id IN (:window_run_ids)
GROUP BY run_id;
```

### Phase 2 — trace document
Build one compressed document per run from the joined row: `name`, derived `run_outcome` (finished + error_spans → completed/failed/blocked), error span names as `review_markers`, the ordered span `name|span_type|status` sequence as `state_digest`. Keep each document short (a few hundred tokens).

### Phase 3 — group
For modest N, hand the compressed documents to an LLM grouping pass; for large N, run the BERTopic stack. Output `behavior_pattern → [run_id...]`.

### Phase 4 — impact leaderboard
Compute `impact_score` per pattern using the severity weights above; sort descending.

### Phase 5 — suspect trace
For the top patterns, pull `get_run_outline(run_id)` on 2–3 representative runs, identify the focus event (first error span / awaiting_review marker), walk parent_span_id backward, score suspects, report the top step.

### Persist findings
- Run-level verdict: `annotate(run_id, kind='issue', note='<pattern>: <suspect step>')`
- Span-level evidence: `annotate(run_id, span_id, kind='issue', note=...)`
Use `kind='note'` for observations, `kind='issue'` for confirmed recurring failures.

## Environment knobs (from the reference notebook)

- `MACRO_EVALS_DATA_ROOT` — data directory
- `MACRO_EVALS_LABELS_PATH` — per-run eval labels
- `MACRO_EVALS_TRACE_LIMIT` — population cap for testing
- `MACRO_EVALS_DISCOVERY_MIN_CLUSTER_SIZE` — default 24
- `RANDOM_STATE` — reproducibility seed

## Named tools in the source

- **Promptfoo** — per-run rubric grading (micro layer)
- **OpenAI Agents SDK** — agent packaging with traces/handoffs/guardrails
- Helper modules `data_prep.py` (normalize, build documents, join labels) and `macro_eval_pipeline.py` (discovery, clustering, suspect diagnosis, visualization)
