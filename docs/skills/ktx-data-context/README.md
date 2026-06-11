# ktx Data Context Skill

Semantic layer for AI data agents using [ktx](https://github.com/Kaelio/ktx) (Kaelio, Apache 2.0). Invoke when building any agent that queries a warehouse or when LLM-generated SQL is hallucinating joins and metric definitions.

**Skill file:** `~/.claude/skills/ktx-data-context/SKILL.md`

---

## What It Does

Guides the full ktx integration workflow:

1. **Install & Connect** — `ktx init` with warehouse credentials
2. **Build context** — `ktx build` ingests warehouse schema + dbt/LookML/BI tools into git-committed YAML/Markdown
3. **Wire MCP server** — adds `ktx serve --stdio` to `.claude/settings.json` so Claude Code agents call `ktx_query` instead of guessing SQL
4. **Review loop** — every context change is a git diff your team approves before agents see it

---

## Problem It Solves

Without a semantic layer, agents guess from table names:

```
❌ Agent: SELECT SUM(amount) FROM orders WHERE month = 6
         -- wrong: ignores refunds, wrong grain, missing region join
```

With ktx, agents query approved context:

```
✅ ktx_query("revenue by region last month")
   → resolves metric definition → compiles correct SQL → executes
```

---

## Activation

Fires when:
- Building an agent that queries a data warehouse
- LLM is hallucinating joins, metric names, or aggregations
- Project has dbt/LookML/BI tools needing agent consumption
- Adding analytics capability to a skill (e.g. `cfo-insights/`)

Direct invocation:

```
Skill("ktx-data-context")
```

---

## MCP Server Config

Add to project `.claude/settings.json`:

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

A commented-out template block is also available at the end of `templates/settings.json.template`.

---

## Supported Warehouses

Snowflake, BigQuery, Redshift, PostgreSQL, Databricks, ClickHouse

## Supported Sources

dbt, LookML, Metabase, Looker, Tableau, Power BI

---

## Related Skills

- `rag-architect` — document/unstructured retrieval (not warehouse queries)
- `rag-implementation` — downstream RAG pipeline
- `database-architect` — warehouse schema design
- `database-optimizer` — query performance
- `dbt-transformation-patterns` — dbt modeling that feeds ktx
- `structured-web-dataset` — generating structured datasets

---

## Source

Extracted from [github.com/Kaelio/ktx](https://github.com/Kaelio/ktx) on 2026-06-11.  
Apache 2.0 license. YC-backed.
