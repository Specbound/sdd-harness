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

If commits are zero, check sibling repos — activity may be invisible if `.claude/` is gitignored or work lands in a parallel directory. (source: 2026-08-31 [routine-error])

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

When marking idle on zero commits, check routine transcripts for auth errors; ~15-19-line transcripts can be legitimate short sessions. (source: 2026-08-31 [routine-error])

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
Check routine transcripts for hard-failure signature (~15 lines means died at auth); zero observations can hide outages indistinguishable from idle. (source: 2026-08-31 [routine-error])
