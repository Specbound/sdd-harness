---
name: structured-web-dataset
description: Build structured tabular datasets from natural language descriptions — either by researching live web data via parallel agents, or by generating synthetic data with defined constraints. Use when output must be a table/CSV, not a prose report. Triggered by: "build a dataset of X", "generate synthetic data for X", "I need a table of X", "create training data with columns Y, Z".
---

# Structured Web Dataset

Turns a natural language description into a structured table. Two modes:
- **Web**: agents research real entities from live web sources, verify, and populate rows
- **Synthetic**: generates rows from a schema + statistical/constraint rules without web access

Different from `deep-research` (which produces narrative reports). Use this skill when the output must be rows and columns.

---

## Phase A: Classify Mode

Before anything else, determine which mode applies:

| Signal | Use Web Mode | Use Synthetic Mode |
|--------|--------------|--------------------|
| Data exists on the public web | ✓ | |
| Need real, verified values | ✓ | |
| Need training/test data | | ✓ |
| Need controlled distributions | | ✓ |
| Data is sensitive / can't scrape | | ✓ |
| Need 1,000+ rows fast | | ✓ |
| Need <100 rows, accuracy matters | ✓ | |

If unclear, ask: **"Do you need real data from the web, or generated data that matches a schema?"**

---

## Phase B: Schema Inference

Infer schema from the user's description. Present for approval **before any research or generation**.

Schema proposal format:
```
Dataset: <name>
Mode: Web | Synthetic
Primary key: <column(s) that uniquely identify a row>

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| name | string | Entity name | "OpenAI" |
| ... | ... | ... | ... |

Suggested web sources (Web mode): [list]
Generation rules (Synthetic mode): [list]
Target row count: N
```

**Wait for approval.** User may add/remove columns, change types, adjust rules.

---

## Phase C (Web Mode): Research & Populate

### C1 — Entity Discovery

Use `WebSearch` to find a list of entities matching the dataset description. Aim for 20–50 candidates. Output a numbered list and ask: **"Does this entity list look right? Add/remove any?"**

### C2 — Fan-Out Population

For each entity, spawn an `Agent` call:

```
prompt: "Research [ENTITY] and return a JSON object with these exact fields: [SCHEMA]. 
Rules:
- Use WebFetch to verify values from primary sources
- If a value is unknown, use null — never guess
- Primary key must be unique across all rows
- Return ONLY the JSON, no prose"
```

Run agents in parallel batches of 10–15. Collect results.

### C3 — Aggregate & Deduplicate

- Drop rows where primary key is null
- Deduplicate on primary key (keep most complete row)
- Flag nulls > 30% in any column as a warning
- Sort by primary key

---

## Phase C (Synthetic Mode): Generate

### C1 — Define Generation Rules

Based on the schema, define:
- **Distributions**: numeric ranges, realistic value skew
- **Categorical pools**: enums, realistic name sets, domain-specific vocabularies
- **Constraints**: foreign key-like relationships between columns
- **Edge cases**: intentional outliers, nulls at target %, boundary values

Present rules to user. Wait for approval/adjustment.

### C2 — Generate Rows

Generate rows in batches. For large counts (>200 rows), use `Agent` sub-calls to parallelize generation:

```
prompt: "Generate [N] rows for this dataset schema: [SCHEMA].
Rules: [RULES]
Requirements:
- No duplicate primary keys
- Match type constraints exactly
- Apply edge cases: [EDGE_CASES]
- Return as JSON array only"
```

### C3 — Validate

- Check primary key uniqueness across all batches
- Verify type conformance (numbers are numbers, dates parse, etc.)
- Confirm null rate matches target
- Flag distribution anomalies

---

## Phase D: Output

Always output in this order:

1. **Summary**: row count, column count, null rates, warnings
2. **Markdown table** (first 10 rows as preview)
3. **Full CSV** — write to a file if >50 rows, or paste inline if small

```
Dataset: [name]
Rows: N | Columns: M | Mode: Web/Synthetic
Nulls: col_a=2%, col_b=0% ...
⚠️ Warnings: [any issues]

| col1 | col2 | ... |
|------|------|-----|
| ... preview rows ... |

[CSV written to ./datasets/[name]-YYYY-MM-DD.csv]
```

If the user asked for XLSX, note that Claude Code cannot write `.xlsx` directly — suggest they open the CSV in Excel or use `python -c "import pandas as pd; pd.read_csv('X').to_excel('X.xlsx')"`.

---

## Quality Rules

- **Never hallucinate web data.** If a value can't be verified, it must be null.
- **Schema must be approved before any work starts.** Don't skip Phase B.
- **Synthetic ≠ fake web.** Synthetic mode generates plausible data per rules — it does not pretend to scrape.
- **Primary key integrity is non-negotiable.** Duplicates = bad dataset.
- **Cap web fan-out at 20 agents per batch** to avoid context overload.

---

## Common Use Cases

| Description | Mode | Notes |
|-------------|------|-------|
| "AI company pricing table" | Web | Real pricing from vendor pages |
| "Competitor feature matrix" | Web | Research each competitor |
| "Synthetic user profiles for testing" | Synthetic | Define age/location/behavior distributions |
| "Training data: invoice records" | Synthetic | Controlled formats, edge cases |
| "GPU prices from major retailers" | Web | Price + availability per SKU |
| "CFO dashboard mock data" | Synthetic | Match real financial metric distributions |
| "YC companies with founding year + sector" | Web | Authoritative list from YC site |
