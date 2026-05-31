---
name: cma-outcomes
description: Build grade-and-revise loops using Claude Managed Agents Outcomes feature. Use when asked to "build a grader agent", "verify agent output automatically", "set up a grade-and-revise loop", "use CMA Outcomes", or implement iterative quality verification with a rubric-driven grader.
---

# CMA Outcomes: Grade-and-Revise Loops

The Outcomes feature in Claude Managed Agents lets a stateless grader agent evaluate a writer agent's output against a rubric and drive revisions until the output passes — without writing custom orchestration code.

## When to Use Outcomes

Outcomes fits tasks where you can write down what "good" looks like as a checkable rubric:

- **Good fit:** research quality verification, citation checking, compliance review, structured document completeness
- **Poor fit:** open-ended creative tasks, subjective quality, tasks without objective criteria

The test: can you write a rubric that a fresh-context agent could apply mechanically to produce a pass/fail verdict?

## Phase 0: Setup

```python
import anthropic, os
from dotenv import load_dotenv

load_dotenv()
BETAS = ["managed-agents-2026-04-01"]
MODEL = os.environ.get("COOKBOOK_MODEL", "claude-sonnet-4-6")
client = anthropic.Anthropic()
```

## Phase 1: Create the Writer Agent + Session

```python
env = client.beta.environments.create(
    name="my-task-env",
    config={"type": "anthropic_cloud", "networking": {"type": "unrestricted"}},
)

writer = client.beta.agents.create(
    name="Writer Agent",
    model=MODEL,
    system="<writer system prompt — include explicit output format and file path>",
    tools=[{
        "type": "agent_toolset_20260401",
        "configs": [
            {"name": "web_search"},
            {"name": "web_fetch"},
            {"name": "read"},
            {"name": "write"},
        ],
    }],
    betas=BETAS,
)

session = client.beta.sessions.create(
    agent={"type": "agent", "id": writer.id, "version": writer.version},
    environment_id=env.id,
    title="<session title>",
    betas=BETAS,
)
```

## Phase 2: Define the Task and Rubric

Separate `TASK` (what to produce) from `RUBRIC` (how the grader verifies it).

```python
TASK = """<what the writer should produce, topic + required coverage areas>"""

RUBRIC = """
You are reviewing <output location> against a coverage checklist.

COVERAGE CHECKLIST:
  1. <Item>: <specific, checkable criterion — name the exact metric or value required>
  2. <Item>: <criterion>
  ...

CITATION CHECK (if applicable):
  a. LIVE: Fetch each cited URL. Mark LIVE only if web_fetch returns the page directly.
  b. VERBATIM: Search the page for the quoted string character-for-character.
  c. SUPPORTS CLAIM: Mark SUPPORTS_CLAIM if the quote backs the claim it's cited on.

OUTPUT FORMAT:
Line 1: Coverage N/M. Citations K/L verified.
Then one bullet per failed item: "Item N <name> - MISSING/FAILED. <one sentence why>".
Then one bullet per failed citation: "[n] domain - REASON. <one sentence what's wrong>".
"""
```

## Phase 3: Send the Outcome Event

```python
client.beta.sessions.events.send(
    session.id,
    betas=BETAS,
    events=[{
        "type": "user.define_outcome",
        "description": TASK,
        "rubric": {"type": "text", "content": RUBRIC},
        "max_iterations": 5,
    }],
)
```

## Phase 4: Monitor the Grade-and-Revise Loop

```python
import time, re

TERMINAL = {"satisfied", "max_iterations_reached", "failed", "interrupted"}
t0, result, iters = time.time(), None, 0

with client.beta.sessions.events.stream(session.id, betas=BETAS) as stream:
    for ev in stream:
        if ev.type == "span.outcome_evaluation_start":
            print(f"\n--- writer {'draft' if iters == 0 else f'revision {iters}'} ---")
        elif ev.type == "span.outcome_evaluation_end":
            result = ev.result
            status = "PASSED" if result == "satisfied" else "needs revision"
            print(f"--- grader pass {iters}: {status} ---")
            print(ev.explanation)
            iters += 1
            if result in TERMINAL:
                break

elapsed = int(time.time() - t0)
print(f"\nDone: {result} after {iters} pass(es) in {elapsed}s")
```

**Key event types:**

| Event | Meaning |
|-------|---------|
| `agent.tool_use` | Writer used a tool (web_search, write, etc.) |
| `span.outcome_evaluation_start` | Grader starting a new evaluation pass |
| `span.outcome_evaluation_end` | Grader finished; check `ev.result` and `ev.explanation` |

**Terminal states:** `satisfied` | `max_iterations_reached` | `failed` | `interrupted`

## Phase 5: Retrieve the Final Artifact

```python
content = ""
for ev in client.beta.sessions.events.list(session.id, limit=1000, betas=BETAS):
    if ev.type != "agent.tool_use":
        continue
    if "output.md" not in str(ev.input.get("file_path", "")):
        continue
    if ev.name == "write":
        content = ev.input["content"]
    elif ev.name == "edit":
        content = content.replace(ev.input["old_string"], ev.input["new_string"], 1)

print(content)
```

## Rubric Writing Principles

| Principle | Good | Bad |
|-----------|------|-----|
| **Make each criterion checkable** | "Confirm a $/kW figure or % of cost" | "Cover demand charges" |
| **Force evidence** | "Fetch the URL; mark DEAD if 403" | "Verify citations exist" |
| **Describe the goal, not the steps** | Define what counts as proof | Step-by-step instructions |
| **Anticipate shortcuts** | "Do NOT use press releases; require the 10-K" | (silent) |
| **Mandate output format** | "One bullet per failure" | (open-ended) |
| **Tell the grader what to ignore** | "Do not corroborate via mirrors" | (grader decides) |

## Tips

- **Writer system prompt:** always specify the exact output file path and citation format. The grader needs a stable location to read.
- **Rubric strictness:** the grader approves whatever it's shown unless forced to fetch and verify evidence. Weak rubrics produce false passes.
- **`max_iterations`:** set to 3–5. Beyond 5, the writer is likely stuck and needs a different prompt, not more attempts.
- **Citation check:** the `LIVE` / `VERBATIM` / `SUPPORTS_CLAIM` triplet from the cookbook is the gold standard for verifiable citation quality.
- **After loop ends:** the session is conversational again; you can chain a second outcome.

## Related Skills

- `evaluation` — general rubric design methodology and LLM-as-judge patterns
- `multi-agent-patterns` — architectural context for writer/grader agent design
- `claude-api` — Anthropic SDK usage and model selection guidance

## Reference

Source: [Anthropic Cookbook — Managed Agents: Verify with Outcome Grader](https://platform.claude.com/cookbook/managed-agents-cma-verify-with-outcome-grader)
