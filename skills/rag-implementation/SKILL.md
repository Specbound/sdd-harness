---
name: rag-implementation
description: "Build and debug Retrieval-Augmented Generation systems — chunking, hybrid retrieval, reranking, grounding prompts, and retrieval-vs-generation failure triage. Use when implementing document Q&A, semantic search over proprietary data, or diagnosing a RAG system that returns wrong or ungrounded answers."
---

# RAG Implementation

RAG quality is decided by **retrieval**, not by the LLM. Most "the model hallucinated"
reports are retrieval failures wearing a disguise. This skill is organised around that.

## Framework versions move fast — pin, don't copy

Verified against PyPI on 2026-10-22:

| Package | Latest |
|---|---|
| `langchain` | **1.4.7** |
| `langchain-text-splitters` | 1.1.3 |
| `langchain-openai` | 1.7.2 |
| `langchain-chroma` | 1.1.0 |
| `langchain-community` | 0.4.2 |
| `pinecone` | 10.1.0 (replaces the frozen `pinecone-client` 6.0.0) |

Two consequences, both of which break copied snippets:

- LangChain split from one package into **many**. Monolithic `langchain.*` imports for
  embeddings, vector stores, loaders and splitters are from the 0.0.x era and no longer
  resolve; those live in provider packages (`langchain-openai`, `langchain-chroma`) or
  `langchain-community`. Text splitters have their own package entirely.
- Pinecone's client was renamed and re-majored. The old `pinecone.init(api_key=...,
  environment=...)` module-level initialiser belongs to a client generation that is gone;
  current clients instantiate a class.

**Do not trust any import line in a RAG tutorial, including this one.** Check the exact
symbol against the version actually installed (`pip show`, then the package's own docs)
before writing code. The architecture below is what's durable; the import paths are not.

## The pipeline, and where quality is won

```
documents → chunk → embed → index → retrieve(k wide) → rerank(→ small k) → prompt → answer+citations
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                     this is where the wins are
```

### Chunking

- **Chunk size is a tradeoff, not a constant.** Large chunks retrieve reliably but dilute
  the embedding and waste context; small chunks embed sharply but lose the surrounding
  meaning. ~500–1000 tokens with 10–20% overlap is a reasonable starting point to *tune
  away from*, not a recommendation to adopt permanently.
- Never exceed the embedding model's max input length — silently truncated chunks index
  only their opening text and retrieve badly for content near the end.
- Split on **structure before characters**: markdown headers, document sections, function
  boundaries. A recursive character splitter with a separator list
  (`["\n\n", "\n", " ", ""]`) approximates this; semantic chunkers that split at embedding
  discontinuities do better on flowing text and cost an extra embedding pass.
- **Parent-document retrieval is the biggest single win in chunking**: embed and search
  *small* chunks, but return the *large* parent to the LLM. You get precise retrieval and
  full context without compromising on one chunk size.

### Embeddings

- **The index and the query must use the same embedding model.** Changing models means
  re-embedding the entire corpus — there is no incremental migration. Budget for this
  before picking a model, not after.
- Store the model name and dimension in the index metadata. Without it, an accidental model
  swap produces a silently degraded system that still returns plausible results.
- `text-embedding-ada-002` appears in most older tutorials. OpenAI superseded it with the
  `text-embedding-3-*` family, which supports dimension reduction — useful when storage
  cost or index size is the constraint.

### Retrieval: use both kinds

Dense (embedding) retrieval understands meaning but reliably misses exact tokens — error
codes, SKUs, surnames, version strings. Sparse retrieval (BM25) catches exactly those and
understands nothing. **Hybrid is not an optimisation, it's a correctness fix** for any
corpus containing identifiers.

Other strategies, in rough order of value per unit of effort:
- **Reranking** — retrieve wide (k=20–50), score with a cross-encoder, keep the top 3–5.
  A cross-encoder reads query and document *together*, so it is far more accurate than
  vector similarity, and too slow to run over the whole corpus. This is usually the single
  biggest quality jump available.
- **Metadata filtering** — index source, section, timestamp, permissions. Filtering before
  search beats semantic cleverness and is how you implement access control. Do not rely on
  the LLM to withhold documents it was given.
- **MMR** — trade some relevance for diversity when top results are near-duplicates.
- **Multi-query** — paraphrase the query N ways, union the results. Helps on short or
  ambiguous queries; costs an LLM call per query.
- **Contextual compression** — have an LLM strip irrelevant passages from retrieved chunks
  before they reach the prompt. Buys context budget, adds latency and a failure mode.

### Grounding prompt

Three non-negotiable elements:

1. An explicit refusal clause — *"If the context does not contain the answer, say you don't
   have enough information."* Without it the model fills gaps from parametric memory, which
   is precisely what RAG exists to prevent.
2. Citation markers tied to retrieved chunk IDs, so claims are traceable.
3. The context clearly delimited from the question.

Asking the model for a self-reported confidence score is popular and near-worthless —
LLM confidence is poorly calibrated. Use retrieval scores and a groundedness check instead.

## Debugging: separate retrieval from generation first

This is the method, and it is the main thing to take from this skill. Before touching the
prompt, ask: **was the correct chunk in the retrieved set?**

- **If no** → retrieval problem. Chunking, embedding model, k, or the query is at fault.
  Prompt changes cannot fix it.
- **If yes, and the answer is still wrong** → generation problem. Prompt, context ordering,
  or context overflow.

Skipping this split is why RAG debugging degenerates into prompt roulette.

| Symptom | Likely cause |
|---|---|
| Right document, wrong passage | Chunks too large — the embedding is diluted |
| Misses exact IDs, codes, names | Dense-only retrieval — add BM25 |
| Correct chunk retrieved but ranked ~15th | No reranker |
| Answer contradicts the provided context | Weak grounding prompt, or context lost mid-prompt |
| Confident answer from no supporting chunk | Missing refusal clause |
| Quality fell off a cliff with no code change | Embedding model changed without reindexing |
| Good in demo, bad in production | Test queries were written by the index's author |

## Evaluation

Build a golden set of ~50 real questions with known supporting documents **before**
tuning. Without it, every change is unfalsifiable.

Measure retrieval and generation separately:
- **Retrieval**: recall@k — was the supporting document in the top k? Tune chunking and
  retrieval against this alone, with generation held fixed.
- **Groundedness**: is each claim in the answer supported by a retrieved chunk? This is the
  hallucination metric.
- **Answer correctness**: compared against the expected answer.

Log retrieved chunk IDs and scores for every production query. When someone reports a bad
answer weeks later, that log is the only way to reconstruct whether retrieval or generation
failed.

## Honest limits of this file

The package versions above were fetched from PyPI on 2026-10-22 and are accurate as of
then. **No RAG pipeline was executed while writing this** — no vector store was started and
no embedding call was made — so no code sample is included that would imply otherwise. The
architectural claims rest on well-established RAG practice; the version table is the only
part checked against a live source, and it is the part that will rot first.
