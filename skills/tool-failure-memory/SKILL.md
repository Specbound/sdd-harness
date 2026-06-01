---
name: tool-failure-memory
description: Use when a tool-failure recall warning appears before a Bash/MCP call, a command fails 2+ times in a session, or reviewing the tool-failure ledger. Covers the capture→recall→review loop and recording a remedy so the failure stops recurring.
---

# Tool-Failure Memory

A closed loop so the harness **learns from its own failing tool calls** instead of repeating them. Adapted from ReMe's tool/procedural memory (success-failure experience), made deterministic with hooks + a per-repo ledger.

## The loop (three moving parts)

1. **Capture** — `tool-failure-capture.sh` (PostToolUseFailure) records every failing Bash/MCP call into `.claude/memory/tool-failures.jsonl`, keyed by a normalized *signature*.
2. **Recall** — `tool-failure-recall.sh` (PreToolUse) warns before you re-run a shape that has failed ≥2× and is still `open`.
3. **Review** — the scheduled `tool-failure-review` routine reads the ledger, diagnoses *why* recurring failures happen, and writes the cause+remedy into memory. This is where learning becomes durable.

```
fail → capture (ledger) → recall warns on repeat → review promotes to memory → memory prevents
```

## The signature (why it clusters)

The hooks collapse volatile tokens so the *same kind* of failure clusters under one key. Bash commands: quoted strings → `<str>`, slash-bearing tokens → `<path>`, hashes → `<hash>`, numbers → `<n>`. MCP calls: `tool_name(sorted,arg,keys)`.

- `pytest tests/test_auth.py::test_login -x` → `pytest <path> -x`
- `mcp__gitnexus__query` with `{cypher: "..."}` → `mcp__gitnexus__query(cypher)`

So three different failing pytest invocations collapse to one entry whose `count` climbs — that count is the signal worth acting on.

## When a recall warning fires (do NOT reflexively re-run)

The warning means this shape already failed here. Before proceeding:

1. **Read the recorded error / remedy** in the warning. If a remedy is shown, apply it.
2. **Change something concrete** — fix the flag, activate the venv, correct the path, install the dep — or explicitly confirm what is now different (e.g. "the missing file now exists").
3. **If the call then succeeds**, say so in your reply and, when you know the fix, record the remedy (below). A success after a recorded failure is exactly the experience the loop exists to keep.

Never silence the loop by deleting the ledger. If a warning is genuinely stale, let it age out (recall ignores entries older than 45 days) or mark it resolved via the review routine.

## Recording a remedy (close an entry)

When you discover why a recurring failure happens and how to avoid it, update its ledger entry so future recall is actionable and the review routine can promote it:

```bash
python3 - <<'PY'
import json
LED = ".claude/memory/tool-failures.jsonl"
SIG = "pytest <path> -x"                       # the signature from the warning
REMEDY = "Run inside the project venv: source .venv/bin/activate first."
rows = [json.loads(l) for l in open(LED) if l.strip()]
for r in rows:
    if r["sig"] == SIG:
        r["remedy"] = REMEDY
        r["status"] = "resolved"               # recall stops warning; capture re-opens if it recurs
open(LED, "w").write("".join(json.dumps(r) + "\n" for r in rows))
PY
```

`resolved` silences recall. If the failure recurs anyway, the capture hook automatically flips it back to `open` — the fix didn't hold, so the loop re-engages.

## Promoting to memory (the review step)

Recurring failures whose cause is understood graduate from the ledger (ephemeral, per-repo) into a memory file (durable, explains *why*). A good promotion is reusable across future tasks — not a one-off:

- ✅ "In this repo, bare `pytest` fails with ModuleNotFoundError; the test suite must run via `uv run pytest` because deps live in the uv venv." → memory.
- ❌ "`pytest tests/test_auth.py` failed once on 2026-06-01." → not memory; that's a single ledger event.

Write the promotion as a `feedback` or `project` memory (cause + how to apply), add its index line to `MEMORY.md`, and mark the ledger entry `promoted: true`. The `tool-failure-review` routine does this in bulk on its schedule; you can also do it inline when you fix a failure mid-session.

## Cross-references

- `ERRORS.md` — CLAUDE.md already requires logging any approach that took 2+ attempts. A promoted tool failure usually belongs there too (what failed, what worked, why).
- `tool-failure-review` command (`/kiro:tool-failure-review`) — the manual entry point to the review step.

## This skill does NOT

- Block or retry tool calls — recall is advisory only.
- Track *successful* tool calls — only failures are captured.
- Replace general memory discipline — promotions still pass the memory-discipline transfer test ("would this help a different future task?").
