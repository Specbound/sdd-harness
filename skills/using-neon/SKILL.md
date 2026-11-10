---
name: using-neon
description: "Neon serverless Postgres: connection methods (pooled vs direct), PgBouncer limits, Prisma/Drizzle integration, branching, autoscaling. Use when setting up a Neon database, choosing a driver/connection string, configuring migrations, or debugging Neon-specific connection errors."
source: "https://github.com/neondatabase/agent-skills/tree/main/skills/neon-postgres"
risk: safe
---

# Neon Serverless Postgres

Neon separates compute and storage to offer autoscaling, branching, instant restore, and scale-to-zero. It is fully Postgres-compatible — works with any language, framework, or ORM that supports Postgres.

## Use this skill when
- Setting up a Neon project, database, or connection string
- Choosing a connection method/driver for a given runtime (serverless/edge vs long-lived server)
- Configuring Prisma/Drizzle migrations against Neon
- Using Neon features: branching, autoscaling, scale-to-zero, instant restore
- Debugging connection-limit or pooling errors

## Always verify against live docs
Neon ships features fast — don't guess doc URLs or API shapes from memory.
```bash
curl https://neon.com/llms.txt                                   # index of all docs
curl -H "Accept: text/markdown" https://neon.com/docs/<path>      # fetch a specific page as markdown
```

## Two connection strings — pooled vs direct
Every Neon database exposes both; use the right one per operation:
- **Pooled** (`-pooler` in the hostname, routes through PgBouncer): application runtime queries. Supports up to 10,000 concurrent client connections; 7 are reserved for the Neon superuser. Pooled connections still consume underlying Postgres connections, so this isn't unlimited headroom.
- **Direct** (no `-pooler`): required for DDL/migrations (`prisma migrate`, `drizzle-kit push`, advisory-lock-based migration tools) — pooled transaction-mode connections can break session state these tools rely on.

Prisma: set `DATABASE_URL` to the pooled string for `PrismaClient`, `DIRECT_URL` to the direct string for `prisma migrate`.

## Choosing a driver
| Runtime | Driver | Notes |
|---|---|---|
| Edge/serverless (Vercel Edge, Cloudflare Workers, no TCP) | `@neondatabase/serverless` — `neon-http` | One-off queries over HTTP; fastest for single queries, no connection to hold open |
| Edge/serverless needing transactions/sessions | `@neondatabase/serverless` — `neon-serverless` (WebSocket) | Use when you need multi-statement transactions, not just single queries |
| Long-lived server (Node server, container, Lambda with TCP) | standard `pg`/`postgres.js` over the pooled connection string | No HTTP/WebSocket overhead when TCP is available |
| Drizzle ORM | pick `neon-http` or `neon-serverless` per the table above | Drizzle's Neon adapters wrap the same two driver modes |

## Core workflow
1. Create project/branch, grab the pooled and direct connection strings from the Neon console or API.
2. Pick the driver/connection string per the tables above for the target runtime.
3. Run migrations against the **direct** connection; point the app at the **pooled** connection.
4. Use branching for per-PR or per-preview databases (instant copy-on-write, not a full data copy); scale-to-zero suspends idle compute automatically — first query after idle has a brief cold-start.

## Managing Neon programmatically
- **Neon CLI** (`neon init`, `neon branches create`, etc.) for local/CI scripting.
- **Platform API** (REST) for anything not covered by CLI/SDKs; TypeScript SDK `@neondatabase/api-client`, Python SDK `neon-api`.
- **Neon Auth** (`@neondatabase/auth`) for auth only; **Neon JS SDK** (`@neondatabase/neon-js`) for auth + a PostgREST-style data API.
- **MCP server / VS Code extension** available for agent and IDE integration — fetch current setup steps from the docs index above rather than assuming flags/config shape.

## Sharp edges
- Don't run migrations over the pooled connection — session-level operations (advisory locks, prepared statements some tools rely on) can silently misbehave under PgBouncer transaction mode.
- Pooled connections still count against the underlying Postgres `max_connections` — pooling raises client-side concurrency, it doesn't remove the server-side ceiling.
- Cold start after scale-to-zero adds latency to the first query on an idle branch — don't assume uniform query latency in tests run against an idle database.
- Branches are compute+storage copies of a parent at a point in time, not a live replica — write to the right branch.
