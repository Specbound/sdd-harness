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

## Fail Closed, Narrow Only (blocking hooks)

Two rules for any hook that can exit 2. Neither applies to advisory hooks that always exit 0.

**1. Fail closed.** A blocking hook whose own machinery fails must not allow the call. That covers `python3` off PATH, malformed event JSON, and an analyzer crash. The fail-open shape is `|| echo ""` or `except: print('')` followed by `[ -z "$X" ] && exit 0`. It turns a broken interpreter into a silent allow. Scope the failure block so a broken dependency does not take down every tool call. Block only when the raw event mentions what the hook protects, using a literal glob:

```bash
fail_closed() {
  case "$EVENT" in
    *git*|*"gh "*) ;;          # the hook's protected surface, literal match
    *) exit 0 ;;
  esac
  echo "BLOCKED: <hook> could not verify this call — $1" >&2
  exit 2
}
```

Propagate the verdict too. If a heredoc'd `python3` does `sys.exit(2)` and the script then ends in a bare `exit 0`, the block is discarded. Capture `RC=$?` and exit with it. Worked examples: `git-destructive-guard-hook.sh`, `ledger-append-only.sh`, and `agent-behavior-guard.sh`. The last one's enforce mode never blocked anything until 2026-10-01 for exactly this reason. Every blocking hook's `*.test.sh` needs a malformed-event case and a python3-off-PATH case (a `PATH` holding only `cat`). Without them, a fail-open regression passes the suite.

**2. Signals only narrow.** A hook's verdict may block, warn, pause or revoke. It never grants. No hook returns `permissionDecision: "allow"` or writes allow-rules. A detection that can widen access can be steered by whoever controls its input. Approval to widen access belongs to the human.

(Source: Perplexity, "How we engineer safer agents", 2026-09-29: "A safeguard the agent can decline to invoke, or reconfigure, is not a safeguard" and "No risk signal should ever grant additional access.")

## Harness Hook Conventions

- Hook source files live in `$SDD_HARNESS/hooks/` and get installed to `<project>/.claude/hooks/`
- Parse tool input from stdin: `EVENT=$(cat)` then extract `tool_input` fields with python3
- Use `set -euo pipefail` at the top
- Register in `<project>/.claude/settings.json` under the appropriate event + matcher
- Multiple hooks can share the same event + matcher — they run sequentially

**Stdin parsing pattern:**

```bash
EVENT=$(cat)
FILE_PATH=$(echo "$EVENT" | python3 -c "
import json, sys
e = json.load(sys.stdin)
inp = e.get('tool_input', {})
print(inp.get('file_path', inp.get('path', '')))
" 2>/dev/null) || fail_closed "could not parse the hook event"
```

Let a parse failure exit non-zero and handle it. Don't swallow it into `''`. An empty field and a failed parse mean different things, and only the first one may fall through to `exit 0`. For `fail_closed`, see "Fail Closed, Narrow Only" below.

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

## Replay Before Ship (PreToolUse changes)

Hand-written `*.test.sh` cases cover the calls you thought of. Before changing what a PreToolUse hook blocks, replay the calls the agent actually made through the old and new versions:

```bash
git show HEAD:hooks/claude/my-hook.sh > /tmp/old-hook.sh
python3 $SDD_HARNESS/skills/hook-design/resources/hook-replay.py \
  --old /tmp/old-hook.sh --new hooks/claude/my-hook.sh --tool Bash
```

It reports `newly_blocked`, `newly_allowed` and `new_errors`. The old hook is the baseline, so every flip is a decision the change has to justify — a false block on a routine command is the most common way a hook change goes wrong here.

- **Counts only by default.** Transcripts hold secrets; `--samples N` prints truncated calls when you need to see which ones flipped.
- **Wire it into the hook's `*.test.sh`** with `--fail-on-change` once the intended flips are accepted, so a later edit that flips more fails the test.
- **Coverage limit:** it can only test calls in the history. A command nobody has run yet is invisible to it, so keep the hand-written edge cases too.
- **Side effects:** each run gets a throwaway `HOME`; a hook that writes into the repo or `/tmp` is not isolated.
- A run with zero recorded calls exits 2 — nothing tested is not a pass.

Tests: `bash skills/hook-design/resources/hook-replay.test.sh`. (Source: Dream-RSI, arXiv 2609.14858 — score a candidate policy by replaying recorded history, with the incumbent as the baseline.)

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
