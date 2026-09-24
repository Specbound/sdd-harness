---
name: risk-zone-engine
description: This skill should be used when working with or explaining the harness's risk-zone system — the shared red/yellow/green map at .claude/steering/risk-zones.md that gates risky edits and tiers PR labels. Covers the reseed cadence, the pinned-override convention, and both hook consumers.
triggers:
  - risk zone
  - risk-zones.md
  - pinned zone
  - pr risk tier
  - blast radius map
version: 1.0.0
author: Dan
date: 2026-09-16
---

# Risk-Zone Engine

One shared data file — `.claude/steering/risk-zones.md` — scores every file touched
in the last 90 days into `red` / `yellow` / `green`, and two hooks consume it. This
replaces having each consumer (PR tiering, edit-time warnings) recompute its own
notion of "risky" from scratch.

## The data source

`.claude/steering/risk-zones.md`, format:

```markdown
| File | Zone | Signal |
|---|---|---|
| `src/auth/session.py` | red | HIGH impact, 12 commits/90d, no test file |
```

Scored from three signals: git churn (90-day commit count), test-file presence,
and `gitnexus impact` risk level when GitNexus is installed (see the `gitnexus`
skill). Missing gitnexus doesn't block scoring — churn + test-presence alone
still produce a zone, annotated `(impact: not scored)`.

## Reseed cadence

`scripts/routines/risk-zone-reseed-runner.sh`, wired into the daily orchestrator's
`run_one()`, self-paces to once every 7 days (`RISK_ZONE_GAP_DAYS` to override,
`RISK_ZONE_FORCE=1` to force, `SDD_SKIP_RISK_ZONE=1` to opt out). It drives
`risk-zone-reseed-prompt.md` headlessly via `claude --print`.

**Human overrides survive reseeds.** Append `<!-- pinned -->` to any row and the
next reseed leaves that row untouched regardless of freshly computed signals —
this is the durable escape hatch when the auto-score is wrong for a specific file.

## The two consumers

1. **`risk-zone-edit-gate-hook.sh`** — `PreToolUse(Write|Edit|MultiEdit)`, soft
   gate. Looks up the target file in the map; if `red` or `yellow`, prints a
   banner naming the signal and asking Claude to check for characterization
   tests / run `gitnexus impact` before proceeding. Silent for `green` or
   unlisted files. Never hard-blocks — zone data can be stale or wrong, and a
   wrong call must not stop real work (same tradeoff `protected-path-hook.sh`
   makes for sensitive files).

2. **`pr-risk-tier-hook.sh`** — `PostToolUse(Bash)`, fires on a non-force
   `git push` with an open PR for the current branch (same trigger as
   `pr-auto-create-hook.sh`). Diffs the PR's files against its base branch,
   takes the worst zone among them, and labels the PR `risk:red` /
   `risk:yellow` / `risk:green` via `gh pr edit --add-label` (creating the
   label if missing).

## Relationship to other skills

- `gitnexus` — supplies the blast-radius signal the reseed prompt uses; see
  its "Harness Automatic Integrations" table.
- `pr-babysit` — watches CI/review after a PR opens; the risk-tier label this
  engine applies is visible context for that skill's triage, not something it
  needs to recompute itself.
