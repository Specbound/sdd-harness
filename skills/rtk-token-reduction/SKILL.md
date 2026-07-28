---
name: rtk-token-reduction
description: RTK advanced usage NOT covered by the always-loaded ~/.claude/RTK.md — when to bypass with rtk proxy, configuring exclusions, tee mode, and --ultra-compact. Use when compressed output hides needed detail or a command needs an exclusion.
risk: safe
source: https://github.com/rtk-ai/rtk
---

# RTK — Advanced Usage

`~/.claude/RTK.md` (always loaded) covers the meta commands (`rtk gain`, `rtk discover`, `rtk proxy`, install checks) and the hook that transparently rewrites Bash calls. This skill covers only what it doesn't: bypass decisions, configuration, and extra compression.

## When to bypass with `rtk proxy <cmd>`

Only when exact raw output is required:
- Piping to another tool that parses stdout: `rtk proxy git log --format="%H" | head -5`
- Debugging a hook/script that reads exact output
- Verbatim before/after output comparison
- Compression is dropping detail you need right now (one-off; return to compressed defaults after)

Never bypass just to avoid RTK — if compression keeps losing needed detail for a command, add an exclusion instead (below).

## Configuration and exclusions

Config: `~/Library/Application Support/rtk/config.toml` (macOS). Show/create with `rtk config`.

```toml
[hooks]
exclude_commands = ["curl", "playwright"]  # exact prefix match, never rewritten

[tee]
enabled = true
mode = "failures"   # save raw outputs: "failures" | "always" | "never"
```

Add an exclusion when RTK misidentifies a command or a script needs exact output every time.

## Extra compression

`--ultra-compact` on any rtk command (ASCII icons, inline format) — for very long test suites or near context limits:

```bash
rtk --ultra-compact pytest tests/
```

## Preview a rewrite

```bash
rtk hook check <cmd>   # shows how the hook would rewrite the command
```
