---
name: raindrop-instrument-agent
description: Add Raindrop Workshop tracing to a Python agent (LangChain/LangGraph/OpenAI). Two phases: basic visibility first, enrichment second. Verify Phase 1 before Phase 2.
source: https://github.com/raindrop-ai/workshop/tree/main/skills/instrument-agent
risk: low
---

# Instrument Agent with Raindrop Workshop

Add live tracing to an agent so every run appears in Workshop at http://localhost:5899.

## Rules (always apply)

- Fetch current SDK docs before writing code — APIs change fast
- Update the SDK to latest before any instrumentation edits
- Never create competing providers if Langfuse/OTel/Sentry already exist — wrap outside them
- Verify Phase 1 success (one real trace in Workshop) before Phase 2
- Use `event=repo_name` in `begin()` to enable per-repo filtering in the harness dashboard

## Phase 0 — Orient

```bash
# Check if Workshop is running
curl -s http://localhost:5899 > /dev/null && echo "running" || echo "not running"

# Check if raindrop-ai is installed
pip show raindrop-ai 2>/dev/null | grep Version

# Find existing observability (must not conflict)
grep -r "langfuse\|opentelemetry\|sentry" pyproject.toml requirements*.txt 2>/dev/null
```

If Workshop is not running: `raindrop workshop` (install first if needed: `curl -fsSL https://raindrop.sh/install | bash`)

## Phase 1 — Basic Visibility

**Install:**
```bash
pip install --upgrade raindrop-ai
# or add to pyproject.toml: "raindrop-ai>=0.1"
```

**Minimal wrapper pattern (Python async):**
```python
import raindrop.analytics as raindrop
import uuid

raindrop.init(
    api_key=None,              # None = local Workshop only, no cloud
    tracing_enabled=True,
    bypass_otel_for_tools=True,
    auto_instrument=False,
)

# At your outermost agent entry point:
async def process(user_message: str, ...):
    interaction = raindrop.begin(
        user_id="local",
        event="<REPO_NAME>",       # use repo name for per-repo dashboard filtering
        event_id=str(uuid.uuid4()),
        convo_id="default",
        input=user_message,
    )
    try:
        result = await _your_agent_logic(user_message, ...)
        await raindrop.finish(interaction, output=str(result))
        return result
    except Exception as e:
        await raindrop.finish(interaction, output=f"error: {e}")
        raise
    finally:
        await raindrop.flush()
```

**Set env var** (add to `.env` or your runner config):
```
RAINDROP_LOCAL_DEBUGGER=http://localhost:5899
```

**Verify:** Run the agent once, open http://localhost:5899, confirm a trace appears with the right input and output.

## Phase 2 — Enrichment

Only proceed after Phase 1 produces a visible trace.

**Add tool spans** using `interaction.track_tool`:
```python
async def _call_tool(interaction, tool_name: str, input_data: dict):
    tool_span = await interaction.track_tool(
        name=tool_name,
        input=str(input_data),
    )
    result = await _execute_tool(tool_name, input_data)
    await tool_span.finish(output=str(result))
    return result
```

**Add session/tenant metadata:**
```python
interaction = raindrop.begin(
    user_id=user_id,           # actual user identifier if available
    event="<REPO_NAME>",
    event_id=request_id,       # stable ID for this specific run
    convo_id=session_id,       # groups turns in a conversation
    input=user_message,
    properties={               # arbitrary metadata for Workshop filter
        "repo": "<REPO_NAME>",
        "environment": os.getenv("ENVIRONMENT", "local"),
    },
)
```

## Success Criteria

A useful trace shows: user input, final output, main LLM call, real tool executions, tenant/session IDs. Verification = trace appears in Workshop with actionable content, not just "installed successfully."

## LangChain/LangGraph Note

For repos using LangGraph `.ainvoke()`: inject `begin()`/`finish()` at the outermost boundary (e.g. `process()` or `invoke()`), **outside** any existing Langfuse context managers. Never wrap inside `create_root_trace_context()` or `@observe` decorators — Raindrop must be the outermost span.
