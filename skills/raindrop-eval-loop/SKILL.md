---
name: raindrop-eval-loop
description: Self-healing eval loop using Workshop traces — read captured agent runs, write pytest assertions, auto-fix failures, rerun until green. Token cost ~5k-30k per cycle; user-triggered.
source: https://github.com/raindrop-ai/workshop (synthesized)
risk: low
---

# Raindrop Self-Healing Eval Loop

Read live traces from Workshop → write assertions → run → fix failures → repeat.

## Token budget

One full cycle costs roughly 5k–30k tokens depending on trace size and failure complexity. You trigger this; it doesn't run automatically.

## Phase −1 — Pattern Discovery (run first if you don't know what to test)

If you're opening the eval loop without a clear sense of what scenarios matter, run `active-observability` first:
- Batch-facet recent traces (task + issues) → cluster summaries → identify top task types and failure modes
- Top 2-3 task clusters → happy path eval scenarios
- Top issue clusters → edge case / bug eval targets

Skip this phase if you already have specific scenarios in mind.

---

## Phase 0 — Prerequisites

```bash
# Workshop must be running with at least one trace
curl -s http://localhost:5899/api/events | python3 -c "import sys,json; e=json.load(sys.stdin); print(f'{len(e)} traces')" 2>/dev/null || echo "Workshop not running or no API"
```

If no traces exist: run the agent once first, verify trace appears in Workshop at http://localhost:5899.

## Phase 1 — Read Traces

Query Workshop's API for recent traces for the target repo:

```bash
# Fetch recent events (adjust event= to your repo name)
curl -s "http://localhost:5899/api/events?event=<REPO_NAME>&limit=10" | python3 -m json.tool
```

Identify 2–3 representative traces:
- One happy path (normal successful run)
- One edge case (unusual input, long output, or multi-step)
- One failure or near-miss (if available)

For each selected trace, capture:
- `id` — trace identifier
- `input` — the user message
- `output` — the final agent response
- Tool calls and their inputs/outputs (from trace spans)
- Latency and any error spans

## Phase 2 — Write Evals

Create or update `tests/test_agent_evals.py` in the repo. Write pytest test functions:

```python
"""Agent evals generated from Workshop traces."""
import pytest
from <your.module> import <YourAgent>

@pytest.fixture
def agent():
    return <YourAgent>()

# One test per selected trace — name reflects the scenario
@pytest.mark.asyncio
async def test_<scenario_from_trace>(agent):
    """<1-line description of what this trace covers>"""
    result = await agent.process("<input from trace>")
    # Assert on structure
    assert result is not None
    # Assert on content — be specific but not fragile
    assert "<key phrase from expected output>" in str(result).lower()
    # Assert on behavior (tool calls, latency, no errors)
    # Add more assertions based on what the trace showed
```

**Assertion guidelines:**
- Test behavior, not exact strings (LLMs are non-deterministic)
- Assert on: presence of key concepts, response structure, tool call patterns, no exceptions
- Never assert on exact wording — use `in` or regex, not `==`

## Phase 3 — Run Evals

```bash
cd <repo_path>
python -m pytest tests/test_agent_evals.py -v --tb=short 2>&1 | tee /tmp/eval_results.txt
```

Collect failures. For each failure, note:
- The assertion that failed
- The actual vs. expected output
- Which trace this test corresponds to

## Phase 4 — Auto-Fix

For each failing test:

1. **If the assertion is wrong** (agent behavior changed intentionally): Update the assertion to match current behavior
2. **If the agent code is wrong**: Read the agent's entry point, apply a targeted fix
3. **Never change the test to trivially pass** (e.g., `assert True`) — fix the root cause

Apply fixes with Edit tool. Keep changes minimal.

## Phase 5 — Rerun Loop

```bash
python -m pytest tests/test_agent_evals.py -v --tb=short 2>&1
```

- If all pass: done, go to Phase 6
- If still failing: check for stall before looping again

**Convergence check (run before each re-iteration):**
Track the count of failing tests across iterations. If the count doesn't decrease from the previous pass, the loop has stalled — stop and report rather than spinning.

```python
# pseudo-code for stall detection
if iteration > 1 and failing_count >= prev_failing_count:
    # stall: loop is not making progress
    report_stall(remaining_failures)
    break
prev_failing_count = failing_count
```

Maximum 3 loop iterations. Don't loop forever.

## Phase 6 — Report

Summarize:
```
## Eval Loop Complete

Traces read: N
Evals written: N  
Evals passing: N/N

Fixed:
- <what was fixed and how>

Still failing (if any):
- <test name>: <why it's hard to fix automatically>

Token cost estimate: ~Xk tokens
```

## Adapting to each repo

| Repo | Entry point | Import pattern |
|------|-------------|----------------|
| aiq-zora-ai-engine | `AgentPipelineGraph.process()` in `engine/core/pipeline.py` | `from engine.core.pipeline import AgentPipeline` |
| aiq-zora-agent-skills | `DailyNewsHandler.handle()` in `zora_skills/.../handler.py` | `from zora_skills.product.cfo_insights.daily_news.scripts.handler import DailyNewsHandler` |
| aiq-purina backend | `Graph.invoke()` in `app/agents/main_graph.py` | `from app.agents.main_graph import Graph` |

**Langfuse note (zora-ai-engine + purina):** Langfuse is already integrated in both repos. Raindrop traces run in parallel — do not disable Langfuse when running evals.
