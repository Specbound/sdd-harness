You are running the local daily maintenance loop for this repository. This invocation runs LOCALLY (not in Anthropic cloud), so you have access to:

- `~/.claude/skills/` via the Skill tool
- The full repo file tree (you are already in the repo's working directory)
- All slash commands defined in `.claude/commands/`

Today's date: TODAY_PLACEHOLDER

Execute the three steps below in order. Each is error-isolated — if one step fails, log the failure and continue to the next.

## Step A — Daily Maintenance (trust-battery loop)

Read `.claude/commands/kiro/daily-maintenance.md` and execute its pipeline:
1. Judge — score the last 24h of observations using `kiro/settings/rules/session-quality-rubric.md`. Write the `[judge]` observation as usual, but **do NOT call `trust_score.py apply`** — scoring is handled in Step D (after session-quality and keep-rate are written).
2. Reflect — convert drains (especially [memory-gap] entries) into memory updates
3. Housekeep — archive observations.md if >50 entries
4. Alert — append `[routine-alert]` if any [memory-gap] entries remain unresolved after reflect

The pre-check at the top of daily-maintenance.md skips if today's `[judge]:` entry already exists. Respect that.

## Step B — Session Quality Assessment

Invoke the `session-quality` skill via the Skill tool. Apply its workflow:
- Collect today's git activity (commits, reverts, file rework counts)
- Score the session 1–5 based on charges vs drains
- Append a single `[session-quality]` observation to `.claude/memory/observations.md`

If today's `[session-quality]:` line already exists, skip silently.

## Step C — Keep Rate Evaluation

Invoke the `keep-rate` skill via the Skill tool. Apply its workflow:
- Find Claude-co-authored commits older than 7 days
- For each, compute lines added vs lines still in HEAD
- Append a single `[keep-rate]` observation with the overall %, trend, and any low-keep-rate flag

If today's `[keep-rate]:` line already exists, skip silently.

## Step D — Trust Score

Run `python3 .claude/scripts/trust_score.py auto-score` from the repo root.

**Must run AFTER Steps B and C** so today's `[session-quality]` and `[keep-rate]` observations are visible.
Reads `observations.md` directly and scores mechanically from tagged signals
(`[session-charge]`, `[memory-gap]`, `[session-quality]`, `[keep-rate]`).
Idempotent — running it twice on the same day is safe.

## Step E — Skill Augmentation (Sleep-Phase Knowledge Seeding)

Invoke the `skill-augment-agent` via the Agent tool. Pass this as the task prompt:

```
Augment skills from today's session.
Date: TODAY_PLACEHOLDER
Judge verdict: <paste the full judge JSON from Step A, or "no verdict" if Step A was skipped>
```

This is the Sleep-phase Knowledge Seeding step: converts today's drains **and any `[seed-target:]` observations** (auto-written by the action-capture hook during the Wake phase) into targeted, evidence-backed skill improvements. The agent will:
1. Collect `[seed-target:]` observations as additional evidence alongside judge drains
2. Run the Dreaming phase to generate synthetic worked examples for each gap
3. Apply up to 3 skill updates, logging each as `[skill-update]`

Idempotent: if `[skill-update]:` entries already exist for TODAY_PLACEHOLDER, the agent exits without duplicate writes.

If Step A failed and no judge verdict is available, pass "no verdict" — the agent falls back to `[seed-target:]` observations only.

## Output

When all five steps are done, emit a single summary line on stdout:

```
Daily maintenance complete: judge=<delta> session-quality=<N/5> keep-rate=<N%> trust-score=<score>% skill-updates=<N>
```

If any step was skipped or failed, replace the value with `skipped` or `failed`.
