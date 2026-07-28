# GitNexus Integration — Code Intelligence + Visual Explorer

> Optional integration that gives SDD harness agents graph-backed code intelligence via [GitNexus](https://github.com/abhigyanpatwari/GitNexus), and lets users visually explore codebase connections through the GitNexus Web UI.

## What It Is

GitNexus is a zero-server code intelligence engine that builds a knowledge graph from your codebase — symbols, dependencies, call chains, execution flows — and exposes it via MCP tools. The SDD harness integration is **opt-in**: when GitNexus is present, harness agents gain graph-backed context. When absent, everything works as before.

The integration adds six automatic capabilities and one manual command:

**Automatic (wired into existing workflows — no extra commands needed):**

1. **PreToolUse context enrichment** — Every file read/edit is automatically enriched with GitNexus 360-degree symbol context (callers, dependencies, process participation). Agents see the blast radius of every file they touch.
2. **Auto-reindex on commit** — The post-commit hook re-indexes the repo after every commit so the knowledge graph stays fresh. Exception: the hook's own `docs: auto-sync` commits are skipped by its self-commit guard, which bails before the reindex stage.
3. **Impact detection in verify pipeline** — `verify-agent` Stage 0 runs `detect_changes` automatically, flagging HIGH risk semantic regressions before build/test/lint.
4. **Blast radius in spec-impl** — Before TDD implementation, `spec-impl` scans all files it will modify for downstream dependents, writing tests that cover affected code.
5. **Call chain tracing in debug** — `debug-agent` Step 2 (Localize) queries GitNexus for the full call chain instead of manually grepping for callers.
6. **Community-seeded skill extraction** — `skill-extract-agent` uses Leiden-detected functional clusters as extraction candidates.

**Manual (on-demand):**

7. **Visual exploration** — `/kiro:gitnexus-explore` launches the GitNexus Web UI to browse connections in a browser

## How It Works

### Architecture

```
┌─ SDD Harness (automatic wiring) ───────────────────────────────────────┐
│                                                                         │
│  PreToolUse hook (every Read/Edit/MultiEdit)                           │
│    → queries GitNexus context for the target file                       │
│    → injects callers, dependencies, process participation               │
│    → all agents see blast radius automatically                          │
│                                                                         │
│  post-commit hook (every git commit)                                    │
│    → runs gitnexus analyze --skip-embeddings in background              │
│    → knowledge graph stays fresh without manual reindex                  │
│                                                                         │
│  verify-agent (Stage 0 — automatic)                                     │
│    → detect_changes on git diff before build/test/lint                  │
│    → flags HIGH risk semantic regressions                               │
│                                                                         │
│  spec-impl (Step 1 — automatic)                                        │
│    → scans design.md/tasks.md files for downstream dependents           │
│    → builds dependency map before TDD cycle begins                      │
│    → tests cover affected downstream code, not just changed code        │
│                                                                         │
│  debug-agent (Step 2 — automatic)                                       │
│    → queries GitNexus context/impact for suspect symbols                │
│    → traces full call chain instead of manual grep                      │
│                                                                         │
│  skill-extract-agent (Stage 2 — automatic)                              │
│    → seeds candidates from Leiden community clusters                    │
│    → falls back to Glob+Grep if GitNexus unavailable                    │
│                                                                         │
│  /kiro:gitnexus-setup (one-time, manual)                               │
│    → installs gitnexus, indexes repo, configures MCP                    │
│                                                                         │
│  /kiro:gitnexus-explore (on-demand, manual)                            │
│    → launches Web UI at localhost:4567                                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
         │                       │
         ▼                       ▼
┌─ GitNexus MCP ──────┐    ┌─ GitNexus Web UI ──┐
│ query               │    │ gitnexus serve     │
│ context             │    │ → localhost:4567   │
│ impact              │    │ → WebGL graph      │
│ detect_changes      │    │ → symbol browser   │
│ rename              │    │ → process flows    │
│ cypher              │    └────────────────────┘
│ list_repos          │
│ group_list          │
│ group_sync          │
│ group_contracts     │
│ group_query         │
│ group_status        │
│ [prompt] detect_impact  │
│ [prompt] generate_map   │
└─────────────────────┘
```

### Graceful Degradation

Every integration point checks for GitNexus availability first:

```
if gitnexus is available:
    use graph-backed intelligence
else:
    use existing grep/glob/steering-based approach (unchanged)
```

No harness functionality degrades when GitNexus is absent.

## Commands

| Command | Purpose |
|---|---|
| `/kiro:gitnexus-setup` | Install GitNexus, index the repo, configure MCP + hooks |
| `/kiro:gitnexus-explore` | Launch the Web UI to visually browse code connections |
| `/kiro:gitnexus-impact` | Query blast radius for current changes |
| `/kiro:gitnexus-wiki` | Generate architecture wiki from the knowledge graph |

## Automatic Agent Enhancements

All enhancements activate automatically when `.gitnexus/` exists. No commands needed.

| Agent | Enhancement | Trigger |
|---|---|---|
| **All agents** | 360-degree context injected on every file read/edit via PreToolUse hook | Every `Read`/`Edit`/`MultiEdit` tool call |
| `verify-agent` | Stage 0: `detect_changes` maps git diff to affected processes with risk levels | Every `/kiro:verify` run |
| `spec-impl` | Blast radius scan of all files to be modified; dependency map informs TDD test coverage | Every `/kiro:spec-impl` run |
| `debug-agent` | Call chain tracing via `context`/`impact` queries in Step 2 (Localize) | Every `/kiro:debug` run |
| `skill-extract-agent` | Leiden community clusters as extraction candidate seeds | Every `/kiro:skill-extract-scan` run |

## Automatic Infrastructure

| Component | Enhancement | Trigger |
|---|---|---|
| `post-commit` hook | Re-indexes repo (`gitnexus analyze --skip-embeddings`) in the background, fully detached (stdin `/dev/null`, stdout/stderr discarded) so it never prints into or blocks the terminal | Every `git commit`, except the hook's own `docs: auto-sync` commits (self-commit guard exits first) |
| `PreToolUse` hook | Queries GitNexus for file context, injects into agent conversation | Every file read/edit |

## Use Cases

### 1. Pre-change impact check
```
/kiro:gitnexus-impact
```
Maps your current `git diff` to affected execution flows. Shows which processes break, at what depth, with confidence scores. Run this before `/kiro:verify` to catch semantic regressions that linting and tests miss.

### 2. Visual exploration during debugging
```
/kiro:gitnexus-explore
```
Opens a browser-based graph view of your codebase. Navigate symbol relationships, trace call chains, inspect process flows. Useful when `/kiro:debug` identifies a suspicious area and you want to understand its connections visually.

### 3. Architecture review before spec design
```
/kiro:gitnexus-explore
```
Before running `/kiro:spec-design`, open the visual explorer to understand how existing code is structured. Identify the right integration points, spot coupling patterns, and find the natural boundaries for your feature.

### 4. Enhanced skill extraction
```
/kiro:skill-extract-scan /path/to/repo
```
When GitNexus is indexed on the target repo, the skill extraction pipeline seeds its candidates from algorithmically-detected functional communities instead of text-search heuristics.

### 5. Full verification with impact analysis
```
/kiro:verify full
```
When GitNexus is available, the verify pipeline adds a Stage 0 that checks for high-risk semantic regressions before running the standard build/test/lint stages.

## Setup

### Quick setup (recommended)
```
/kiro:gitnexus-setup
```
This command handles everything: installs GitNexus (if needed), indexes the current repo, configures the MCP server, and sets up the post-commit reindex hook.

### Manual setup

#### 1. Install GitNexus
```bash
npm install -g gitnexus
```

#### 2. Index your repository
```bash
cd /path/to/your/project
gitnexus analyze
```
This creates a `.gitnexus/` directory (gitignored) with the knowledge graph index.

#### 3. Configure MCP server

Add to your project's `.claude/settings.json`:
```json
{
  "mcpServers": {
    "gitnexus": {
      "command": "npx",
      "args": ["-y", "gitnexus", "mcp"],
      "env": {}
    }
  }
}
```

#### 4. Register for editor integration
```bash
gitnexus setup
```

### With install.sh

```bash
~/.claude/sdd-harness/install.sh /path/to/project --with-gitnexus
```

The `--with-gitnexus` flag adds GitNexus configuration during harness installation.

## Web UI

The GitNexus Web UI runs entirely in your browser — no data leaves your machine.

### Features
- **WebGL graph visualization** — Sigma.js-powered interactive graph
- **Symbol browser** — Search and inspect functions, classes, methods
- **Call chain tracing** — Follow execution flows from entry points
- **Process flow view** — See which symbols participate in which processes
- **Dependency mapping** — Incoming/outgoing relationships with confidence scores
- **Community clusters** — Color-coded functional groups (Leiden algorithm)

### Launching
```
/kiro:gitnexus-explore
```
Or manually:
```bash
gitnexus serve        # starts HTTP server on localhost:4567
# open http://localhost:4567 in your browser
```

### Browser mode (no backend)
The Web UI also works standalone — drag-and-drop a ZIP of your repo into the browser UI at the GitNexus web app. Limited to ~5k files in pure browser mode.

## Repository Groups (Multi-Repo Analysis)

GitNexus can extract contracts across multiple repositories and trace cross-repo execution flows — useful when working on microservices, monorepos with sub-packages, or any system where code spans multiple repos.

### Setup a group
```bash
gitnexus group create my-services
gitnexus group add my-services /path/to/api-service api-service
gitnexus group add my-services /path/to/worker-service worker-service
```

### Use it
```bash
gitnexus group sync my-services         # extract contracts (interfaces, shared symbols)
gitnexus group contracts my-services    # inspect what was found
gitnexus group query my-services "payment flow"  # search across all repos
gitnexus group status my-services       # check index staleness
```

### MCP tools (available inside Claude)
| Tool | What it does |
|---|---|
| `group_list` | List configured repository groups |
| `group_sync` | Extract contracts and cross-match across repos |
| `group_contracts` | Inspect extracted contracts and links |
| `group_query` | Search execution flows across group repos |
| `group_status` | Check staleness of repos in a group |

---

## Wiki Generation

Generate architecture documentation from the knowledge graph:

```bash
gitnexus wiki                          # generate wiki for current repo
gitnexus wiki /path/to/project         # specify path
gitnexus wiki --model gpt-4o           # custom LLM
gitnexus wiki --base-url http://...    # custom API base
```

Produces markdown docs covering symbols, processes, and execution flows — seeded from the graph rather than written manually. Use `/kiro:gitnexus-wiki` to invoke this from within the harness.

The `generate_map` MCP prompt (usable directly in Claude) generates mermaid architecture diagrams from the knowledge graph without needing to run the CLI.

---

## Skill Generation

The `--skills` flag generates repo-specific skills from the knowledge graph during indexing:

```bash
gitnexus analyze --skills
```

GitNexus uses Leiden community detection to identify functional clusters and writes skills for each cluster. These are in addition to skills the harness's own `/kiro:skill-extract-scan` produces.

---

## Maintenance

```bash
gitnexus status          # show index status
gitnexus list            # list all indexed repos
gitnexus clean           # delete current repo's index
gitnexus clean --all --force  # delete all indexes
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `gitnexus: command not found` | Not installed globally | `npm install -g gitnexus` |
| MCP tools not appearing in Claude | MCP server not configured | Run `/kiro:gitnexus-setup` or add `mcpServers` config manually |
| Stale index (changes not reflected) | Index not updated after code changes | `gitnexus analyze` or enable post-commit hook |
| Web UI won't load | Port 4567 in use | Kill other process or use `gitnexus serve --port 4568` |
| `detect_changes` returns empty | No uncommitted changes | Make changes first, or use `gitnexus impact --from HEAD~1` |
| Stage 0 skipped in verify | GitNexus MCP not available | Expected behavior — Stage 0 is opt-in |
| Slow initial index | Large repo with embeddings | Use `gitnexus analyze --skip-embeddings` for faster indexing |
