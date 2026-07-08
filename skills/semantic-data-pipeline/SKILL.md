---
name: semantic-data-pipeline
description: Use when writing batch LLM transformation over many rows/records (extract-to-schema, classify, NL-filter, reduce/summarize) that must be reproducible — treat it as a lazily-evaluated query with a caching/cost/lineage layer, not an ad-hoc loop of API calls. Reference implementation is fenic. Triggered by "process N records with an LLM", "batch extract structured data from these", "classify/enrich this dataset with a model", "make this LLM pipeline reproducible/cheaper".
---

# Semantic Data Pipeline

When LLM inference runs over **many rows** and the result must be **reproducible and
auditable**, model it as a *typed, lazily-evaluated query* — not a `for` loop of API calls.
The lazy-query framing is what unlocks three things a hand-rolled loop can't give you cheaply:

- **Caching** — identical (input, prompt, model) tuples dedupe automatically; re-runs cost near-zero.
- **Cost accounting** — tokens/$ per operation, not one opaque bill.
- **Lineage** — every output row traces back to its input row for audit and debugging.

**Reference implementation:** [fenic](https://github.com/typedef-ai/fenic) (typedef-ai) — a
PySpark-inspired DataFrame library that exposes LLM inference as first-class semantic operators.
This skill teaches the *pattern and the decision*; use fenic's docs (via `get-api-docs`) for syntax
only if you actually adopt it.

## When to Activate

- You are about to write a loop that calls an LLM once per row/record/file over a collection.
- The transform is one of: **extract** (text → schema), **classify** (text → label), **predicate**
  (NL filter — keep rows matching a natural-language condition), **reduce** (many rows → one summary).
- Re-running must be cheap (caching) OR you need per-operation cost visibility OR you need to trace
  an output back to its source row.

## Do NOT Activate (routes to other skills)

- **Sourcing/building the dataset itself** from a NL description or the live web → `structured-web-dataset`.
  That skill *produces rows*; this one *transforms existing rows* with reproducibility guarantees.
- **Retrieval / vector search / embedding-model choice** → `rag-architect`. Semantic joins here are
  transform operators, not a retrieval strategy.
- **Ingesting/parsing** PDFs, DOCX, images into text → `document-parsing` (do that first; feed the output here).
- **Ad-hoc stats/plots** over an existing CSV → `csv-data-summarizer`.
- A one-off single call, or a handful of rows where a plain loop is simpler — the caching/lineage
  machinery is not worth it. This skill earns its keep at scale + reproducibility, not for 5 rows.

## The Four Semantic Operators (taxonomy)

| Operator | Shape | Example |
|---|---|---|
| **extract** | text → typed schema | pull `{title, date, sentiment}` from each blog post |
| **classify** | text → label(s) | tag each support ticket `bug\|feature\|billing` |
| **predicate** | text → bool (NL filter) | keep rows where "the review mentions shipping delays" |
| **reduce** | many rows → one | summarize all of one cluster's rows into a paragraph |

Semantic `join` / similarity-join / clustering are the same idea applied across two frames.

## Workflow

1. **Decide it's a pipeline, not a loop** — check the activation gate above. If it's <~20 rows and
   one-shot, stop and just write the loop.
2. **Define the schema first** — the output type (Pydantic/JSON schema) is the contract. Extract and
   classify both bind to it; validation happens at the operator boundary so the model retries on mismatch.
3. **Model each stage as an operator** (extract/classify/predicate/reduce), lazily. Do not materialize
   between stages — lazy eval is what lets the engine cache, cost-account, and dedupe.
4. **Materialize once** at the end. Inspect cost accounting and cache hit-rate.
5. **Graduate stable pipelines** — a pipeline you run repeatedly is a candidate to freeze behind a
   governed interface (fenic's MCP-tool graduation, or your own script/command). Exploration → pipeline
   → tool.

## Why lazy eval matters (the non-obvious insight)

A `for` loop calls the model eagerly and throws away everything but the result. A lazy query builds a
plan first, so the engine can: dedupe identical calls before spending a token, attribute cost per
operator, and keep the input→output edge for lineage. You get observability and reproducibility *for
free* from the framing — that is the entire reason to reach for a semantic-DataFrame engine over a loop.

## Related Skills

- `structured-web-dataset` — build the table (upstream of this skill)
- `document-parsing` — parse files to text (upstream)
- `rag-architect` — retrieval strategy (different problem: fetch, not transform)
- `csv-data-summarizer` — analyze/plot a finished table (downstream)
- `context-optimization` — if the batch context itself is large
