---
name: sql-pro
description: "Write and tune SQL: reading EXPLAIN plans, index selection, JOIN/subquery/window-function rewrites, pagination, batch operations, materialized views. Use when debugging a slow query, designing indexes, resolving N+1 queries, or writing advanced analytical SQL (CTEs, window functions)."
metadata:
  model: inherit
risk: unknown
source: community
---

# SQL Pro

## Use this skill when
- Writing or speeding up complex SQL (analytics, reporting, OLTP hot paths)
- Tuning query performance via indexes or execution plans
- Resolving N+1 queries, slow pagination, or correlated-subquery performance
- Designing OLTP/OLAP query patterns (window functions, CTEs, materialized views)

## Do not use skill when
- You only need ORM-level guidance, not SQL itself
- The system is non-SQL/document-only, or you cannot access query plans/schema

## Instructions
1. Define query goals, constraints, and expected output shape.
2. Inspect schema, statistics, and access paths before guessing at fixes.
3. Change one thing at a time and validate with `EXPLAIN ANALYZE` — never assume.
4. Verify correctness (not just speed) and test under realistic data volume/load.

## Safety
- Avoid heavy ad-hoc queries on production without `LIMIT`/safeguards; use read replicas for exploratory analysis.

## Reading EXPLAIN
```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'user@example.com';
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT u.*, o.order_total
FROM users u JOIN orders o ON u.id = o.user_id
WHERE u.created_at > NOW() - INTERVAL '30 days';
```
Watch for: `Seq Scan` on a large table (missing index), `Index Only Scan` (best case), join method (`Nested Loop` fine for small sets, `Hash Join` for larger, `Merge Join` for pre-sorted), `Buffers: read >> hit` (cold cache), estimated `Rows` vs `Actual` diverging a lot (stale statistics — run `ANALYZE`).

## Index selection
- **B-Tree** (default): equality/range. **Hash**: equality only. **GIN**: full-text, arrays, JSONB. **GiST**: geometric/full-text. **BRIN**: huge, naturally-ordered tables (minimal storage).
- Composite index column order matters — leftmost prefix must match the query's equality predicates; put the most selective/frequent filter first.
- Partial (`WHERE status = 'active'`), expression (`(LOWER(email))`), and covering (`INCLUDE (name, created_at)`) indexes each solve a narrower problem than a plain index — use the narrowest that fits.
- Extra indexes slow every write; drop indexes with `idx_scan = 0` in `pg_stat_user_indexes`.

## Query rewrite patterns
**Select only needed columns** — `SELECT *` fetches unused data and defeats covering/index-only scans.

**Don't wrap indexed columns in functions** unless you've built a matching expression/functional index:
```sql
-- Bad: LOWER() on every row scanned defeats a plain index on email
SELECT * FROM users WHERE LOWER(email) = 'user@example.com';
-- Fix: CREATE INDEX ON users (LOWER(email));
```

**Explicit JOIN, not comma-join + WHERE** — comma joins invite accidental cross products; filter the smaller side before joining when the planner doesn't push the predicate down itself.

**Correlated subquery → JOIN/window function**:
```sql
-- Bad: subquery runs once per outer row
SELECT u.name, (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) order_count FROM users u;
-- Better: aggregate join
SELECT u.name, COUNT(o.id) order_count FROM users u LEFT JOIN orders o ON o.user_id = u.id GROUP BY u.id, u.name;
-- Or a window function when you need the detail rows too
SELECT u.name, COUNT(o.id) OVER (PARTITION BY u.id) order_count FROM users u LEFT JOIN orders o ON o.user_id = u.id;
```

**CTEs** for readability on multi-stage aggregation — name each intermediate result set as a step instead of nesting subqueries three deep. Recursive CTEs (`WITH RECURSIVE`) for hierarchical/graph-shaped data.

## N+1 elimination
Batch-load with `IN`/`= ANY` or a single `JOIN` instead of one query per loop iteration:
```sql
SELECT u.id, u.name, o.id order_id, o.total
FROM users u LEFT JOIN orders o ON u.id = o.user_id
WHERE u.id IN (1,2,3,4,5);
```
In app code, group the batch-loaded rows by foreign key client-side rather than re-querying per parent.

## Pagination
`OFFSET` rescans every skipped row — slows sharply at depth. Use cursor/keyset pagination instead:
```sql
SELECT * FROM users WHERE (created_at, id) < ('2024-01-15 10:30:00', 12345)
ORDER BY created_at DESC, id DESC LIMIT 20;
-- supporting index:
CREATE INDEX idx_users_cursor ON users (created_at DESC, id DESC);
```

## Aggregation
- Exact `COUNT(*)` on a huge table is slow — filter first, or use `pg_class.reltuples` for an estimate when exactness isn't required.
- Filter (`WHERE`) before `GROUP BY`/`HAVING` where semantically equivalent — reduces rows the aggregate has to touch; back it with a composite index on `(group_col, filter_col)`.

## Batch operations
```sql
-- Multi-row INSERT beats one INSERT per row
INSERT INTO users (name, email) VALUES ('Alice','a@x.com'), ('Bob','b@x.com');
-- COPY for bulk loads (Postgres)
COPY users (name, email) FROM '/path/users.csv' CSV HEADER;
-- Batch UPDATE via temp table for large sets
CREATE TEMP TABLE updates (id INT, new_status TEXT);
INSERT INTO updates VALUES (1,'active'), (2,'active');
UPDATE users u SET status = t.new_status FROM updates t WHERE u.id = t.id;
```

## Materialized views
Pre-compute expensive aggregations; index the materialized result like a table; refresh on a schedule or trigger:
```sql
CREATE MATERIALIZED VIEW user_order_summary AS
SELECT u.id, u.name, COUNT(o.id) total_orders, SUM(o.total) total_spent
FROM users u LEFT JOIN orders o ON u.id = o.user_id GROUP BY u.id, u.name;
CREATE INDEX ON user_order_summary (total_spent DESC);
REFRESH MATERIALIZED VIEW CONCURRENTLY user_order_summary; -- avoids locking readers
```

## Partitioning (large/time-series tables)
`PARTITION BY RANGE (created_at)` with per-period child tables lets the planner prune partitions outside the query's date range, scanning only the relevant slice instead of the whole table. Use for tables where a single dimension (time, tenant, region) consistently appears in the `WHERE` clause.

## Query hints
```sql
SET max_parallel_workers_per_gather = 4;     -- Postgres: encourage parallel scan
SET enable_nestloop = OFF;                   -- Postgres: force a different join strategy for A/B comparison
SELECT * FROM users USE INDEX (idx_users_email) WHERE email = '...';  -- MySQL index hint
```
Treat hints as a diagnostic tool (compare plans), not a permanent fix — a hint that's right today can be wrong after data grows or stats change.

## Common pitfalls
Too many indexes (slows every write) · unused indexes (wasted space + write cost) · implicit type conversion in `WHERE` (silently defeats an index) · `OR` across different columns (planner often can't use either index) · `LIKE '%abc'` leading-wildcard (sequential scan unless trigram/GIN-indexed) · function on an indexed column without a matching expression index.

## Monitoring
```sql
-- Slowest queries by mean time (needs pg_stat_statements)
SELECT query, calls, total_exec_time, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;
-- Tables with heavy sequential scan (candidate for a new index)
SELECT schemaname, relname, seq_scan, seq_tup_read FROM pg_stat_user_tables WHERE seq_scan > 0 ORDER BY seq_tup_read DESC LIMIT 10;
-- Unused indexes (candidate for removal)
SELECT schemaname, relname, indexrelname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0;
```

## Best practices
Index selectively, not exhaustively · keep statistics fresh (`ANALYZE` after bulk changes) · prefer the smallest sufficient data type · balance normalization against proven read-performance needs · cache at the application layer for hot, expensive-to-compute results · pool connections rather than opening one per request · schedule routine `VACUUM`/`ANALYZE`/`REINDEX` maintenance.
