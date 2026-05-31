---
name: rtk-token-reduction
description: "Use when running shell commands that could bloat context: git operations, test runners, build tools, linters, Docker, kubectl, AWS CLI. RTK transparently rewrites Bash commands to compressed equivalents. Activate to decide when to use rtk proxy (exact output), rtk gain (track savings), or how to configure exclusions."
risk: safe
source: https://github.com/rtk-ai/rtk
---

# RTK Token Reduction

RTK (Rust Token Killer) intercepts Bash commands via a Claude Code PreToolUse hook and rewrites them to compressed equivalents — 60-90% fewer tokens on common dev operations. The hook is already active; this skill covers when and how to use RTK deliberately.

## When this skill activates

- Running git, pytest, jest, vitest, cargo test, rspec — output would be verbose
- Building (tsc, eslint, ruff, cargo build, next build) — errors need compression
- Checking Docker, kubectl, AWS CLI output in context
- Need exact raw output for piping or debugging (→ use `rtk proxy`)
- User asks about token savings, `rtk gain`, or how the hook works

## How the hook works

The `rtk hook claude` PreToolUse Bash hook intercepts every Bash call. If RTK knows the command, it rewrites it to `rtk <cmd>` and emits `"permissionDecision":"allow"` — no prompt, no delay. Unknown commands pass through unchanged.

## Phase 1: Command Rewrites (happens automatically)

RTK rewrites these command families silently:

| Category | Commands | Typical savings |
|---|---|---|
| Version control | git status/log/diff/push/commit/add | 80-90% |
| Test runners | pytest, jest, vitest, cargo test, rspec, go test | 85-90% |
| Type/lint | tsc, eslint (via npx), mypy, ruff, rubocop, golangci-lint | 70-85% |
| Build | next build, cargo build, dotnet build | 60-75% |
| Containers | docker, kubectl | 60-80% |
| Cloud | aws | 50-70% |
| Package mgmt | npm, pnpm, pip | 40-60% |
| Files | ls, find, grep, diff, tree | 40-70% |

## Phase 2: When to use rtk proxy (bypass)

Use `rtk proxy <cmd>` when exact output is required:
- Piping output to another tool: `rtk proxy git log --format="%H" | head -5`
- Debugging a hook or script that reads exact stdout
- Comparing output before/after a change verbatim
- A command is being compressed in a way that loses needed detail

**Never** use `rtk proxy` just to avoid RTK — it disables filtering and still tracks usage. If you genuinely need full output, `rtk proxy` is the right tool.

## Phase 3: Tracking savings

```bash
rtk gain               # Summary: total tokens saved, % reduction
rtk gain --history     # Per-command breakdown (last N runs)
rtk gain --graph       # ASCII chart of daily savings
rtk gain -p            # Filter to current project directory
rtk discover           # Scan Claude Code history for commands that missed RTK
```

Run `rtk gain` when the user asks "how much have we saved?" or after a heavy session.

## Phase 4: Configuration

Config file: `~/Library/Application Support/rtk/config.toml` (macOS)

```toml
[hooks]
# Commands RTK will NOT rewrite (exact prefix match)
exclude_commands = ["curl", "playwright"]

[tee]
# Save raw outputs: "failures" | "always" | "never"
enabled = true
mode = "failures"
```

Create or view config: `rtk config`

Add an exclusion when a command's compressed output is causing problems — e.g., a test framework that RTK misidentifies, or a custom script that parses exact output.

## Phase 5: Ultra-compact mode

Append `--ultra-compact` to any `rtk` command for extra compression (ASCII icons, inline format):

```bash
rtk --ultra-compact git status
rtk --ultra-compact pytest tests/
```

Use for very long test suites or when context is near limits.

## ZTK migration note

This harness previously used `ztk rewrite --skip-permissions` (v0.3.1). RTK v0.42.0 replaces it:
- `ztk run <cmd>` → `rtk proxy <cmd>`
- `ztk stats` → `rtk gain`
- `ztk rewrite` → `rtk hook claude` (built into PreToolUse hook)

## Quick reference

```bash
rtk gain               # Check savings
rtk proxy <cmd>        # Raw output, no filtering
rtk hook check <cmd>   # Preview how a command would be rewritten
rtk discover           # Find missed savings in session history
rtk config             # Show/create config file
rtk --version          # Confirm version (should be 0.42.0+)
```
