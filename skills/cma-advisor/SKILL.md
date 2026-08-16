---
name: cma-advisor
description: Let a Claude Managed Agents (CMA) working agent consult a stronger model mid-turn on a single high-stakes/irreversible decision. Use when asked to "add an advisor to a managed agent", "escalate hard decisions to a stronger model", "use CMA Advisor", or set up cost-aware model escalation inside a Managed Agents session.
---

# CMA Advisor: Mid-Turn Escalation to a Stronger Model

The Advisor feature in Claude Managed Agents lets a working agent's coordinator roster include a reserved `advisor` entry — a stronger (usually more expensive) model the working agent can consult, once, on the whole conversation-so-far, when it hits a decision it doesn't trust itself on. The platform handles thread spin-up, delivery, and per-consultation cost tracking; you write the consultation *policy* (when to call it) into the system prompt, not into code.

## When to Use Advisor vs. Outcomes

- **Advisor** (this skill): mid-turn escalation on a single hard call — "should I drop this column or keep it nullable?" One-shot advice, delivered once, no revision loop.
- **`cma-outcomes`** (sibling skill): post-hoc grade-and-revise — a stateless grader repeatedly checks a rubric and drives the writer to revise until it passes.

Different API surface (roster `multiagent.agents` entry vs. `user.define_outcome` event), different event types, different use case. Don't conflate them.

## Phase 0: Setup

```python
import anthropic, os
from dotenv import load_dotenv

load_dotenv()
BETAS = ["managed-agents-2026-04-01"]   # requires anthropic>=0.121.0
WORKER_MODEL  = os.environ.get("WORKER_MODEL", "claude-sonnet-4-6")
ADVISOR_MODEL = os.environ.get("ADVISOR_MODEL", "claude-opus-4-8")
client = anthropic.Anthropic()
```

## Phase 1: Roster Setup — Add the Advisor Entry

Advisor is declared as a `multiagent.agents` roster entry, not a tool definition or a separate agent resource:

```python
designer = client.beta.agents.create(
    name="api_designer",
    description="Designs HTTP APIs, escalating irreversible decisions to an advisor.",
    model={"id": WORKER_MODEL},
    system=SYSTEM,   # consultation policy lives here — see Phase 2
    tools=[{"type": "agent_toolset_20260401"}],
    multiagent={
        "type": "coordinator",
        "agents": [
            {"type": "advisor", "model": ADVISOR_MODEL},
        ],
    },
    betas=BETAS,
)
```

A roster containing *only* the advisor entry is valid — the agent consults but spawns no specialist subagents. Advisor can also sit alongside specialists in the same roster:

```python
multiagent={
    "type": "coordinator",
    "agents": [
        "agent_01Res...",                              # specialist by id
        {"type": "agent", "id": "agent_01Aud...", "version": 3},
        {"type": "advisor", "model": ADVISOR_MODEL},   # the advisor
    ],
},
```

**Constraints (platform-enforced, not conventions):**

| Constraint | Detail |
|---|---|
| At most one advisor per roster | A second `{"type": "advisor", ...}` entry is invalid |
| Reserved name | Occupies `anthropic.advisor` in the roster — no specialist may use that name |
| Model eligibility | The `model` must be an allowed advisor, and the pairing with the working model must be permitted — an ineligible pairing 400s at `agents.create`, not at runtime |
| No-input tool | The advisor reads the *whole conversation so far* — it takes no query the working model writes. Consultation policy (when/why to call) must be set via the system prompt, not a tool argument |
| Fixed at session creation | Changing the advisor on the agent resource affects sessions created afterward, not one already running |
| Concurrency exemption | Only the primary thread consults; specialists spawned by the coordinator have no advisor of their own, and advisor threads are exempt from the child-thread concurrency bound — a coordinator already at its child limit can still consult |
| No per-consultation spend cap | Advisor tokens bill in addition to the working model's, uncapped per call — bound total spend with a session `budget` (Phase 3) |

## Phase 2: Consultation Policy — Write It Into the System Prompt

Since the advisor tool takes no input, *when* to call it is entirely a system-prompt instruction. Be specific about what counts as "irreversible" or "high-stakes" for this task — vague policy either never fires or fires on everything.

```python
SYSTEM = """You design HTTP APIs. For most decisions, use your own judgment.

Consult the advisor only for decisions that are hard to reverse once shipped:
schema-breaking changes, auth model choices, or anything a downstream client
would need a major-version bump to recover from. Do not consult it for
naming, formatting, or anything you could fix in a follow-up PR."""
```

## Phase 3: Bound Total Spend (No Per-Call Cap Exists)

```python
session = client.beta.sessions.create(
    agent={"type": "agent", "id": designer.id, "version": designer.version},
    environment_id=env.id,
    budget={"type": "limit", "max_list_cost": {"currency": "USD", "amount": "500"}},  # $5.00, minor units
    betas=BETAS,
)
```

## Phase 4: Monitor Consultations via the Event Stream

A consultation surfaces as a thread lifecycle on the primary session stream — not as an `agent.tool_use` event:

```
session.thread_created           agent_name: anthropic.advisor
session.thread_status_running    agent_name: anthropic.advisor
agent.thread_message_received    from_agent_name: anthropic.advisor, content: [{type: "text", ...}]
session.thread_status_idle       agent_name: anthropic.advisor
session.thread_status_terminated agent_name: anthropic.advisor
```

The thread stays `running` throughout the call; advice delivers at the end and the thread terminates itself.

```python
def advice_text(content):
    """Render an advisor delivery: joined text, or a marker for the redacted arm."""
    if any(block.type == "redacted" for block in content):
        return "[redacted advice: content withheld by the advisor model's policy]"
    return "".join(block.text for block in content if block.type == "text")

consultations = 0
with client.beta.sessions.events.stream(session.id, betas=BETAS) as stream:
    for ev in stream:
        if ev.type == "session.thread_created" and ev.agent_name == "anthropic.advisor":
            consultations += 1
        elif ev.type == "agent.thread_message_received" and ev.from_agent_name == "anthropic.advisor":
            print(advice_text(ev.content)[:800])
```

**Identifying the advisor thread reliably:** on stream events, match `agent_name == "anthropic.advisor"` / `from_agent_name == "anthropic.advisor"`. On a *retrieved thread object*, prefer `thread.agent.type == "advisor"` over the name — no Agent resource backs a platform advisor, so the thread carries the roster entry itself (`{"type": "advisor", "model": ...}`), and `agent.type` is the more reliable field.

## Phase 5: Retrieve Per-Consultation Cost

```python
from decimal import Decimal

def usd(money) -> str:
    """Render an integer minor-unit amount ("131" = $1.31) as dollars."""
    return f"${Decimal(money.amount) / 100:.2f}"

advisor_thread_ids = [
    ev.session_thread_id
    for ev in client.beta.sessions.events.list(session.id, limit=1000, betas=BETAS)
    if ev.type == "session.thread_created" and ev.agent_name == "anthropic.advisor"
]

advisor_in = advisor_out = 0
advisor_cents = Decimal("0")
for thread_id in advisor_thread_ids:
    thread = client.beta.sessions.threads.retrieve(thread_id, session_id=session.id, betas=BETAS)
    usage = thread.usage
    advisor_in += usage.input_tokens or 0
    advisor_out += usage.output_tokens or 0
    advisor_cents += Decimal(usage.list_cost.amount)
    print(
        f"{thread.id} agent.type={thread.agent.type} model={thread.agent.model} "
        f"status={thread.status} in={usage.input_tokens} out={usage.output_tokens} {usd(usage.list_cost)}"
    )

total = client.beta.sessions.retrieve(session.id, betas=BETAS).usage  # already folds advisor cost in
```

Advisor tokens bill in addition to the primary thread's and are already folded into the session-level `usage.list_cost` aggregate — don't double-count when reporting total session spend.

## Redaction

Whether consultation content is visible depends on Anthropic's policy for the advisor model. If withheld, delivery events carry `[{"type": "redacted"}]` placeholder blocks instead of text — redaction changes what *you* observe, not what the working model uses; it still receives full advice. The advisor's own reasoning is never delivered under either policy, only its final text.

## Tips

- **Model choice:** pick an advisor model meaningfully stronger than the worker — if they're comparable, you're paying double for the same judgment quality.
- **Policy specificity:** name the exact decision categories that warrant escalation in the system prompt (see Phase 2). A generic "ask for help when unsure" policy either never fires or fires constantly.
- **Budget, not per-call cap:** since there's no per-consultation spend cap, the session `budget` is your only backstop against a worker that over-consults.

## Related Skills

- `cma-outcomes` — sibling CMA feature: post-hoc grade-and-revise loop, different mechanism and use case
- `model-tiers` — this harness's own Claude Code subagent model-tier selection; a different runtime (in-process `Agent`/`Task` dispatch, not CMA's hosted platform threads) — don't conflate the two
- `claude-api` — Anthropic SDK usage and model selection guidance

## Reference

Source: [Anthropic Cookbook — Managed Agents: Consult an Advisor](https://platform.claude.com/cookbook/managed-agents-cma-consult-an-advisor)
