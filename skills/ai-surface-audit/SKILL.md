---
name: ai-surface-audit
description: This skill should be used when auditing the local AI-agent attack surface — installed MCP servers, CLI agents, and their capabilities (execute, hold secrets, broad filesystem/network access) — or when investigating drift in that surface since the last scan.
triggers:
  - ai surface audit
  - mcp server audit
  - geiger scan
  - agent attack surface
  - what can my mcp servers do
version: 1.0.0
author: Dan
date: 2026-09-16
---

# AI-Agent Surface Audit

Security skills in this harness audit *code and infra*. Nothing audits the local
AI-toolchain itself — yet this repo's own `.claude/` config and MCP servers
(lean-ctx, gitnexus, workshop, serena, Atlassian, ...) are themselves an attack
surface: any of them can execute code, read secrets, or reach the network on
Claude's behalf. This skill wraps [geiger](https://github.com/Atomburstofficial/geiger)
to inventory that surface.

## When to use

- User asks "what can my MCP servers actually do?" or "audit my AI agent setup"
- Before onboarding a new MCP server or CLI agent, to see its declared capabilities
- When `daily-maintenance`'s drift check (below) flags a surface change

## Running a scan

```bash
npx --yes geiger-scan --strict --json > .claude/memory/.ai-surface-scan.json
```

`--strict` fails loudly on ambiguous capability declarations rather than
guessing. `--json` makes the output diffable. Read the output and summarize by
capability class:

- **Executes** — can run arbitrary code/shell (highest risk)
- **Holds secrets** — has access to API keys, tokens, credentials
- **Broad filesystem** — reads/writes outside a scoped directory
- **Broad network** — unrestricted outbound network access

Flag anything in more than one class, and anything the user doesn't recognize
installing themselves.

## Drift detection

```bash
npx --yes geiger-scan --strict --json --diff .claude/memory/.ai-surface-scan.json
```

Compares the current surface against the last saved scan. A new capability
appearing on an existing server, or a new server entirely, is worth surfacing
to the user even if nothing else changed that session — MCP servers can
change their declared tool surface on update without the user reinstalling
anything.

## Automation

Folded into `/kiro:daily-maintenance`'s drift check (best-effort, silent if
`npx`/`geiger-scan` isn't available — this is advisory, not a hard gate). The
*initial* full scan stays user-invoked: a first-run baseline needs a human to
review what's normal for their setup, an automated routine has no baseline to
diff against yet.

## Not automatable (by design)

Judging whether a given capability combination is *acceptable* requires
knowing what the user intentionally installed and why — a routine can detect
drift, but can't judge intent. Surface the diff; let the user decide.
