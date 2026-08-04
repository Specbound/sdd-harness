---
name: background-work-routing
description: Decide whether to run work inline or in background. Pain-triggered mode by default — stay inline unless a specific signal fires. Includes concurrency budget and Agent() parameter guidance.
triggers:
  - About to spawn a subagent via Agent tool
  - Task seems long-running or expected to take more than a few minutes
  - Multiple agents needed in parallel
  - User asks "what happened to the agent" or expresses frustration with dropped state
  - Deciding between run_in_background true vs false
  - Choosing how to structure parallel agent work
  - Any task where the user might walk away and come back
---

# Background Work Routing

Default: **inline**. Switch to background only when a pain signal fires.

## Three Modes

| Mode | Behavior |
|---|---|
| `pain_triggered` | Inline by default; switch when ≥1 pain signal fires — **DEFAULT** |
| `always` | All multi-step work goes background |
| `off` | Always inline; never suggest background |

## Pain Signals — Switch to Background When ≥1 Fires

| Signal | What it looks like |
|---|---|
| **Gateway restart mid-task** | Agent was running, session crashed or restarted |
| **State drop** | User asks "what happened to the agent" or "why did it forget what it was doing" |
| **Parallel > 3** | Task needs more than 3 concurrent agents |
| **Long runtime** | Expected to take > 5 minutes |
| **User frustration** | "this keeps breaking", "it keeps losing track", "why is this so flaky" |

When ≥1 signal fires: **pause and offer the switch explicitly.** Don't switch silently.

> "This task is expected to run ~10 minutes and might outlast the session. Want me to run it in the background so you can continue working? It'll report back when done."

## Inline vs Background Decision Table

| Condition | Action |
|---|---|
| Single tool call, < 30s | Inline, always |
| Read-only query | Inline |
| User is waiting in real time for an answer | Inline |
| Multi-step, user can walk away | **Background** |
| Parallel 3+ streams | **Background** |
| Task needs to survive a session restart | **Background** |
| User wants progress updates | **Background** |
| Research or bulk operation | **Background** |

**Rule of thumb:** If the user might ask "is it done yet?", use background.

## Concurrency Budget

Before launching parallel agents:
- If > 5 agents are already active, stagger new ones with delays rather than launching all at once
- Prefer 3–5 focused parallel streams over 10 broad ones
- Large batch jobs: submit in waves, not all at once

## Agent() Parameters

```python
# Inline (default) — user is watching, task is short
Agent(
    description="Quick analysis",
    prompt="...",
    run_in_background=False   # default, can omit
)

# Background — pain signal fired or task is clearly long
Agent(
    description="Long research task",
    prompt="...",
    run_in_background=True    # reports back when done
)
```

## When to Propose Mode Change

If the user has been burned multiple times by dropped state (pain signals fire repeatedly), propose switching the default:

> "Your agents keep dropping state. Want to switch to background-first for all multi-step tasks? It's one setting — I can set it now."

Don't propose this after a single incident. Multiple confirmed pain signals warrant the suggestion.
