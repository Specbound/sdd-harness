---
name: database-design
description: "Database design and operations decision-making: choosing a database/ORM, schema design, indexing, migrations, query tuning, and production reliability (backups, HA/DR, connection pooling). Use when picking a database technology, designing a schema, planning a migration, or setting up backups/replication/monitoring."
allowed-tools: Read, Write, Edit, Glob, Grep
risk: unknown
---

# Database Design

> **Learn to THINK, not copy SQL patterns.**

## Selective Reading Rule
**Read ONLY files relevant to the request!** Check the content map, find what you need.

| File | Description | When to Read |
|------|-------------|--------------|
| `database-selection.md` | PostgreSQL vs Neon vs Turso vs SQLite | Choosing database |
| `orm-selection.md` | Drizzle vs Prisma vs Kysely | Choosing ORM |
| `schema-design.md` | Normalization, PKs, relationships | Designing schema |
| `indexing.md` | Index types, composite indexes | Performance tuning |
| `optimization.md` | N+1, EXPLAIN ANALYZE | Query tuning |
| `migrations.md` | Safe migrations, serverless DBs | Schema changes |

---

## Core Principle
- ASK the user for database preferences when unclear.
- Choose database/ORM based on CONTEXT — don't default to PostgreSQL for everything.
- Recommend schema/architecture; don't execute migrations or modify infra unless explicitly asked.

## Decision Checklist
Before designing a schema:
- [ ] Asked user about database preference?
- [ ] Chosen database for THIS context (not habit)?
- [ ] Considered deployment environment (serverless, embedded, self-hosted)?
- [ ] Planned index strategy?
- [ ] Defined relationship types?
- [ ] Planned backup/replication if this is a production system?

## Technology Selection (quick guide)
- **Relational (Postgres/MySQL)**: default for transactional apps needing joins, constraints, multi-row ACID transactions.
- **SQLite/Turso/libSQL**: embedded, edge, or low-traffic apps where a managed server is overkill — not for high write concurrency.
- **Document (MongoDB, DynamoDB)**: schema that changes often, denormalized read patterns, very high write throughput where joins aren't needed.
- **Time-series (TimescaleDB, InfluxDB, ClickHouse)**: metrics/events at high ingest rate with time-range queries and retention/rollup needs.
- **Key trade-off to name explicitly when picking**: consistency vs availability under partition (CAP), and operational complexity of running/upgrading the chosen engine vs a managed Postgres.
- Don't introduce a second database technology for one feature — the operational cost (backups, monitoring, on-call familiarity) usually outweighs the query-shape benefit until scale actually demands it.

## Operations & Reliability
- **Backups**: automate full + incremental/WAL backups; a backup that has never been restored is not a backup — test restores on a schedule, not just after an incident.
- **Replication/HA**: async replicas for read scaling and failover (small data-loss window on failover); sync replication only when zero data loss is a hard requirement (adds write latency). Define RPO (how much data loss is acceptable) and RTO (how long to recover) explicitly before choosing a strategy.
- **Connection pooling**: use PgBouncer (Postgres) / ProxySQL or MySQL Router (MySQL) in front of the app — size the pool to the DB's connection ceiling, not the app's thread count.
- **Monitoring**: track replication lag, connection pool utilization, slow-query log / `pg_stat_statements`, and disk growth — alert on trend, not just threshold, so capacity planning happens before exhaustion.
- **Migrations in production**: run schema changes through CI with a rollback path; avoid long table locks (`CREATE INDEX CONCURRENTLY`, batched backfills) — see `migrations.md`.

## Anti-Patterns
- Default to PostgreSQL for simple apps (SQLite may suffice)
- Skip indexing, or index everything indiscriminately
- Use SELECT * in production
- Store JSON when structured data is better
- Ignore N+1 queries
- Treat an untested backup as a working backup
- Add a second database technology before the first one's limits are actually measured
