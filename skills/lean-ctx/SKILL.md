---
name: lean-ctx
description: Context Runtime for AI Agents — 83 MCP tools, 10 read modes, 60+ shell patterns, tree-sitter AST for 18 languages. Compresses LLM context by up to 99%. Use when reading files, running shell commands, searching code, or exploring directories. Auto-installs if not present.
---

# lean-ctx — Context Runtime for AI Agents

## Setup

```bash
which lean-ctx || curl -fsSL https://raw.githubusercontent.com/yvgude/lean-ctx/main/skills/lean-ctx/scripts/install.sh | bash
lean-ctx setup
```

## Advertised Tools (profile `standard` — 17)

| Tool | Purpose |
|------|---------|
| `ctx_callgraph(symbol, direction)` | Callers or callees of a function |
| `ctx_compose(task, path)` | Bundles orientation lookups for a task |
| `ctx_delta(path)` | Diff since last read (post-edit verification) |
| `ctx_execute(language, script)` | Trusted script execution path |
| `ctx_expand(id, ...)` | Retrieve full/archived output from firewalled results |
| `ctx_explore(...)` | Guided codebase exploration |
| `ctx_glob(pattern)` | File pattern matching |
| `ctx_graph(action)` | Code relationships and impact |
| `ctx_knowledge(action)` | Project knowledge across sessions |
| `ctx_overview(task)` | Task-relevant project map |
| `ctx_patch(path, ...)` | Anchored edit application (pairs with `ctx_read(mode="anchored")`) |
| `ctx_read(path, mode)` | Read file with compression and caching |
| `ctx_search(pattern, path)` | Search code with compressed results |
| `ctx_session(action)` | Session state and persistence |
| `ctx_shell(command)` | Run shell with compressed output |
| `ctx_tree(path, depth)` | Directory listing |
| `ctx_url_read(url)` | Fetch and read a URL's content |

Other tools (~66) are trimmed from the schema but callable:
`ctx_call {"name":"ctx_impact","arguments":{"action":"analyze"}}`

## Shell Hook (use instead of raw exec)

```bash
lean-ctx -c "git status"
lean-ctx -c "cargo test"
lean-ctx -c "npm install"
lean-ctx ls src/
```

## ctx_read Modes

| Mode | When |
|------|------|
| `full` | Files you will edit |
| `map` | Context-only (deps + exports) |
| `signatures` | API surface only |
| `diff` | After edits (changed lines) |
| `aggressive` | Large files, syntax-stripped |
| `entropy` | Shannon filtering |
| `task` | Task-relevant lines |
| `lines:N-M` | Specific range |
| `auto` | System selects optimal |

Re-reads cost ~13 tokens. fresh=true bypasses cache.

## File Editing

Use native Edit/StrReplace. If unavailable, use `ctx_patch` after `ctx_read(mode="anchored")`.

## More Tools (via ctx_call or ctx_load_tools)

Invoke via `ctx_call {"name":"<tool>","arguments":{...}}`, e.g. `ctx_call {"name":"ctx_impact","arguments":{"action":"analyze"}}`. List all with `ctx_call {"name":"ctx_discover_tools","arguments":{"query":"keyword"}}`.

Architecture: `ctx_callgraph` and `ctx_graph` are advertised; `ctx_impact`, `ctx_architecture`, `ctx_routes`, `ctx_smells` need `ctx_call`. For symbols use `ctx_search(action="symbol")`.
Multi-agent: ctx_agent, ctx_share, ctx_task, ctx_handoff, ctx_workflow
Verify: ctx_benchmark, ctx_verify, ctx_proof, ctx_review
Batch: ctx_fill, ctx_pack

Full docs: https://leanctx.com/docs
