You are running the local daily maintenance loop for this repository. This invocation runs LOCALLY (not in Anthropic cloud), so you have access to:

- `~/.claude/skills/` via the Skill tool
- The full repo file tree (you are already in the repo's working directory)
- All slash commands defined in `.claude/commands/`

Today's date: TODAY_PLACEHOLDER

Execute the three steps below in order. Each is error-isolated — if one step fails, log the failure and continue to the next.

## Step A — Daily Maintenance (trust-battery loop)

Read `.claude/commands/kiro/daily-maintenance.md` and execute its pipeline:
1. Judge — score the last 24h of observations using `kiro/settings/rules/session-quality-rubric.md`
2. Reflect — convert drains (especially [memory-gap] entries) into memory updates
3. Housekeep — archive observations.md if >50 entries
4. Trust Score — `python3 .claude/scripts/trust_score.py apply --delta <X> --summary "<one-line>"`
5. Alert — append `[routine-alert]` if any [memory-gap] entries remain unresolved after reflect

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

## Output

When all three steps are done, emit a single summary line on stdout:

```
Daily maintenance complete: judge=<delta> session-quality=<N/5> keep-rate=<N%>
```

If any step was skipped or failed, replace the value with `skipped` or `failed`.
