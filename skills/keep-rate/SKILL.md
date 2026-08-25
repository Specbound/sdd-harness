---
name: keep-rate
description: Measures what % of Claude-co-authored code still exists in HEAD after N days (the "Keep Rate" metric). Higher keep rate = agent-written code was accepted long-term. Lower rate = code got rewritten or thrown out. Run periodically to track agent code quality over time.
---

# Keep Rate Evaluator

The Keep Rate is a lagging quality signal: if code Claude wrote is still in the codebase a week later, it was probably good. If it got rewritten, something was wrong. Compute it, record it, and flag declining trends.

## When to Run

- On a scheduled routine (Mon/Thu evening recommended)
- After a dense agent-coding sprint to get a baseline reading
- When `kaizen` surfaces a pattern of heavy post-agent rewrites

## Workflow

### Step 1 — Find Claude-co-authored commits

```bash
git log --format="%H %ae %s" --no-merges | grep -i "co-authored-by.*claude\|noreply@anthropic"
```

Alternatively scan for the Co-Authored-By trailer:
```bash
git log --format="%H %aI" --grep="Co-Authored-By: Claude" --no-merges | head -100
```

Collect: commit hash, date, author, subject.

> **Do not compute an "AI adoption %" here.** It was removed on 2026-08-20. The metric
> divided trailered commits by all commits, so in a single-developer repo it measured
> commit-trailer hygiene — auto-generated `docs: auto-sync` commits and hand-typed
> commits both counted as "not AI" regardless of who wrote the code. Keep Rate below
> is the durability signal and stands on its own.

### Step 2 — For each commit older than 7 days, calculate line survival

For each file touched in that commit:
```bash
git diff <commit>^..<commit> --unified=0 -- <file> | grep "^+" | grep -v "^+++" | wc -l
# lines added by Claude in that commit

git blame HEAD -- <file> 2>/dev/null | grep <commit_hash> | wc -l
# lines from that commit still present in HEAD
```

**Keep Rate for commit** = `lines_still_in_HEAD / lines_added_by_Claude`

### Step 3 — Aggregate

- Per-commit keep rate
- Overall project keep rate (last 30 days of Claude commits)
- Trend: compare to previous period's rate

### Step 4 — Interpret

| Keep Rate | Signal |
|-----------|--------|
| > 80% | Strong — agent code quality is high |
| 60–80% | Normal — some iteration expected |
| 40–60% | Warning — code getting substantially reworked |
| < 40% | Alert — agent output is being rejected or heavily rewritten |

**Window Artifact Check:** Before flagging a sharp drop in keep-rate, verify whether a large durable commit just aged past 30 days (removed from denominator) or a large low-survival commit entered the 7-30d window. Recompute keeping only feature code, excluding infra/revert/churn commits. High feature-code survival with low aggregate = window shift, not a quality drain. (source: 2026-07-29 patterns)

### Step 5 — Record as observation

Prose observation in `.claude/memory/observations.md` (trend, window notes, outliers):

```
- YYYY-MM-DD [keep-rate]: Keep Rate = X% (N commits, M lines). Trend: ↑/↓/→ vs last period. [any notable pattern]
```

Structured measurement — the dashboard reads **only** this, never the prose:

```bash
.claude/scripts/session/record_metric.py --metric keep-rate --value X \
  --meta '{"commits": N, "lines": M, "window": "YYYY-MM-DD..YYYY-MM-DD"}'
```

Pass the percentage as a plain number (`86` or `86.4`), not a string with `%`.

If keep rate < 50%, add a `kaizen` note flagging the pattern for review.

### Step 6 — Surface findings

Report:
- Overall keep rate %
- Number of Claude commits analyzed
- Any files or feature areas with notably low keep rate (potential signal of prompt or context issues)
- Trend direction vs last measurement

## Expected Churn Patterns (Anti-Patterns)

Not all low keep-rate signals indicate code quality issues:
- **Iterative patch commits** (fixup, revert cycles): naturally 0–20% survival; expected in active refactor.
- **Infra/reorg commits**: wholesale rewrites inflate denominator with pure renames (0% lines remain); not a code-quality signal.
When keep-rate drops, separately analyze feature-code survival from infra-churn to avoid false regression. (source: 2026-06-22 observations)

### ❌ Using `--all` in Step 1
`git log --all` enumerates all branches (233 commits vs 111 on dev), inflating denominator. Enumerate on the working branch. (source: 2026-08-25 [keep-rate])

### ❌ Merge commits in Step 1
Add `--no-merges` to exclude; without it, 3 merges worth 8505 phantom lines inflate count. (source: 2026-08-25 [keep-rate])

### ❌ Binary files in Step 2 diffs
.mp3/.wav files inflate by 1141% on one file. Skip `--numstat` rows with `-`. (source: 2026-08-25 [keep-rate])

### ❌ Blame field filtering in Step 2
`git blame | grep <hash>` misses continuations; use `--line-porcelain` headers. (source: 2026-08-25 [keep-rate])
