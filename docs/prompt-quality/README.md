# Prompt Quality (PQ) System

Heuristic scoring pipeline that measures and tracks the quality of every agent prompt spawned during Claude Code sessions. No external service or LLM required — runs locally, scores via regex heuristics, logs to `~/.code-insights/pq-log.jsonl`.

## What It Does

Every `Agent` tool call is intercepted by `prompt-quality-check.sh` (PreToolUse hook). The hook:
1. Extracts the `prompt` field from the tool input JSON
2. Scores the prompt against 6 PQ dimensions using fast Python heuristics
3. Outputs a scored report into Claude's context (stdout)
4. Appends a JSON entry to `~/.code-insights/pq-log.jsonl`

At session start, `session-start-hook.sh` reads the last 14 log entries and emits a one-line quality baseline so Claude knows its weak dimensions before writing any new agent prompts.

The dashboard **Session Health → Prompt Quality** tab reads the log file and visualizes trends.

## The 6 PQ Dimensions

| Dimension | What it measures | Heuristic signals |
|---|---|---|
| `context_provision` | Enough background for the agent to start | File paths, prior attempts, background keywords |
| `request_specificity` | Clear, unambiguous goal | Action verbs, named targets, no vague phrases |
| `scope_management` | Bounded scope + output format specified | "only", "do not touch", output format keywords |
| `information_timing` | Goal stated first, context after | Action verb in first third of prompt |
| `correction_quality` | If redirecting, names the exact error | "specifically", "exactly", expected behavior stated |
| `overall` | Composite average | Average of applicable dimensions |

`correction_quality` returns N/A (not counted) for new tasks — only scored when the prompt contains correction language ("wrong", "incorrect", "instead", etc.).

## Files

| File | Purpose |
|---|---|
| `hooks/claude/prompt-quality-check.sh` | PreToolUse hook — scores every Agent call |
| `hooks/claude/session-start-hook.sh` | Extended to show PQ baseline at session start |
| `scripts/utils/dashboard.py` | `render_prompt_quality()` function — Session Health tab |
| `skills/prompt-quality-assess/SKILL.md` | Cognitive rubric — apply before writing agent prompts |
| `~/.code-insights/pq-log.jsonl` | Runtime log (global, not per-repo) |

## Log Format

```jsonl
{"ts":"2026-06-11T12:34:56+00:00","overall":3.8,"dims":{"context_provision":3,"request_specificity":5,"scope_management":4,"information_timing":4,"correction_quality":null},"prompt_hash":"a1b2c3d4e5f6","word_count":42}
```

## Dashboard Tab

Located at **Session Health → Prompt Quality** (✨ tab). Shows:
- Summary strip: 7-day avg, total spawns scored, weakest dimension
- Per-dimension horizontal bars (green ≥4, yellow 3–4, red <3)
- Rolling score trend chart (last 20 spawns)
- Glossary: what PQ means and how to improve

## Hook Output Example

```
⚡ PQ Score: 3.2/5
  ✅ request_specificity: 5/5
  ⚠  context_provision: 2/5  →  add file paths, prior attempts, or relevant background
  ⚠  scope_management: 2/5   →  state what NOT to change; specify output format
  ✅ information_timing: 4/5
  —  correction_quality: N/A
  ⬆  Consider improving flagged dimensions before spawning.
```

## Session Baseline Example

```
📊 Prompt Quality Baseline (last 14 agent spawns): 🟡 avg 3.4/5 | weakest: context provision (2.8), scope management (3.1)
   → Reminder: front-load context and bound scope on every Agent call.
```

## How to Improve Scores

Invoke the `prompt-quality-assess` skill before writing agent prompts. It provides per-dimension rewrite patterns to get scores ≥4.0 before the hook fires.

## Inspired By

[github.com/melagiri/code-insights](https://github.com/melagiri/code-insights) — local session analytics tool that scores prompt quality with LLM analysis. This system replicates the 6-dimension schema as fast heuristics with no external dependencies.
