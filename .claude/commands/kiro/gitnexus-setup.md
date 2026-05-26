---
description: Install GitNexus, index the repo, and configure MCP + hooks
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: [--skip-embeddings] [--force]
---

# GitNexus Setup

One-command setup for GitNexus code intelligence integration. Installs GitNexus, indexes the current repository, configures the MCP server, and sets up auto-reindex hooks.

## Parse Arguments

- `--skip-embeddings`: Skip vector embeddings during indexing (faster, still useful)
- `--force`: Force re-index even if `.gitnexus/` already exists

## Step 1: Check / Install GitNexus

```bash
if command -v gitnexus >/dev/null 2>&1 || npx gitnexus --version >/dev/null 2>&1; then
  echo "GitNexus is already installed."
else
  echo "Installing GitNexus..."
  npm install -g gitnexus
fi
```

If `npm` is not available, tell the user:
```
npm is required to install GitNexus. Install Node.js first:
  https://nodejs.org/
```
Then stop.

## Step 2: Index the Repository

Check if `.gitnexus/` exists and `--force` was not passed:
- If exists: skip indexing, report "Repository already indexed. Use --force to re-index."
- If missing or `--force`: run indexing

```bash
npx gitnexus analyze [--skip-embeddings if flag passed]
```

Report indexing progress to the user. If indexing fails, show the error output and stop.

## Step 3: Configure MCP Server

Read `.claude/settings.json`. If it exists, check whether `mcpServers.gitnexus` is already configured.

If not configured, add the GitNexus MCP server:

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

Merge with existing settings — do not overwrite other MCP servers or permissions.

If already configured, report "MCP server already configured."

## Step 4: Add .gitnexus/ to .gitignore

Check `.gitignore` for `.gitnexus/`:
```bash
grep -qF '.gitnexus/' .gitignore 2>/dev/null
```

If not present, append:
```
# GitNexus index (local, regenerable)
.gitnexus/
```

## Step 5: Register Editor Integration

```bash
npx gitnexus setup
```

This configures the MCP server for supported editors (Claude Code, Cursor, Codex, Windsurf).

## Step 6: Report

```
GitNexus setup complete.

  Index:     .gitnexus/ (created)
  MCP:       configured in .claude/settings.json
  Gitignore: .gitnexus/ added

Available commands:
  /kiro:gitnexus-explore   — Launch visual Web UI to browse connections
  /kiro:gitnexus-impact    — Query blast radius for current changes

Enhanced agents:
  /kiro:verify             — Now includes optional Stage 0 (impact detection)
  /kiro:skill-extract-scan — Now seeds from GitNexus community clusters

Documentation: .claude/docs/gitnexus/README.md
```
