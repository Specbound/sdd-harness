---
name: data-and-db
description: Databases and data systems: schema/index design, SQL tuning, migrations, Postgres/NoSQL/vector, pipelines/ETL, event-sourcing. Use when designing schemas, tuning queries, or building data flows.
---

# data-and-db — domain router

This is a routing skill for the **data-and-db** domain. It holds no technique itself — it lists the sub-skills in this domain so you can load the right one(s).

**How to use:** scan the table, then READ the SKILL.md at each path that genuinely helps the task with the Read tool. **Load as many as the task needs — not just one.** A task that spans sub-skills (e.g. build + test, or debug + fix infra) should pull every relevant row. Skip the rest.


| sub-skill | what it covers | path |
|---|---|---|
| `airflow-dag-patterns` | Build production Apache Airflow DAGs with best practices for operators, sensors, testing, and deployment. Use when creating data pipelines, orchestrating workfl | `~/.claude/skill-library/airflow-dag-patterns/SKILL.md` |
| `algolia-search` | Expert patterns for Algolia search implementation, indexing strategies, React InstantSearch, and relevance tuning Use when: adding search to, algolia, instantse | `~/.claude/skill-library/algolia-search/SKILL.md` |
| `backtesting-frameworks` | Build robust backtesting systems for trading strategies with proper handling of look-ahead bias, survivorship bias, and transaction costs. Use when developing t | `~/.claude/skill-library/backtesting-frameworks/SKILL.md` |
| `cqrs-implementation` | Implement Command Query Responsibility Segregation for scalable architectures. Use when separating read and write models, optimizing query performance, or build | `~/.claude/skill-library/cqrs-implementation/SKILL.md` |
| `csv-data-summarizer` | Analyze a CSV end-to-end without asking questions — pandas stats, missing-data audit, and only the charts the data supports. Use when the user shares or referen | `~/.claude/skill-library/csv-data-summarizer/SKILL.md` |
| `data-engineer` | Build scalable data pipelines, modern data warehouses, and | `~/.claude/skill-library/data-engineer/SKILL.md` |
| `data-engineering-data-driven-feature` | Build features guided by data insights, A/B testing, and continuous measurement using specialized agents for analysis, implementation, and experimentation. | `~/.claude/skill-library/data-engineering-data-driven-feature/SKILL.md` |
| `data-engineering-data-pipeline` | You are a data pipeline architecture expert specializing in scalable, reliable, and cost-effective data pipelines for batch and streaming data processing. | `~/.claude/skill-library/data-engineering-data-pipeline/SKILL.md` |
| `data-quality-frameworks` | Implement data quality validation with Great Expectations, dbt tests, and data contracts. Use when building data quality pipelines, implementing validation rule | `~/.claude/skill-library/data-quality-frameworks/SKILL.md` |
| `data-storytelling` | Transform data into compelling narratives using visualization, context, and persuasive structure. Use when presenting analytics to stakeholders, creating data r | `~/.claude/skill-library/data-storytelling/SKILL.md` |
| `database-cloud-optimization-cost-optimize` | You are a cloud cost optimization expert specializing in reducing infrastructure expenses while maintaining performance and reliability. Analyze cloud spending, | `~/.claude/skill-library/database-cloud-optimization-cost-optimize/SKILL.md` |
| `database-design` | Database design and operations decision-making: choosing a database/ORM, schema design, indexing, migrations, query tuning, and production reliability (backups, | `~/.claude/skill-library/database-design/SKILL.md` |
| `database-migration` | Database schema and data migrations across ORMs (Sequelize, TypeORM, Prisma) and raw SQL: zero-downtime strategies, rollback procedures, data transformation, an | `~/.claude/skill-library/database-migration/SKILL.md` |
| `dbt-transformation-patterns` | Master dbt (data build tool) for analytics engineering with model organization, testing, documentation, and incremental strategies. Use when building data trans | `~/.claude/skill-library/dbt-transformation-patterns/SKILL.md` |
| `event-sourcing-architect` | Expert in event sourcing, CQRS, and event-driven architecture patterns. Masters event store design, projection building, saga orchestration, and eventual consis | `~/.claude/skill-library/event-sourcing-architect/SKILL.md` |
| `event-store-design` | Design and implement event stores for event-sourced systems. Use when building event sourcing infrastructure, choosing event store technologies, or implementing | `~/.claude/skill-library/event-store-design/SKILL.md` |
| `hybrid-search-implementation` | Combine vector and keyword search for improved retrieval. Use when implementing RAG systems, building search engines, or when neither approach alone provides su | `~/.claude/skill-library/hybrid-search-implementation/SKILL.md` |
| `nosql-expert` | Expert guidance for distributed NoSQL databases (Cassandra, DynamoDB). Focuses on mental models, query-first modeling, single-table design, and avoiding hot par | `~/.claude/skill-library/nosql-expert/SKILL.md` |
| `postgresql` | PostgreSQL schema design, indexing, data types, RLS, connection pooling, locking, query diagnostics, and performance tuning. Use when designing or reviewing a P | `~/.claude/skill-library/postgresql/SKILL.md` |
| `prisma-expert` | Prisma ORM expert for schema design, migrations, query optimization, relations modeling, and database operations. Use PROACTIVELY for Prisma schema issues, migr | `~/.claude/skill-library/prisma-expert/SKILL.md` |
| `projection-patterns` | Build read models and projections from event streams. Use when implementing CQRS read sides, building materialized views, or optimizing query performance in eve | `~/.claude/skill-library/projection-patterns/SKILL.md` |
| `risk-metrics-calculation` | Calculate portfolio risk metrics including VaR, CVaR, Sharpe, Sortino, and drawdown analysis. Use when measuring portfolio risk, implementing risk limits, or bu | `~/.claude/skill-library/risk-metrics-calculation/SKILL.md` |
| `saga-orchestration` | Implement saga patterns for distributed transactions and cross-aggregate workflows. Use when coordinating multi-step business processes, handling compensating t | `~/.claude/skill-library/saga-orchestration/SKILL.md` |
| `semantic-data-pipeline` | Use when writing batch LLM transformation over many rows/records (extract-to-schema, classify, NL-filter, reduce/summarize) that must be reproducible — treat it | `~/.claude/skill-library/semantic-data-pipeline/SKILL.md` |
| `spark-optimization` | Optimize Apache Spark jobs with partitioning, caching, shuffle optimization, and memory tuning. Use when improving Spark performance, debugging slow jobs, or sc | `~/.claude/skill-library/spark-optimization/SKILL.md` |
| `sql-pro` | Write and tune SQL: reading EXPLAIN plans, index selection, JOIN/subquery/window-function rewrites, pagination, batch operations, materialized views. Use when d | `~/.claude/skill-library/sql-pro/SKILL.md` |
| `structured-web-dataset` | Build structured tabular datasets from natural language descriptions — either by researching live web data via parallel agents, or by generating synthetic data  | `~/.claude/skill-library/structured-web-dataset/SKILL.md` |
| `using-neon` | Neon serverless Postgres: connection methods (pooled vs direct), PgBouncer limits, Prisma/Drizzle integration, branching, autoscaling. Use when setting up a Neo | `~/.claude/skill-library/using-neon/SKILL.md` |

_28 sub-skills. If none fit, the task likely belongs to another domain router._
