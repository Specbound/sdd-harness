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
git log --all --format="%H %ae %s" | grep -i "co-authored-by.*claude\|noreply@anthropic"
```

Alternatively scan for the Co-Authored-By trailer:
```bash
git log --all --format="%H %aI" --grep="Co-Authored-By: Claude" | head -100
```

Collect: commit hash, date, author, subject.

### Step 1b — AI Adoption % (volume, not durability)

A second, distinct metric: what fraction of recent commits/lines are Claude-co-authored at all — not whether they survived. Keep Rate answers "how much of Claude's code stuck"; Adoption % answers "how much of the work was Claude's to begin with." Compute over the same 30-day window as Step 3's aggregate:

```bash
git log --all --since=30.days --format="%H" | wc -l
# total commits in window

git log --all --since=30.days --grep="Co-Authored-By: Claude" --format="%H" | wc -l
# Claude-co-authored commits in window
```

**AI Adoption %** = `claude_commits / total_commits` (or line-count equivalent if commit-level granularity is too coarse for the repo). Record alongside Keep Rate in Step 5 — don't conflate the two numbers, a high adoption % with a low keep rate is a real (and different) signal than the reverse.

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

Save to `.claude/memory/observations.md`:

```
- YYYY-MM-DD [keep-rate]: Keep Rate = X% (N commits, M lines). Trend: ↑/↓/→ vs last period. [any notable pattern]
- YYYY-MM-DD [ai-adoption]: AI Adoption = Y% (N of M commits in last 30d). Trend: ↑/↓/→ vs last period.
```

If keep rate < 50%, add a `kaizen` note flagging the pattern for review.

### Step 6 — Surface findings

Report:
- Overall keep rate %
- AI adoption % (volume) — distinct from keep rate (durability)
- Number of Claude commits analyzed
- Any files or feature areas with notably low keep rate (potential signal of prompt or context issues)
- Trend direction vs last measurement, for both metrics

## Expected Churn Patterns (Anti-Patterns)

Not all low keep-rate signals indicate code quality issues:
- **Iterative patch commits** (fixup, revert cycles): naturally 0–20% survival; expected in active refactor.
- **Infra/reorg commits**: wholesale rewrites inflate denominator with pure renames (0% lines remain); not a code-quality signal.
When keep-rate drops, separately analyze feature-code survival from infra-churn to avoid false regression. (source: 2026-06-22 observations)
