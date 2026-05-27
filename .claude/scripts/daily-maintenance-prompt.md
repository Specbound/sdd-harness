You are running the local daily maintenance loop for this repository. This invocation runs LOCALLY (not in Anthropic cloud), so you have access to:

- `~/.claude/skills/` via the Skill tool
- The full repo file tree (you are already in the repo's working directory)
- All slash commands defined in `.claude/commands/`

Today's date: TODAY_PLACEHOLDER

Execute the three steps below in order. Each is error-isolated — if one step fails, log the failure and continue to the next.

## Step A — Daily Maintenance (trust-battery loop)

Read `.claude/commands/kiro/daily-maintenance.md` and execute its pipeline:
1. Judge — score the last 24h of observations using `kiro/settings/rules/session-quality-rubric.md`. Write the `[judge]` observation as usual, but **do NOT call `trust_score.py apply`** — scoring is handled in step 4.
2. Reflect — convert drains (especially [memory-gap] entries) into memory updates
3. Housekeep — archive observations.md if >50 entries
4. Trust Score — `python3 .claude/scripts/trust_score.py auto-score`
   This reads observations.md directly and scores mechanically from tagged signals
   (`[session-charge]`, `[memory-gap]`, `[session-quality]`, `[keep-rate]`).
   It is idempotent — running it twice on the same day is safe.
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

## Step D — Morning Brief (Draft, Don't Act)

Read the following files to assemble today's brief:
- `.claude/memory/action-items.md` — open loops and commitments
- `.claude/memory/hot-memory.md` — current priorities and key decisions
- `.claude/memory/entities.md` — collaborator context

**Output a structured brief** using this template:

```
## Morning Brief — TODAY_PLACEHOLDER

### To-do (open loops on me)
- [item] — [why it matters or what's blocked]

### Needs attention (changed since last brief)
- [item] — [what changed]

### Blocked on me
- [project or decision] — [what unblocks it]

### Nothing to flag
(emit this section only if all above are empty)
```

Rules:
- Draft only — never send messages, push code, or take external actions
- Keep it under 150 words
- If a section is empty, omit it
- If no files exist or all sections are empty, output "Morning Brief — nothing to flag."

If today's brief was already written (check `.claude/memory/daily/TODAY_PLACEHOLDER-brief.md`),
skip and emit `brief=skipped`. Otherwise write the brief to that path and emit `brief=ok`.

## Output

When all four steps are done, emit a single summary line on stdout:

```
Daily maintenance complete: judge=<delta> session-quality=<N/5> keep-rate=<N%> brief=<ok|skipped|failed>
```

If any step was skipped or failed, replace the value with `skipped` or `failed`.
