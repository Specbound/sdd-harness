---
name: automate-whatsapp
description: "Build and debug Kapso WhatsApp automations: workflow graphs, triggers, executions, functions, D1 tables. Use for Kapso or WhatsApp workflow work."
source: "https://github.com/gokapso/agent-skills/tree/master/skills/automate-whatsapp"
risk: safe
---

# Automate WhatsApp (Kapso)

Build and run WhatsApp automations on Kapso: workflow CRUD, graph edits, triggers, executions, function deploy, app integrations, and D1 database operations.

## Before running any command — check the toolchain is present

**This skill ships as `SKILL.md` only.** The `scripts/`, `references/`, and `assets/`
directories that the commands below invoke are **not installed here**. Running
`node scripts/<anything>.js` as-is fails with `Cannot find module`.

```bash
ls scripts/get-graph.js 2>/dev/null || echo "NOT INSTALLED — fetch the toolchain first"
```

If it is missing, fetch the upstream skill directory (see `source:` in the frontmatter)
into the skill folder and run `npm i` there once. Everything below assumes that has
happened. If you cannot fetch it, say so and fall back to the Kapso Platform API
directly — do not report a `scripts/` command as run when it was not.

## Setup

Env vars:
- `KAPSO_API_BASE_URL` — host only, no `/platform/v1` suffix
- `KAPSO_API_KEY`

## Workflows

### Edit a workflow graph

1. Fetch graph: `node scripts/get-graph.js <workflow_id>` — note the `lock_version`
2. Edit the JSON (see Graph rules)
3. Validate: `node scripts/validate-graph.js --definition-file <path>`
4. Update: `node scripts/update-graph.js <workflow_id> --expected-lock-version <n> --definition-file <path>`
5. Re-fetch to confirm

For small edits use `edit-graph.js` with `--old-file` / `--new-file` instead.
On a `lock_version` conflict: re-fetch, re-apply the change, retry with the new version.
Never retry with the stale one.

### Manage triggers

1. List: `node scripts/list-triggers.js <workflow_id>`
2. Create: `node scripts/create-trigger.js <workflow_id> --trigger-type <type> --phone-number-id <id>`
3. Toggle: `node scripts/update-trigger.js --trigger-id <id> --active true|false`
4. Delete: `node scripts/delete-trigger.js --trigger-id <id>`

For `inbound_message` triggers, get `phone_number_id` first via
`node scripts/list-whatsapp-phone-numbers.js`.

### Debug an execution

1. `node scripts/list-executions.js <workflow_id>`
2. `node scripts/get-execution.js <execution-id>`
3. `node scripts/get-context-value.js <execution-id> --variable-path vars.foo`
4. `node scripts/list-execution-events.js <execution-id>`

Also available: `update-execution-status.js` (force state), `resume-execution.js`.

### Create and deploy a function

1. Write the code against the handler contract below
2. `node scripts/create-function.js --name <name> --code-file <path>`
3. `node scripts/deploy-function.js --function-id <id>`
4. `node scripts/get-function.js --function-id <id>` to verify

Also available: `update-function.js`, `invoke-function.js`, `list-function-invocations.js`.

### Agent node with app integrations

1. `node scripts/list-provider-models.js` — find the model
2. `node scripts/list-accounts.js --app-slug <slug>` — take `pipedream_account_id`
3. `node scripts/search-actions.js --query <word> --app-slug <slug>` — `action_id` is the `key`
4. `node scripts/create-integration.js --action-id <id> --app-slug <slug> --account-id <id> --configured-props <json>`
5. Attach to the agent node via `flow_agent_app_integration_tools`

Also available: `list-apps.js`, `get-action-schema.js`, `create-connect-token.js`,
`configure-prop.js`, `reload-props.js`, `list-integrations.js`, `update-integration.js`,
`delete-integration.js`.

### Database (D1)

`list-tables.js` → `get-table.js` (schema + sample rows) → `query-rows.js --table <name> --filters <json>`,
then `create-row.js` / `update-row.js` / `upsert-row.js` / `delete-row.js`.

Raw SQL execution is **not** supported through the Platform API.

### Explore the API surface

```bash
node scripts/openapi-explore.mjs --spec workflows search "variables"
node scripts/openapi-explore.mjs --spec workflows op getWorkflowVariables
node scripts/openapi-explore.mjs --spec platform op queryDatabaseRows
```

Use this rather than guessing an endpoint.

## Graph rules

- Exactly one start node, with `id` = `start`
- Never change an existing node ID
- New node IDs use `{node_type}_{timestamp_ms}`
- Non-decide nodes have 0 or 1 outgoing `next` edge
- Decide edge labels must match `conditions[].label` exactly
- Edge keys are `source` / `target` / `label` — **not** `from` / `to`

## Function contract

```js
async function handler(request, env) {
  const body = await request.json();
  // env.KV and env.DB are available
  return new Response(JSON.stringify({ result: "ok" }));
}
```

- No `export`, no `export default`, no arrow function at the top level
- Must return a `Response`

## Execution context

Four top-level keys, always:
- `vars` — user-defined variables
- `system` — system variables
- `context` — channel data
- `metadata` — request metadata

## Known limits

- Variable CRUD (`variables-set.js`, `variables-delete.js`) is blocked — the Platform API does not support it
- Raw SQL is not exposed
- Prefer file paths over inline JSON (`--definition-file`, `--code-file`) — inline JSON hits shell quoting limits fast

## Related skills

- `observe-whatsapp` — debugging, logs, health checks (same Kapso toolchain, same missing-`scripts/` caveat)
- `integrate-whatsapp` — onboarding, webhooks, messaging, templates, flows
