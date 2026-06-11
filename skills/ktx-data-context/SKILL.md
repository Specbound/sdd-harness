---
name: ktx-data-context
description: Use when building a data agent or adding analytics capability to a project that queries a warehouse. Guides ktx setup (semantic layer + MCP server) so agents get governed SQL instead of schema guesses.
---

# ktx — Context Layer for Data Agents

ktx (Kaelio, Apache 2.0) sits between a data warehouse and AI agents. Instead of letting agents guess table names, join logic, and metric definitions, ktx serves approved context — reviewed and committed to git like code.

**Repo:** https://github.com/Kaelio/ktx

## When to Activate

- Building an agent that queries a warehouse (Snowflake, BigQuery, Redshift, PostgreSQL, ClickHouse, Databricks)
- LLM is hallucinating joins, wrong metric names, or bad aggregations
- Project has dbt, LookML, or a BI tool and agents need to consume those definitions correctly
- Adding an analytics or CFO-insights capability to a skill/agent (e.g. `cfo-insights/`)
- User asks how to give Claude Code or a custom agent correct metric logic without hardcoding SQL

## Do Not Activate

- Agent doesn't query structured warehouse data (chat, code gen, document processing → use `rag-architect`)
- Project already has Cube.dev or dbt Semantic Layer covering the same ground
- Prototype / one-shot query — raw SQL is fine, ktx overhead not worth it

---

## Architecture

Three loops, always active together:

```
[Warehouse / dbt / BI tools]
         │
         ▼ ktx build
[YAML/Markdown context files] ← git-reviewed, team-approved
         │
         ▼ ktx serve (MCP)
[Agent / Claude Code] ──────► [ktx MCP server] ──► compiled SQL ──► warehouse
```

---

## Phase 1: Install & Connect

```bash
# Install (pick one)
pip install ktx
# or
npm install -g ktx

# Connect to warehouse — interactive credential setup
ktx init
```

---

## Phase 2: Build Context

```bash
# Ingest warehouse schema + all connected sources → YAML/Markdown
ktx build

# Or rebuild a specific source
ktx build --source dbt
ktx build --source looker
ktx build --source metabase
```

Output: `ktx/` directory of YAML/Markdown files — tables, metrics, joins, caveats, business definitions.

**Commit these files.** They are the governed context, equivalent to code:

```bash
git add ktx/
git commit -m "feat: initial ktx context layer"
```

---

## Phase 3: Wire MCP Server

**For Claude Code projects** — add to `.claude/settings.json`:

```json
{
  "mcpServers": {
    "ktx": {
      "command": "ktx",
      "args": ["serve", "--stdio"],
      "env": {}
    }
  }
}
```

**For custom agents** using Python MCP SDK:

```python
# Agent can now call:
# ktx_query("what was revenue by region last quarter?")
# ktx_schema("orders")
# ktx_metrics()
```

**Start server standalone:**

```bash
ktx serve
# → MCP server on localhost:8765
```

---

## Phase 4: Review Loop

Every `ktx build` produces git-diffable YAML. Treat changes like code reviews:

```bash
git diff ktx/         # see what changed in metric definitions
git add ktx/ && git commit -m "update: revenue metric now excludes refunds"
```

This is the governance layer — agents always work from approved context, never stale guesses.

---

## Context File Shape

```yaml
# ktx/metrics/revenue.yaml
name: revenue
description: Total recognized revenue, net of refunds
grain: [date, region, product_line]
sql: |
  SELECT
    date_trunc('day', o.created_at) AS date,
    reg.name                        AS region,
    p.category                      AS product_line,
    SUM(o.amount - COALESCE(r.amount, 0)) AS revenue
  FROM orders o
  LEFT JOIN refunds   r   ON o.id = r.order_id
  LEFT JOIN regions   reg ON o.region_id = reg.id
  LEFT JOIN products  p   ON o.product_id = p.id
caveats:
  - Excludes orders with status = 'cancelled'
  - Refunds applied at settlement date, not order date
```

---

## Decision Matrix

| Situation | Use |
|---|---|
| LLM guesses join logic / metric names | ktx semantic layer |
| Multiple agents querying same warehouse | Centralize context in ktx |
| dbt already exists | `ktx build --source dbt` — reuses existing definitions |
| Only documents, no warehouse | `rag-architect` |
| Warehouse + documents | ktx for structured + `rag-implementation` for unstructured |
| Prototype / one-off query | Raw SQL — ktx adds overhead not worth it |
| Already have Cube.dev / dbt Semantic Layer | Skip ktx |

---

## Supported Integrations

| Category | Tools |
|---|---|
| Warehouses | Snowflake, BigQuery, Redshift, PostgreSQL, Databricks, ClickHouse |
| Modeling | dbt, LookML |
| BI tools | Metabase, Looker, Tableau, Power BI |
| Agents | Claude Code, Cursor, Codex, LangChain, custom MCP agents |
| Business tools | Notion, Slack, Salesforce, GitHub, Stripe |

---

## Quick Checklist Before Using

- [ ] Warehouse credentials available for `ktx init`
- [ ] dbt / LookML / BI source identified (if applicable)
- [ ] `ktx/` directory will be committed to the project repo
- [ ] MCP server entry added to `.claude/settings.json`
- [ ] Agents instructed to call `ktx_query` instead of writing raw SQL

---

## Related Skills

- `rag-architect` — unstructured/document retrieval (not warehouse queries)
- `rag-implementation` — downstream RAG pipeline after ktx
- `database-architect` — warehouse schema design
- `database-optimizer` — query performance tuning
- `structured-web-dataset` — generating datasets, not querying existing ones
- `dbt-transformation-patterns` — dbt modeling that feeds ktx
