# GitNexus Integration — Code Intelligence + Visual Explorer

> Optional integration that gives SDD harness agents graph-backed code intelligence via [GitNexus](https://github.com/abhigyanpatwari/GitNexus), and lets users visually explore codebase connections through the GitNexus Web UI.

## What It Is

GitNexus is a zero-server code intelligence engine that builds a knowledge graph from your codebase — symbols, dependencies, call chains, execution flows — and exposes it via MCP tools. The SDD harness integration is **opt-in**: when GitNexus is present, harness agents gain graph-backed context. When absent, everything works as before.

The integration adds three capabilities:

1. **Impact detection in verify pipeline** — Graph-backed blast radius analysis before build/test/lint
2. **Community-seeded skill extraction** — Leiden-detected functional clusters as extraction candidates
3. **Visual exploration** — Launch the GitNexus Web UI to browse connections, call chains, and process flows in a browser

## How It Works

### Architecture

```
┌─ SDD Harness ─────────────────────────────────────┐
│                                                     │
│  /kiro:gitnexus-setup                              │
│    → installs gitnexus, runs initial index          │
│    → configures MCP server in settings.json         │
│    → registers post-commit reindex hook              │
│                                                     │
│  /kiro:gitnexus-explore                            │
│    → starts gitnexus serve (HTTP backend)           │
│    → opens Web UI in browser                        │
│    → browse symbols, call chains, processes          │
│                                                     │
│  /kiro:gitnexus-impact                             │
│    → queries GitNexus detect_changes MCP tool        │
│    → maps current git diff to affected processes     │
│    → reports blast radius with risk levels           │
│                                                     │
│  verify-agent (Stage 0 — optional)                  │
│    → if GitNexus MCP available, detect_changes      │
│    → flags HIGH risk semantic regressions            │
│    → proceeds to existing build/test/lint pipeline   │
│                                                     │
│  skill-extract-agent (optional seeding)             │
│    → if GitNexus MCP available, query communities   │
│    → use clusters as extraction candidates           │
│    → fall back to Glob+Grep scanning if unavailable  │
│                                                     │
└─────────────────────────────────────────────────────┘
         │                       │
         ▼                       ▼
┌─ GitNexus MCP ──┐    ┌─ GitNexus Web UI ──┐
│ query            │    │ gitnexus serve     │
│ context          │    │ → localhost:4567   │
│ impact           │    │ → WebGL graph      │
│ detect_changes   │    │ → symbol browser   │
│ rename           │    │ → process flows    │
│ cypher           │    └────────────────────┘
│ list_repos       │
└──────────────────┘
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

## Agent Enhancements

| Agent | Enhancement |
|---|---|
| `verify-agent` | Optional Stage 0: graph-backed `detect_changes` before build/test pipeline |
| `skill-extract-agent` | Optional community seeding: Leiden clusters as extraction candidates |

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
