# Async Peer-to-Peer Agents (raw Anthropic SDK)

When you build a multi-agent app directly on the Anthropic SDK (no framework), the orchestration plumbing reduces to a shared message hub plus a tool-use loop. Two shapes ride the same hub:

- **Fixed N-agent team** — one lead + a fixed set of helpers, all peers.
- **Dynamic spawn** — lead spawns/kills helpers at runtime.

Source: [Anthropic Cookbook — Async Multi-Agent Orchestration](https://platform.claude.com/cookbook/patterns-agents-async-multi-agent-orchestration).

## Message Hub

Per-agent inbox + an `asyncio.Event` so waits are event-driven, not polled:

```python
class Hub:
    def __init__(self):
        self.inbox: dict[str, list[dict]] = defaultdict(list)
        self.event: dict[str, asyncio.Event] = defaultdict(asyncio.Event)
        self.status: dict[str, str] = {}
        self._ids = itertools.count(1)

    def post(self, sender, recipients, content):
        for r in recipients:
            self.inbox[r].append({"from": sender, "content": content})
            self.event[r].set()              # wake any blocked recipient

    def drain(self, name):                   # atomically empty inbox + reset Event
        msgs, self.inbox[name] = self.inbox[name], []
        self.event[name].clear()
        return msgs

    def new_name(self, prefix="helper"):     # dynamic registration for spawn
        return f"{prefix}-{next(self._ids)}"
```

## The key trick — deliver inline, never poll

Append drained peer messages onto the *last tool result* the agent already received. The agent reads peer mail as a normal continuation of its tool-use loop:

```python
inbox = hub.drain(name)
if inbox and results:
    results[-1]["content"] += hub.render(inbox)   # render() wraps in <agent-message from="...">
```

So an agent sees peer messages on the result of *any* tool call — zero polling overhead.

## Two agent tools — the only inter-agent channel

- `send_message(recipients, content)` → `hub.post(...)`. Plain text in, plain text out. The ONLY way to reach a peer.
- `wait_for_message()` → blocks on `await hub.event[name].wait()`. Use only when the agent has nothing else to do.

## Dynamic-spawn lifecycle — `spawn → status → collect → kill`

- **spawn:** `asyncio.create_task(run_agent(hub.new_name(), ...))` — non-blocking; lead keeps working.
- **status:** read `hub.status[name]` (helper updates its own slot).
- **collect:** drained helper reports arrive inline via the append trick above.
- **kill:** cancel the task / drop the name once its report is collected.

One `run_agent(name, ...)` coroutine drives *any* agent (lead or helper) as a standard tool-use loop; only the toolset and system prompt differ.

## Mitigations (carry over from the failure-modes section)

- TTL limits on spawned tasks so a stuck helper can't hang the lead.
- Output schemas on helper reports.
- Validate a result before a peer consumes it.
