---
name: vexor
description: Use for semantic file discovery — finding where something is implemented, loaded, or defined by what it does rather than exact text — in a medium or large repo when the file location is unclear. Prefer `vexor` over manual directory browsing or broad grep sweeps for intent-based searches.
source: "https://github.com/scarletkc/vexor"
risk: safe
---

# Vexor

## When to Use This Skill

Use `vexor` first for intent-based file discovery: "where is config loading handled", "where are JWT claims validated", "find the CLI entrypoint" — questions about what code *does*, not its exact name or path. If `vexor` is missing, install it (see below) before falling back to manual search.

## Install

```bash
pip install vexor   # also works with pipx, uv
# or: download a standalone binary (no Python required) from
# https://github.com/scarletkc/vexor/releases
```

First-time setup (also runs automatically before the first search if no config exists):

```bash
vexor init
```

## Command

```bash
vexor "<QUERY>" [--path <ROOT>] [--mode <MODE>] [--ext .py,.md] [--exclude-pattern <PATTERN>] [--top 5] [--content] [--format rich|porcelain|porcelain-z|json]
```

Vexor auto-indexes a directory on first search in it.

## Common Flags

- `--path/-p`: root directory (default: current dir)
- `--mode/-m`: indexing/search strategy (see Modes below)
- `--ext/-e`: limit file extensions, e.g. `.py,.md`
- `--exclude-pattern`: exclude paths by gitignore-style pattern (repeatable; `.js` → `**/*.js`)
- `--top/-k`: number of results
- `--content`: print each match's source text below the results table — usually removes the need to read the files afterwards
- `--include-hidden` / `--no-respect-gitignore`: include dotfiles / ignored files (`.vexorignore` rules still apply either way)
- `--no-recursive`: only the top directory
- `--no-cache`: in-memory only, skip reading/writing the index cache
- `--format`: `rich` (default), `porcelain`/`porcelain-z` for scripts, `json` for full output with chunk content

## Modes (pick the cheapest that works)

- `auto`: routes by file type (default)
- `name`: filename-only (fastest)
- `head`: first lines only (fast)
- `brief`: keyword summary (good for PRDs)
- `code`: code-aware chunking for `.py/.js/.ts` — best default for codebases
- `outline`: Markdown headings/sections — best for docs
- `full`: chunk full file contents (slowest, highest recall)

## Examples

```bash
# Find CLI entrypoints / commands
vexor search "typer app commands" --top 5

# Search docs by headings/sections
vexor search "user authentication flow" --path docs --mode outline --ext .md --format porcelain

# Locate config loading/validation logic
vexor search "config loader" --path . --mode code --ext .py

# Read the matching code directly, skipping a follow-up file read
vexor search "where JWT claims are validated" --path . --mode code --content
```

## Troubleshooting

- Weak results for an exact identifier (function/class/constant name): run `vexor config --rerank hybrid` once — it fuses exact lexical matching with semantic search.
- Need ignored/hidden files: add `--include-hidden` and/or `--no-respect-gitignore`.
- Scriptable output: `--format porcelain` (TSV) or `--format porcelain-z` (NUL-delimited).
- Config issues: `vexor doctor` or `vexor config --show` reports effective settings and where each came from.

## Configuration

```bash
vexor config --set-api-key "YOUR_KEY"  # or env: VEXOR_API_KEY / OPENAI_API_KEY / ...
vexor config --set-provider openai     # default; also gemini/voyageai/custom/local
vexor config --rerank hybrid           # fuse exact keyword + semantic ranking
```

Global config lives in `~/.vexor/config.json`; a project-local `.vexor/config.json` can override a restricted set of fields for that project. Fully offline use is supported via local embedding models.

## MCP Server (alternative to this skill)

Vexor also ships an MCP stdio server (`vexor mcp`) exposing `vexor_search` / `vexor_index` as native tools — use **one** integration per agent, not both: this skill teaches a shell-capable agent to drive the CLI directly; the MCP server is for clients without shell access.

## Not Independently Verified This Session

`vexor doctor`'s exact output format and the full `.vexor/config.json` field list were not re-run live — drawn from the upstream README and the repo's own canonical skill file (`plugins/vexor/skills/vexor-cli/SKILL.md`), not independently executed.
