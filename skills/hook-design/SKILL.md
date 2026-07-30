---
name: hook-design
description: "Framework for deciding what becomes a Claude Code hook: lifecycle events, signal words, hook vs. prompt judgment, and adoption strategy. Invoked automatically during skill-extraction."
risk: safe
source: local
---

# Hook Design

Reference framework for deciding when a capability should be a Claude Code hook vs. a prompt, skill, or config change.

## Core Principle

> Use prompts for guidance. Use hooks for behavior that should run every time.

Hooks provide **deterministic enforcement** at known lifecycle points. Prompts provide **reasoning guidance** that may or may not be followed.

## When to Use a Hook

**Signal words that indicate a hook:**

| Word in requirement | Hook event |
|---|---|
| "always" | PreToolUse or PostToolUse |
| "never" / "block" | PreToolUse (exit 2 to hard-block, exit 0 + warning to soft-gate) |
| "record" / "log" / "audit" | PostToolUse or Stop |
| "run" / "verify" / "validate" | PostToolUse |
| "before X, check Y" | PreToolUse |
| "after X, do Y" | PostToolUse |
| "at session start" | SessionStart |
| "at session end" | Stop |

**Use a hook when:** the behavior is required unconditionally, regardless of reasoning or conversational context.  
**Use a prompt/skill when:** the behavior is guidance that should adapt to context.

## Six Lifecycle Events

| Event | Fires when | Harness examples |
|---|---|---|
| `SessionStart` | Session opens, before first message | `session-start-hook.sh` (maintenance catch-up) |
| `UserPromptSubmit` | User sends a message, before model processes | Context routing, prompt inspection |
| `PreToolUse` | Before a tool call executes | `protected-path-hook.sh`, `pre-tool-use-gitnexus.sh` |
| `PostToolUse` | After a tool call succeeds | `impeccable-detect-hook.sh`, `revert-detect-hook.sh` |
| `Stop` | When Claude finishes a turn | `stop-hook.sh` (health checks) |
| `PreCompact` | Before context compaction | `compaction-discipline-hook.sh` |

## Hook Strength

| Exit code | Effect |
|---|---|
| 0 | Allow — Claude sees any stdout output as context before the tool runs |
| 2 | Block — tool call is cancelled; stdout shown as the reason |

**Soft gate (ask user):** Exit 0 + output a `⚠️ CONFIRMATION REQUIRED:` banner. Claude reads it and must explicitly ask the user before proceeding.  
**Hard block:** Exit 2 + output reason. Tool call is unconditionally cancelled.

Use soft gates when the action is sometimes legitimate. Use hard blocks only for actions that should never happen under any circumstance.

> **Enforcement scope:** `settings.json` `deny` rules are unreliable — even Claude's own tool calls can bypass them (proven by fa1ce38: a `git push --force` executed successfully despite a matching deny entry). Use a PreToolUse hard-block hook (exit 2) as the actual enforced mitigation. GitHub branch protection provides an independent remote-layer guard. (fa1ce38, 2026-07-30)

## Harness Hook Conventions

- Hook source files live in `~/.claude/sdd-harness/hooks/` and get installed to `<project>/.claude/hooks/`
- Parse tool input from stdin: `EVENT=$(cat)` then extract `tool_input` fields with python3
- Use `set -euo pipefail` at the top
- Register in `<project>/.claude/settings.json` under the appropriate event + matcher
- Multiple hooks can share the same event + matcher — they run sequentially

**Stdin parsing pattern:**

```bash
EVENT=$(cat)
FILE_PATH=$(echo "$EVENT" | python3 -c "
import json, sys
try:
    e = json.load(sys.stdin)
    inp = e.get('tool_input', {})
    print(inp.get('file_path', inp.get('path', '')))
except Exception:
    print('')
" 2>/dev/null || echo "")
```

## Adoption Order (low to high complexity)

1. **Protected-path enforcement** — PreToolUse Write|Edit, file-path matching, soft gate or hard block
2. **Content quality gates** — PostToolUse Write|Edit, run linters/scanners on written files
3. **Command policy** — PreToolUse Bash, block destructive shell patterns
4. **Post-action state persistence** — PostToolUse Bash, run tests, write `.hook-state/` JSON
5. **Completion gates** — Stop reads state file, blocks if quality gate failed
6. **Context routing** — UserPromptSubmit, keyword matching, inject invariants per topic

## Evaluating Hook Candidates

For each capability extracted from a resource, ask:

1. Should this run **every time** the trigger fires, not just when Claude reasons it should?
2. Does it describe an **enforcement pattern** — block, log, validate, always, never?
3. Is it **lifecycle-aware** — on-save, on-session-start, on-finish?
4. Would a **prompt or skill fail** to reliably enforce this (e.g., Claude could forget or skip it)?

If yes to any → propose a hook. Pick the event from the table above, choose soft gate vs. hard block based on whether the action is ever legitimate.

## Observer Loop Prevention

A hook that fires on Write/Edit can itself cause writes (state files, linters, formatters), re-triggering the same hook — an infinite loop. Prevent this with three patterns, applied in order:

**1. Env-var sentinel (cheapest — add to every hook)**

```bash
[[ "${SDD_HOOK_RUNNING:-}" == "1" ]] && exit 0
export SDD_HOOK_RUNNING=1
```

This stops re-entrancy within a single hook chain. Reset is automatic because child processes inherit but don't propagate env changes back.

**2. Matcher specificity (design-time)**

Prefer specific tool matchers (`Write|Edit`) over blank matchers. A blank matcher fires on every tool call — including tool calls made by hooks themselves.

**3. State-file lock (for hooks that spawn subprocesses)**

```bash
LOCK="/tmp/sdd-hook-$(basename "$0").lock"
[ -f "$LOCK" ] && exit 0
trap 'rm -f "$LOCK"' EXIT
touch "$LOCK"
```

Use this when a hook runs an external process (linter, test runner) that may itself trigger tool calls back into Claude.

**Smell test:** If your hook writes a file or runs a command that writes a file, add the env-var sentinel. If it uses a blank matcher, switch to a specific one.

**4. Commit-message sentinel + atomic mkdir lock (for native git hooks that commit into watched paths)**

Patterns 1–3 assume a hook running inside a single Claude process. Native git hooks (post-commit, post-merge) are spawned fresh per commit — they inherit no env, so the env-var sentinel (pattern 1) is reset each invocation. The racy `touch` lock (pattern 3) can be stolen between `[ -f ]` and `touch`. Use both of these instead:

```bash
# Step 1 — bail if the just-landed commit is our own work (commit-message sentinel)
case "$(git log -1 --format=%s 2>/dev/null)" in
  "docs: auto-sync"*) exit 0 ;;   # replace with your hook's commit prefix
esac

# Step 2 — atomic lock so concurrent runs don't race the git index
LOCKDIR="$REPO_ROOT/.git/my-hook.lock"
# Steal locks stale for >30 min (handles crashed runs)
[ -d "$LOCKDIR" ] && [ -n "$(find "$LOCKDIR" -maxdepth 0 -mmin +30 2>/dev/null)" ] && rmdir "$LOCKDIR" 2>/dev/null
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  exit 0  # another run is active; skip silently
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
```

`mkdir` is POSIX-atomic; `touch` is not. Use `mkdir` for all new hook locks. When retrofitting pattern 3 hooks, upgrade `touch "$LOCK"` → `mkdir "$LOCK"` and add stale-lock theft.

**Worked example:** sdd-harness `post-commit` auto-sync hook (fc50068, 1b0e617, 2026-07-28). HARNESS_CHANGED matched `.md` under `skills/` and `hooks/`, so the hook's own `docs: auto-sync` commits re-fired the agents — 9 loop commits in ~40 minutes. The commit-message sentinel + mkdir lock stopped the loop.

## Session Profile Switching

Some sessions need hooks quieted: heavy refactors where quality-gate noise is counterproductive, or debugging the hooks themselves. Add this preamble to any hook that should respect profile switching:

```bash
# Respect session hook profile
case "${SDD_HOOK_PROFILE:-standard}" in
  off)     exit 0 ;;
  minimal) [[ "$HOOK_CLASS" != "validation" ]] && exit 0 ;;
  standard) ;;  # run normally
esac
```

Set `HOOK_CLASS` at the top of each hook to one of: `validation` (protected-path, memory-discipline), `quality` (linting, formatting), `notification` (hook-added-notify).

**Usage:**

```bash
# Quiet all hooks for this shell session
export SDD_HOOK_PROFILE=off

# Keep only validation hooks (protected-path, memory-discipline)
export SDD_HOOK_PROFILE=minimal

# Restore normal behavior
unset SDD_HOOK_PROFILE
```

Profile is checked at runtime — no settings.json edit needed. Reset when the session ends.
