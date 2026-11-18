---
name: database-migration
description: "Database schema and data migrations across ORMs (Sequelize, TypeORM, Prisma) and raw SQL: zero-downtime strategies, rollback procedures, data transformation, and observability for large/live migrations. Use when migrating schemas, transforming data, planning a rollback, or monitoring a long-running or CDC-based migration."
risk: unknown
source: community
---

# Database Migration

## Use this skill when
- Migrating schema or data across ORMs, or writing raw SQL migrations
- Performing schema transformations (rename, retype, split columns)
- Moving data between databases, or a zero-downtime deployment
- Implementing rollback procedures, or monitoring a large/live migration

## Do not use skill when
- The task is unrelated to database migration

## Core rules
1. Every `up()` needs a working `down()` — test the rollback, not just the forward path.
2. Test on staging with production-shaped data volume before running on production.
3. Wrap multi-statement migrations in a transaction where the DB supports transactional DDL.
4. Back up before any destructive migration.
5. Break large changes into small, incremental, idempotent steps — re-running a migration should be safe.
6. Watch for errors/lag during the deployment, not just at the end.

## ORM Migrations
**Sequelize**:
```javascript
module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('users', {
      id: { type: Sequelize.INTEGER, primaryKey: true, autoIncrement: true },
      email: { type: Sequelize.STRING, unique: true, allowNull: false },
    });
  },
  down: async (queryInterface) => { await queryInterface.dropTable('users'); },
};
// Run: npx sequelize-cli db:migrate | Rollback: npx sequelize-cli db:migrate:undo
```
**TypeORM**: `MigrationInterface` with `up(queryRunner)`/`down(queryRunner)` methods using `queryRunner.createTable(new Table({...}))`. Run: `npm run typeorm migration:run` · Rollback: `migration:revert`.
**Prisma**: schema-first — edit `schema.prisma`, then `npx prisma migrate dev --name <name>` to generate + apply locally, `npx prisma migrate deploy` in CI/production (never `migrate dev` there).

## Schema Transformations
**Add column with default** — safe in one step for small/medium tables; for huge tables a non-volatile default avoids a full rewrite (volatile defaults like `now()` force one).

**Rename column (zero downtime, 3 phases)**:
1. Add the new column, backfill it from the old one (`UPDATE users SET full_name = name`).
2. Deploy application code that writes both, reads the new column.
3. Once fully rolled out, drop the old column in a separate migration.

**Change column type on a large table** (avoid a blocking rewrite): add a new column of the target type → backfill with a cast (`UPDATE users SET age_new = CAST(age AS INTEGER) WHERE age IS NOT NULL`) → drop the old column → rename the new one into place. Do each step as its own deploy for anything beyond a small table.

## Data Transformations
For row-by-row transforms too complex for a single `UPDATE` (e.g. splitting a free-text address into `street`/`city`/`state`), select the rows, transform in application code, and write back with parameterized per-row updates — then drop the source column only after verifying the transform. Keep the `down()` able to reconstruct the original column (e.g. `CONCAT`) in case of rollback.

## Rollback Strategies
**Transaction-based** (DBs with transactional DDL): open a transaction, perform the change(s), commit; catch and `rollback()` on any error so partial migrations never persist.

**Checkpoint-based** (for changes that can't be wrapped in one transaction, or cross-statement verification): snapshot the table (`CREATE TABLE users_backup AS SELECT * FROM users`) before mutating, verify post-migration invariants (e.g. no unexpected NULLs), and restore from the backup table on verification failure. Drop the backup only after the migration is confirmed healthy.

## Zero-Downtime Migrations (expand-contract / blue-green)
1. **Expand**: add new column/table, backward-compatible with old code.
2. **Migrate writes**: deploy code that writes to both old and new.
3. **Backfill**: bulk-copy existing data into the new shape.
4. **Migrate reads**: deploy code that reads from the new column/table.
5. **Contract**: remove the old column/table once nothing references it.
Never collapse these into one deploy — each phase must be independently safe to roll back from.

## Cross-Database Differences
When a migration must run against more than one engine (e.g. Postgres and MySQL), branch on dialect inside the migration (`queryInterface.sequelize.getDialect()`) rather than writing two migration files that can drift — e.g. `JSONB` on Postgres vs `JSON` on MySQL for the same logical column.

## Observability for Large/Live Migrations
For migrations too large to run inline (bulk backfills, CDC-based cutovers), instrument them rather than running blind:
- **CDC cutover**: use Debezium (or equivalent) to stream ongoing changes from source to target during a long backfill, so the target stays current until final cutover — `connector.class: io.debezium.connector.postgresql.PostgresConnector` with the `pgoutput` logical-replication plugin for Postgres sources.
- **Metrics to track**: rows migrated/sec (vs. expected throughput), error rate, replication/consumer lag (seconds and message count behind source), migration duration. Expose as Prometheus counters/gauges/histograms (`migration_rows_total`, `migration_data_lag_seconds`, `migration_errors_total`) and chart in Grafana.
- **Anomaly thresholds**: alert (not just log) when throughput drops below ~50% of expected, or error rate exceeds ~1% — catching a stalled or silently-failing migration early is cheaper than discovering it at cutover.
- **Alerting channels**: route critical migration alerts to the same on-call path as production incidents (Slack/email/PagerDuty) — a migration running unattended overnight needs to be able to page someone.
- Treat a migration dashboard as throwaway infra: stand it up for the migration window, verify cutover, then tear it down — don't let it become permanent monitoring debt.

## Best Practices
Always provide a rollback · test the rollback itself, not just forward · use transactions where available · back up before migrating · prefer many small steps over one large one · document the why, not just the what · make migrations idempotent/rerunnable.

## Common Pitfalls
Not testing rollback procedures · breaking changes with no zero-downtime plan · forgetting NULL handling when backfilling · ignoring index cost on large backfills · ignoring foreign key constraints during multi-table changes · migrating too much data in a single statement/transaction.
