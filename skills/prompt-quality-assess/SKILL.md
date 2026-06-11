---
name: prompt-quality-assess
description: Pre-flight 6-dimension quality rubric for agent prompts — apply before every Agent or Workflow tool call to score and improve prompt quality before spawning
metadata:
  type: skill
---

# Prompt Quality Assessment

## When to Activate

Invoke this skill whenever you are:
- About to write a prompt for the `Agent` tool or `Workflow` tool
- Reviewing an underperforming agent output and want to trace it to prompt quality
- Asked to evaluate or improve a prompt

Do NOT invoke for: user-facing response text, commit messages, or file content.

## The 6 PQ Dimensions

Score each 1–5. The `prompt-quality-check.sh` hook auto-scores every spawn using heuristics; this skill gives you the cognitive checklist to get it right *before* the hook fires.

| Dimension | 5 (Strong) | 3 (Weak) | 1 (Failing) |
|---|---|---|---|
| **context_provision** | File paths, prior attempts, background context present | Some background, no file context | "here's the task" with no background |
| **request_specificity** | Named target (function/file/class) + action verb | Vague goal, no specific target | "help me with this", "fix this" |
| **scope_management** | Explicit NOT-to-touch list, output format stated | Implicitly bounded | "do everything", "comprehensive", no format |
| **information_timing** | Goal stated in first sentence | Goal buried after preamble | Long context dump before the actual ask |
| **correction_quality** | Names the exact error + expected correct behavior | "that was wrong, try again" | N/A for new tasks |
| **overall** | ≥ 4.0 average | 3.0–3.9 | < 3.0 |

## Phase 1 — Score

Before writing the Agent prompt, mentally score each applicable dimension:

```
context_provision:   [ ] Has file paths or relevant background?
request_specificity: [ ] Named target + action verb?
scope_management:    [ ] Bounded scope + output format?
information_timing:  [ ] Goal in first sentence?
correction_quality:  [ ] (If correction) Names exact error + correct behavior?
```

If all ≥ 4: proceed.
If any = 1–2: fix that dimension first (see Phase 2).
If overall < 3.5: rewrite before spawning.

## Phase 2 — Improve by Dimension

**context_provision (score ≤ 3):**
Add before the task description:
```
Context: [what you've already tried / relevant file paths / background state]
```

**request_specificity (score ≤ 3):**
Replace vague verbs with precise ones. Pattern:
```
[Action verb] the [specific target] in [file:line if known] so that [outcome].
```
Not: "fix the auth" → Yes: "Refactor `validate_token()` in `auth/middleware.py` to use `<=` not `<` for expiry check."

**scope_management (score ≤ 3):**
Add scope bounds and output format:
```
Only touch [X]. Do not modify [Y] or [Z].
Return: [bullet list / diff / single file path / JSON summary].
```

**information_timing (score ≤ 3):**
Reorder — goal first, context second:
```
[Goal sentence first.]
[Context / background below.]
```

**correction_quality (score ≤ 3):**
Name the error precisely:
```
The [specific thing] was wrong because [exact reason].
Expected: [correct behavior].
Do NOT [repeat the mistake].
```

## Phase 3 — Final Check

Before calling the Agent tool, confirm:
- [ ] Overall estimated score ≥ 3.5
- [ ] Agent type (`subagent_type`) matches the task (code-change → cavecrew-builder, research → Explore, etc.)
- [ ] `isolation: "worktree"` specified if multiple agents will write files in parallel

## Hook Integration

`prompt-quality-check.sh` scores every Agent call automatically using heuristics and logs to `~/.code-insights/pq-log.jsonl`. The dashboard "Prompt Quality" sub-tab in Session Health reads this log. This skill is the human-side rubric; the hook is the machine-side measurement.
