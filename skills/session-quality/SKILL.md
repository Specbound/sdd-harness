---
name: session-quality
description: Daily session quality assessment — analyzes recent git activity and observation history to score how well Claude-assisted sessions went. Detects frustration signals (rewrites, reverts, corrections) vs success signals (clean merges, forward momentum). Records structured quality observations.
---

# Session Quality Assessor

Inspired by Cursor's "LLM-powered sentiment analysis of user responses." The key insight: a user moving on to the next feature is a strong success signal; a user pasting a stack trace or immediately reverting AI changes is a frustration signal. This skill approximates those signals from observable artifacts (git history, observation notes).

## When to Run

- Daily at ~22:00 via scheduled routine
- After sessions with unusual activity patterns
- As part of `kiro:daily-maintenance` (can be wired in)

## Workflow

### Step 1 — Collect today's signals from git

```bash
# Commits today
git log --since="24 hours ago" --format="%H %s %ae" --all

# Reverts today (strong frustration signal)
git log --since="24 hours ago" --format="%s" | grep -i "revert\|undo\|rollback\|fix.*claude\|fix.*agent"

# Files touched multiple times today (iteration/rework signal)
git log --since="24 hours ago" --name-only --format="" | sort | uniq -c | sort -rn | head -10
```

If commits are zero, check sibling repos — activity may be invisible if `.claude/` is gitignored or work lands in a parallel directory. (source: 2026-09-01 [session-quality])

### Step 2 — Collect signals from observations

Read `.claude/memory/observations.md` for today's entries. Look for:
- Error mentions, exception traces, repeated debugging cycles
- Positive completions ("shipped", "works", "merged", "done")
- Explicit corrections ("wrong", "not what I wanted", "redo")

### Step 3 — Score the session (1–5)

Apply LLM judgment:

| Score | Pattern |
|-------|---------|
| 5 | Clean commits forward, no reverts, user moved to next feature |
| 4 | Minor corrections, forward momentum overall |
| 3 | Some rework, mixed signals |
| 2 | Multiple reverts or heavy corrections, repeated fixes to same area |
| 1 | Reverts dominating, same errors recurring, session ended without progress |

Also assess:
- **Context quality**: Was the right information available? (errors suggesting wrong file/function targeted)
- **Spec quality**: Were requirements clear? (frequent scope changes suggest spec issue)
- **Tool reliability**: Any tool errors or unexpected failures?

### Step 4 — Record the score twice: once for humans, once for the dashboard

Prose observation (context, nuance, root-cause hint):

```
- YYYY-MM-DD [session-quality]: Score=X/5. Signals: [reverts: N, rework files: N, forward commits: N]. Root cause hint: [context gap / spec ambiguity / tool issue / none]. 
```

Structured measurement — the dashboard reads **only** this, never the prose:

```bash
.claude/scripts/session/record_metric.py --metric session-quality --value X \
  --meta '{"reverts": N, "rework_files": N, "forward_commits": N}'
```

**Idle windows.** If there was no user session in the window (routine ran on a stale
repo — no commits, no transcript), the score is a placeholder, not a judgement. Pass
`--idle` so it is excluded from the average:

```bash
.claude/scripts/session/record_metric.py --metric session-quality --value 3 --idle
```

Averaging placeholders in is how a repo with one good session and two quiet days
reports 3.3/5. Say "idle-routine window" in the text too, but the `--idle` flag is
what the dashboard acts on.

When marking idle on zero commits, check routine transcripts for evidence of real work (tool use, assistant turns, terminal Stop hook) and for auth errors. Line count alone does not discriminate outages. (source: daa-llm-evaluation 2026-09-09 [session-quality])

If score ≤ 2, also add a `[kaizen]` flag: `Investigate: [specific pattern observed]`

### Step 5 — Weekly trend (Thursdays)

If running on a Thursday, also compute 7-day average score and note trend:
```
- YYYY-MM-DD [session-quality-weekly]: 7-day avg=X.X/5. Trend: ↑/↓/→. Most common friction: [pattern].
```

### Failure Modes to Watch

- **Same file corrected 3+ days in a row** → steering doc or context issue
- **Reverts on Claude commits** → prompt quality or spec clarity problem  
- **Score declining over a week** → raise in next `kaizen` cycle

## Routine Artifacts vs Real Regression

Not all metric signals indicate real problems. **Idle-routine artifacts** fire on zero-charge windows (no user sessions, routine running automatically on stale repo). Distinguish by:
- Repeating signal with same anchor date (not escalating)? Likely artifact.
- Signal fires only in zero-charge judge windows? Filter before alerting.
Example: loop-debt on 2026-06-21 was recognized as idle-routine artifact, not regression. (source: 2026-06-21 insight, pattern)

### ❌ Marking `--idle` on zero commits alone
Do not use `--idle` on zero commits alone; prior-run output lands post-judge in this window. (source: 2026-08-26 [session-quality])

### ❌ Assuming routine idleness on zero observations
Check transcripts for the hard-failure signature (use the tail-distance rule below, not line count); zero observations hide outages as idle. (source: daa-llm-evaluation 2026-09-24 [insight, enforceable])

### ❌ Single-channel coverage checks
Check all four channels (observations.md, metrics.jsonl, markers, transcripts) before declaring idle. (source: daa-llm-evaluation 2026-09-09 [session-quality])

### ❌ Absolute line count as auth-outage discriminator
Dead = tail≤3 AND ≤25 lines. Tail marks where a run ENDED, not whether it worked: 80ab4e0a (375 lines, tail=3) did real subagent work. (source: daa-llm-evaluation 2026-09-24 [insight, enforceable])

### ❌ Completion sentinel stamped at routine start
Stamping at routine-start hides outages. `claude --print` exits 0 on OAuth, 502 gateway failures. Gate on artifact. (source: daa-llm-evaluation 2026-09-28 [judge])
Example: 2026-10-03 daily-maintenance died in queue; marker read start time, not completion. (source: 2026-10-05 [session-quality])

### ❌ Scheduler no-show vs true idle
Never-fired run leaves zero artifacts, indistinguishable from idle. Check cadence before marking idle. (source: 2026-09-27 [routine-error, insight])

### ❌ Zero-across-channels without TOOL CALL count
No transcript at all = never-fired. A short transcript with 0 tool calls = died at launch. Both leave zero artifacts, so check the transcript. (source: aiq-zora-agent-skill-foundation 2026-10-18 [insight, debug, escaped, enforceable], 2026-10-22 [skill-update-flagged])

### ❌ Reading the subagent scratch dir as the transcript channel
Transcripts live in ~/.claude/projects/<slug>/; /private/tmp/claude-*/<slug>/ is subagent scratch. An empty tasks/ there is normal, not a dead session. (source: 2026-09-30 [session-quality])

### ❌ Missing observation rows mean idle
They may signal routine failures. Check logs/orchestrator-errors.log for exit codes: daily-maintenance, macro-eval, harness-health, tool-failure-review. (source: sdd-harness 2026-10-02 [session-quality])

### ❌ String-keyed failure-mode detection
String-keyed detectors fail when modes shift (OAuth→502→timeout). Use structural invariant: isApiErrorMessage:true + model:"<synthetic>". (source: daa-llm-evaluation 2026-10-02 [judge] drain 2)
Timeout also emits isApiErrorMessage + model:<synthetic> (2026-10-03/04 observed), but text search would miss 'timed out'. (source: 2026-10-05 [session-quality])
Loopback (127.0.0.1) and upstream gateways both emit isApiErrorMessage + model:"<synthetic>". Detect via structural invariant, not text content. (source: 2026-10-12 [routine-alert, insight])

### ❌ Marking parallel-instance outages as schedule never-fire
Parallel-instance death: all scheduled routines fire within 10s, all die identically (<25 lines, 1 turn). Indicates auth outage, not scheduler. (source: daa-llm-evaluation 2026-10-02 [judge] drain 1)

### ❌ File size as outage discriminator
System payloads inflate transcript bytes (92–103 kB) while turn count stays 1. Use turn count or API-error markers instead. (source: 2026-10-02 [session-quality])

### ❌ Fleet-tick overrun vs never-fire (check orchestrator.log for run start/finish pairs)
Stalled fleet tick = zero repo artifacts but `run started` with no matching `run finished`; never-fire = no `run started` at all. Overrun needs scheduler fix, not runner hardening. (source: 2026-10-04 [session-quality])
2026-10-03: 18h37m tick span (three steps held in queue 2-9h each); 2026-10-04 tick never fired. (source: 2026-10-05 [session-quality])

### ❌ Assuming tick-level exit=0 means all steps passed
A tick can finish exit=0 with failed steps inside. Check per-step `exit=1 duration=...` in orchestrator.log, not just tick-level start/finish. (source: 2026-10-12 [routine-alert, insight])
### ❌ Trusting trace-hook error classification
If error count seems high, verify trace.log's `## Trace / outcome:` — hook substring-matches false positives. (source: 2026-10-07 [debug, insight])

### ❌ isApiErrorMessage alone in a transcript that read this skill
Marker appears in skill text; require co-occurrence with model:"<synthetic>" to avoid self-match. (source: 2026-10-07 [session-quality])
### ❌ Grepping transcripts for outage signatures without excluding injected context
Hot-memory injected by UserPromptSubmit quotes "502", "authentication_failed", "Agent stalled" — every transcript self-matches. (source: 2026-10-17 [session-quality])

### ❌ Fleet-mode starvation masked as idle
Orchestrator servicing one repo per invocation starves others for days; zero observations look idle. Check if siblings ran in that window. (source: 2026-10-18 [judge])

### ❌ Dating a transcript by its file mtime
A midnight-crossing run is last written the next day, so mtime dating empties the prior date; use session start time. (source: 2026-10-21)

### ❌ Relative memory paths without repo root verification
Relative .claude/memory paths can resolve to sibling repo if mounted as working directory. Verify absolute path matches repo root. (source: aiq-zora-agent-skill-foundation 2026-10-22 [judge])

### ❌ Recursive find over the transcripts dir
Subagent transcripts also sit at <session>/subagents/, not only in /private/tmp scratch; recursive find inflates session counts. Use -maxdepth 1. (source: 2026-10-23 [session-quality])

### ❌ Auth kills discriminated by tool-call count
Auth kills can land mid-run after substantial work; tool_use == 0 unreliable. Check last assistant message for 401, not tool count. (source: 2026-10-25 [routine-alert])

### ❌ Transcript presence without routine marker check
Per-repo transcripts or session starts do not prove daily-maintenance fired; check .last-routine-run timestamp + observation date histogram. (source: aiq-zora-agent-skill-foundation 2026-10-26 [routine-alert])

### ❌ Relying on harness trace.log status for routine outcome
Trace.log status scans response for keywords, falsely failing agents quoting errors and passing killed ones. Verify with independent artifact channels. (source: comfyui 2026-10-26 [debug, insight, pattern])

### ❌ Zero local `[skill-update]` lines read as no skill work
Cross-repo sessions log the write in the originating repo; 6 such lines sat in siblings on 10-26/27, sdd-harness 0. (source: 2026-10-27 [judge])

### ❌ Assuming mtime census survives between syncs
Fleet sync erases earlier daily buckets (LAST-WRITE-WINS); trust only same-day window counts. (source: aiq-zora-agent-skill-foundation 2026-10-28 [debug, insight, escaped])

### ❌ Inline zsh census loop fabricates output
Zsh `set -- $var` doesn't word-split, so a failed find still prints `0`. The empty result looks identical to a real empty window—silent and indistinguishable. (source: 2026-10-31 [session-quality]). Write loops to script files, run under bash.

### ❌ Shell arithmetic blocked in ctx_shell commands
`$((day+1))` and other shell arithmetic inside ctx_shell is hard-blocked by lean-ctx allowlist (exit 126). Day-window loops must use explicit literal date pairs. (source: 2026-10-31 [session-quality])

### ❌ Five channels miss already-running sessions finishing
Five new-work channels miss a continuing session; add find -newermt D ! -newermt D+1. (source: aiq-zora-ai-engine 2026-10-28 [session-quality])

### ❌ .last-routine-run marker only stamps latest run
.last-routine-run stamps only the latest run, so it cannot evidence a prior day. (source: aiq-zora-ai-engine 2026-10-28 [session-quality])

### ❌ Per-repo starvation confused with fleet-wide quiet
One busy sibling = quiet day, not starvation. Only all siblings quiet = fleet-wide quiet. Count siblings per repo, not globally. (source: 2026-10-31 [session-quality])

### ❌ Keeping a prior row's idle marking for continuity
Zero user sessions means `--idle` (see Idle windows above); continuity with earlier rows never overrides it. Backfill, don't match. (2026-10-29)
