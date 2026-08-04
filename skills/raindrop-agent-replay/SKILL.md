---
name: raindrop-agent-replay
description: Configure local replay of Workshop traces — create .raindrop/agents.yaml + a minimal replay server so Workshop can re-run any captured trace against your live agent code.
source: https://github.com/raindrop-ai/workshop/tree/main/skills/setup-agent-replay
risk: low
---

# Setup Agent Replay

Let Workshop replay a captured production trace against your real local agent code.

## Prerequisites

- Agent is already instrumented (see `raindrop-instrument-agent`)
- At least one trace exists in Workshop at http://localhost:5899
- `raindrop` CLI installed

## Phase 1 — Config File

Create `.raindrop/agents.yaml` in the repo root:

```yaml
agents:
  - event: "<REPO_NAME>"        # matches the event= you used in raindrop.begin()
    name: "<Human name>"
    command: "python -m <your.entry.module>"   # command to start your replay server
    port: 61020                 # pick unused port in range 61020-61044
    input_schema:               # shape of the POST /replay body
      user_message: string
      session_id: string
    prefill:                    # how to extract inputs from the original trace
      user_message: "$.input"
      session_id: "$.convo_id"
```

## Phase 2 — Replay Server

Generate a minimal aiohttp replay server at `<repo_root>/replay_server.py`:

```python
"""Raindrop replay server — receives replay requests from Workshop and runs the agent."""
import asyncio
import os
from aiohttp import web
import raindrop.analytics as raindrop

PORT = int(os.getenv("REPLAY_PORT", "61020"))
AGENT_NAME = "<REPO_NAME>"
AGENT_VERSION = "1.0.0"

async def health(request):
    return web.json_response({
        "name": AGENT_NAME,
        "version": AGENT_VERSION,
        "status": "ready",
    })

async def replay(request):
    body = await request.json()
    replay_run_id = body.get("replayRunId")
    user_message  = body["user_message"]
    session_id    = body.get("session_id", "replay-session")

    # Import your actual agent
    from <your.module> import <YourAgent>
    agent = <YourAgent>(dry_run=True)   # use dry_run/test doubles to avoid side effects

    interaction = raindrop.begin(
        user_id="replay",
        event=AGENT_NAME,
        event_id=replay_run_id,   # links replay run to original trace in Workshop UI
        convo_id=session_id,
        input=user_message,
    )
    try:
        result = await agent.process(user_message)
        await raindrop.finish(interaction, output=str(result))
    except Exception as e:
        await raindrop.finish(interaction, output=f"replay error: {e}")
        raise
    finally:
        await raindrop.flush()

    return web.json_response({"ok": True, "output": str(result)})

app = web.Application()
app.router.add_get("/health", health)
app.router.add_post("/replay", replay)

if __name__ == "__main__":
    web.run_app(app, port=PORT)
```

**Critical:** The server must keep the connection open until agent execution finishes. Never fire-and-forget — Workshop waits for the POST /replay response.

## Phase 3 — Register and Test

```bash
# Verify health endpoint
python replay_server.py &
curl http://localhost:61020/health

# Register with Workshop
raindrop replay register

# Run a test replay against the most recent trace
raindrop replay test --event <REPO_NAME>
```

## Side-Effect Prevention

Replay must not write to production DBs, billing systems, or external APIs. Use:
- **Dependency injection**: pass a `dry_run=True` flag or test-double client
- **Env override**: `REPLAY_MODE=true` in the replay server's env
- **Stubs**: mock external HTTP calls with `unittest.mock` or test fixtures

## Trace Stitching

Workshop correlates the replay run with the original trace via `event_id=replay_run_id`. The `prefill` config in `agents.yaml` extracts the original inputs from trace metadata automatically. No manual linking needed.
