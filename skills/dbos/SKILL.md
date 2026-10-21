---
name: dbos
description: Build reliable, fault-tolerant applications with DBOS durable workflows in Python, Go, or TypeScript. Use when adding DBOS to code, writing workflows/steps, using queues, workflow communication (events/messages/streams), or configuring/launching/testing a DBOS app.
---

# DBOS Durable Workflows

DBOS durable execution: workflows checkpoint their progress so they resume from the last completed step after a crash or restart, instead of re-running from scratch. Same model across Python, Go, and TypeScript — only syntax differs.

## Core model
- A **workflow** orchestrates; a **step** does the actual work (API calls, I/O, anything non-deterministic or side-effecting).
- **Workflows MUST be deterministic.** Any non-deterministic operation (network call, random, current time, external service) belongs in a step, never directly in workflow code.
- Steps checkpoint results — on retry, a completed step is not re-run; its saved result is returned.
- **Queues** control concurrency/rate of workflow execution (priority, dedup, partitioning, rate limiting).
- The app MUST configure and launch DBOS (register workflows, connect to the system database) before any workflow runs — typically in `main`.

## Key constraints (all languages)
- Do NOT start, enqueue, or receive-on-behalf-of workflows **from inside a step**.
- Do NOT use raw threads/goroutines/uncontrolled concurrency to start workflows — use the language's queue/start-workflow API instead.
- Do NOT mutate global/module-level state from workflows or steps.
- All workflows (and queues, in Go) must be registered before `Launch()`/`launch()` is called.

## Quickstart per language

### Python
```bash
pip install dbos
```
```python
import os
from dbos import DBOS, DBOSConfig

@DBOS.step()
def call_external_api():
    return requests.get("https://api.example.com").json()

@DBOS.workflow()
def my_workflow():
    return call_external_api()

if __name__ == "__main__":
    config: DBOSConfig = {
        "name": "my-app",
        "system_database_url": os.environ.get("DBOS_SYSTEM_DATABASE_URL"),
    }
    DBOS(config=config)
    DBOS.launch()
```
Constraints specific to Python: do not call `DBOS.start_workflow` or `DBOS.recv` from a step.

### Go
```bash
go get github.com/dbos-inc/dbos-transact-golang/dbos@latest
```
```go
func fetchData(ctx context.Context) (string, error) {
    resp, err := http.Get("https://api.example.com/data")
    if err != nil { return "", err }
    defer resp.Body.Close()
    body, _ := io.ReadAll(resp.Body)
    return string(body), nil
}

func myWorkflow(ctx dbos.DBOSContext, input string) (string, error) {
    return dbos.RunAsStep(ctx, fetchData, dbos.WithStepName("fetchData"))
}

func main() {
    ctx, err := dbos.NewDBOSContext(context.Background(), dbos.Config{
        AppName:     "my-app",
        DatabaseURL: os.Getenv("DBOS_SYSTEM_DATABASE_URL"),
    })
    if err != nil { log.Fatal(err) }
    defer dbos.Shutdown(ctx, 30*time.Second)
    dbos.RegisterWorkflow(ctx, myWorkflow)
    if err := dbos.Launch(ctx); err != nil { log.Fatal(err) }
}
```
Use `dbos.Go`/`dbos.Select` for concurrent steps; use `dbos.RunWorkflow` + queues to start workflows concurrently (never bare goroutines).

### TypeScript
```bash
npm install @dbos-inc/dbos-sdk@latest
```
```typescript
import { DBOS } from "@dbos-inc/dbos-sdk";

async function fetchData() {
  return await fetch("https://api.example.com").then(r => r.json());
}
async function myWorkflowFn() {
  return await DBOS.runStep(fetchData, { name: "fetchData" });
}
const myWorkflow = DBOS.registerWorkflow(myWorkflowFn);

async function main() {
  DBOS.setConfig({ name: "my-app", systemDatabaseUrl: process.env.DBOS_SYSTEM_DATABASE_URL });
  await DBOS.launch();
  await myWorkflow();
}
main().catch(console.log);
```
Use `DBOS.startWorkflow` or queues to run workflows concurrently (never uncontrolled async/threads).

## Workflow communication
All three SDKs support the same patterns for talking to a running workflow from outside (or between workflows):
- **Events**: workflow sets a named key/value; callers poll/get it (`comm-events`).
- **Messages**: durable send/receive between workflow and caller (`comm-messages`).
- **Streams**: incremental, ordered output a workflow can push and a caller can consume (`comm-streaming`).

## Queues
Use a queue instead of ad-hoc concurrency when you need: concurrency limits, rate limiting, priority ordering, deduplication, or partitioning of enqueued workflow runs. Enqueue via the language's `start_workflow`/`RunWorkflow`/`startWorkflow` + queue argument — never spawn workflows from inside a step.

## Common patterns
- **Idempotency**: pass a deterministic workflow ID (e.g. derived from the triggering event) so re-delivery doesn't re-run the workflow.
- **Scheduled workflows**: register on a cron-like schedule instead of polling.
- **Debouncing**: coalesce rapid repeated triggers into one workflow run.
- **Sleep**: use the SDK's durable sleep (not `time.sleep`/`setTimeout`) so the delay survives a restart.

## Testing & external clients
- Tests should launch DBOS against a real (often ephemeral/local) system database — don't mock the durability layer.
- Use `DBOSClient`/`dbos.Client` from a separate process/service to enqueue workflows or read their status/results without embedding the full SDK runtime.

## Gotchas
- A workflow that calls another workflow directly (not via `start_workflow`/queue) runs it as a child **synchronously in the same execution** — use that only when you want it to block.
- Changing a workflow's code after it has in-flight executions can break replay determinism — see each SDK's versioning/patching docs before deploying breaking changes to a long-running workflow.
- FastAPI/Express-style lifecycle integration (starting DBOS alongside a web server) needs DBOS launched before the server starts accepting requests, not after.

## References
- https://docs.dbos.dev/
- https://github.com/dbos-inc/dbos-transact-py
- https://github.com/dbos-inc/dbos-transact-golang
- https://github.com/dbos-inc/dbos-transact-ts
