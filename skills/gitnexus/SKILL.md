---
name: gitnexus
description: This skill should be used when querying GitNexus for code intelligence — symbol context, blast-radius impact analysis, call chain tracing, multi-repo groups, wiki generation, or visual codebase exploration. Covers setup, all 16 MCP tools, CLI commands, and the SDD harness integration.
triggers:
  - gitnexus
  - query gitnexus
  - blast radius
  - symbol context
  - call chain
  - impact analysis
  - code knowledge graph
  - gitnexus explore
  - gitnexus setup
  - gitnexus wiki
  - cross-repo analysis
  - detect changes
version: 1.0.0
author: Dan
date: 2026-05-06
---

# GitNexus Skill

GitNexus is the code intelligence layer wired into this harness. It builds a knowledge graph from your codebase — symbols, dependencies, call chains, execution flows — and exposes them via 16 MCP tools. It runs entirely on-device; no data leaves your machine.

**Full docs:** `~/.claude/sdd-harness/docs/gitnexus/README.md`

---

## Setup

### One-command setup (recommended)
```
/kiro:gitnexus-setup
```
Installs GitNexus, indexes the current repo, configures MCP, and sets up the post-commit reindex hook.

### Manual setup
```bash
npm install -g gitnexus
cd /path/to/project
gitnexus analyze          # builds .gitnexus/ knowledge graph index
gitnexus setup            # registers MCP for Claude Code + editors
```

Or add to `.claude/settings.json`:
```json
{
  "mcpServers": {
    "gitnexus": {
      "command": "npx",
      "args": ["-y", "gitnexus@latest", "mcp"]
    }
  }
}
```

---

## MCP Tools Reference

### Core tools

| Tool | What it does | Key params |
|------|-------------|------------|
| `list_repos` | List all indexed repositories | — |
| `query` | Hybrid search (BM25 + semantic + RRF) | `query`, `repo` |
| `context` | 360-degree symbol view: callers, dependencies, process participation | `name`, `repo` |
| `impact` | Upstream/downstream blast radius with confidence scores | `target`, `direction`, `minConfidence`, `maxDepth` |
| `detect_changes` | Map git diff lines to affected processes and risk levels | `scope`, `repo` |
| `rename` | Multi-file coordinated rename with graph validation | `symbol_name`, `new_name`, `dry_run` |
| `cypher` | Raw Cypher graph query | query string, `repo` |

### Repository group tools (multi-repo)

| Tool | What it does |
|------|-------------|
| `group_list` | List configured repository groups |
| `group_sync` | Extract contracts and cross-match across repos |
| `group_contracts` | Inspect extracted contracts and links |
| `group_query` | Search execution flows across all repos in a group |
| `group_status` | Check staleness of repos in a group |

### MCP prompts

| Prompt | What it does |
|--------|-------------|
| `detect_impact` | Pre-commit analysis: scope → affected processes → risk assessment |
| `generate_map` | Architecture documentation with mermaid diagrams from knowledge graph |

---

## Common Workflows

### Check blast radius before editing a file
```
Use the `impact` MCP tool:
  target: "MyClass.myMethod"
  direction: "downstream"
  maxDepth: 3
```

### Find all callers of a symbol
```
Use the `context` MCP tool:
  name: "functionName"
→ Returns incoming calls, outgoing dependencies, process participation
```

### Pre-commit impact check
```
/kiro:gitnexus-impact
```
Or use the `detect_changes` MCP tool with `scope: "git diff"` to map changed lines to affected processes with risk levels.

### Visual exploration
```
/kiro:gitnexus-explore
```
Opens the WebGL graph UI at `localhost:4567`. Useful during debugging or before spec design.

---

## Repository Groups (Multi-Repo Analysis)

Groups let GitNexus extract contracts across multiple repos and trace cross-repo execution flows.

```bash
# Create a group and add repos
gitnexus group create my-services
gitnexus group add my-services /path/to/api-service api-service
gitnexus group add my-services /path/to/worker-service worker-service

# Extract contracts (interfaces, types, shared symbols)
gitnexus group sync my-services

# Inspect what was found
gitnexus group contracts my-services

# Search across all repos in the group
gitnexus group query my-services "payment processing flow"

# Check staleness
gitnexus group status my-services
```

Use the `group_*` MCP tools for the same operations from within Claude.

---

## Wiki Generation

Generate architecture documentation from the knowledge graph:

```bash
gitnexus wiki                          # generate wiki for current repo
gitnexus wiki /path/to/project         # specify path
gitnexus wiki --model gpt-4o           # custom LLM
gitnexus wiki --base-url http://...    # custom API base
```

Produces markdown documentation covering symbols, processes, execution flows, and dependency maps — seeded from the knowledge graph rather than written manually.

---

## Key `analyze` Flags

| Flag | Effect |
|------|--------|
| `gitnexus analyze` | Full index |
| `--skip-embeddings` | Faster index; disables semantic search |
| `--embeddings` | Enable embeddings (slower, more accurate) |
| `--skills` | Auto-generate repo-specific skills from the graph |
| `--force` | Force full re-index |
| `--skip-agents-md` | Preserve custom AGENTS.md edits |
| `--skip-git` | Index non-Git folders |
| `--verbose` | Log skipped files |

---

## Maintenance

```bash
gitnexus status        # show index status
gitnexus list          # list indexed repos
gitnexus clean         # delete current repo index
gitnexus clean --all --force  # delete all indexes
```

---

## Harness Automatic Integrations

When `.gitnexus/` exists, these activate without any commands:

| Where | What happens |
|-------|-------------|
| Every `Read`/`Edit` | PreToolUse hook injects 360-degree symbol context |
| Every `git commit` | Post-commit hook re-indexes (`--skip-embeddings`) |
| `/kiro:verify` | Stage 0 runs `detect_changes`, flags HIGH-risk regressions |
| `/kiro:spec-impl` | Blast radius scan before TDD cycle; tests cover downstream dependents |
| `/kiro:debug` | Step 2 queries call chain instead of manual grep |
| `/kiro:skill-extract-scan` | Seeds candidates from Leiden community clusters |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `gitnexus: command not found` | `npm install -g gitnexus` |
| MCP tools not in Claude | Run `/kiro:gitnexus-setup` or add `mcpServers` config manually |
| Stale index | `gitnexus analyze` or check post-commit hook |
| `detect_changes` returns empty | No uncommitted changes — make changes first |
| Slow indexing | Use `--skip-embeddings` for faster indexing |
| Web UI port conflict | `gitnexus serve --port 4568` |
