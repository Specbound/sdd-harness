---
name: cheap-model-delegation
description: Delegate bulk, low-judgment multi-file reading/summarizing work to a cheap-tier subagent instead of doing it inline at the primary model's rate. Use for monorepo-wide skims, multi-file audits, or any task that's mostly "read N files and extract X" with no deep reasoning per file.
source: "engineering.atspotify.com — Portal by Spotify cut Claude Code token usage by 90%"
---

# Cheap Model Delegation

**Scope note:** a single large-file `Read` is already hard-gated by `lean-ctx-nudge-hook.sh`, which redirects to `ctx_read`'s compression modes — that case is solved and this skill doesn't touch it. This skill covers the layer above: work that's inherently **many files, low judgment per file** (skim a monorepo for a pattern, extract one field from every config file, summarize every changelog in a directory) where compressing one read at a time still burns primary-model tokens on repetitive, mechanical extraction.

## When to Use

- The task is "look at N files and extract/report X" where X is simple per file (a value, a yes/no, a one-line summary) and N is large (dozens+)
- A monorepo-wide skim where most files are irrelevant and only a few need real reasoning
- Any bulk-read task where you'd otherwise `ctx_read`/`Read` many files back-to-back at full model rate just to extract small facts from each

## Do Not Use When

- Fewer than ~10 files, or the extraction requires real judgment per file (not just pattern matching) — delegation overhead isn't worth it
- The task needs cross-file reasoning that a cheap model would do poorly (e.g. "does this change break any of these 20 files" — that needs real reasoning, not per-file extraction)

## How to Delegate

1. **Confirm the task is extraction-shaped**, not reasoning-shaped: can you write one sentence describing what to pull from each file, independent of the other files? If yes, it delegates cleanly.
2. **Dispatch a cheap-tier subagent** (see `model-tiers`'s utility tier — `haiku`) via the `Agent` tool with a tight tool allowlist (Read/Grep only, no Write/Edit) and an explicit output contract (e.g. "one line per file: `<path>: <extracted value>`").
3. **Batch the file list** into the subagent's prompt rather than looping one file per subagent call — one dispatch covering 50 files beats 50 dispatches.
4. **Consume the structured output** at the primary model tier — do the actual judgment/synthesis step yourself, using the cheap-tier extraction as raw material.

## Automation Note

This is a **user/task-invoked pattern, not a hard hook** — unlike the single-large-file case, "is this task bulk-extraction-shaped" requires judgment a PreToolUse gate can't make reliably (a Bash `cat file1 file2 file3` could be a legitimate 3-file read or the start of a 50-file loop; blocking on file count alone would false-positive on ordinary small multi-file reads). `hooks/claude/cheap-model-delegation-hook.sh` provides a **soft, advisory-only** nudge — it fires when a single Bash command reads more than a handful of files in one call, prints a reminder to consider this skill, and never blocks. Treat it as a prompt, not a gate; the actual decision to delegate stays with you.

## Related Skills

- `model-tiers` — model tier selection (this pattern uses the utility/haiku tier)
- `rtk-token-reduction` — subagent token caps and TALE-EP budget sizing, for capping the cheap subagent's own output
- `lean-ctx` rules (`.claude/rules/lean-ctx.md`) — the single-file compression path this skill does not duplicate
