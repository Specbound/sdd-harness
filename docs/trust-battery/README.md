# Trust Battery — Nightly Self-Improving Loop

> The harness's nightly scoring, reflection, and memory-gap detection system. Adapted from [@nityeshaga's trust-battery design](https://x.com/nityeshaga/status/2044864114682741134) (April 2026), scoped to a single-developer CLI harness.

## What It Is

A scheduled nightly pipeline that scores the harness's own recent behavior, converts the score into concrete memory changes, and surfaces unresolved drift to the developer. It closes the loop the harness was previously missing: **the harness has observations, patterns, and rules — but no wall-clock feedback that runs whether or not the developer remembers to invoke it**.

Without the battery loop, `/kiro:reflect` and `/kiro:housekeeping` run irregularly, the memory-gap signal is never captured, and the harness drifts. With the loop, every day ends with:

- a ±4.5% adjustment to a single **Trust Score** (observability only — it never gates harness behavior)
- a one-line `[judge]` observation summarising the day's charges and drains
- new memory entries converted from `[memory-gap]` signals the user generated that session
- a `[routine-alert]` in `observations.md` if any memory-gaps remain unresolved

### What problem it solves

The harness already had the right ingredients — an adversarial validator, a reflection loop, rule-encoded structural fixes, memory tiers — but every step was user-triggered. In practice, `/kiro:reflect` ran only when the developer remembered. The trust-battery loop supplies the **clock**.

The single sharpest insight from the source post: *every re-explained preference is a memory the agent should have saved but didn't*. The detector catches those in real-time; the Judge counts them as the flagship drain; the Reflector converts them into memories. That loop did not exist before.

## Origin and Attribution

Based on a post by [@nityeshaga](https://x.com/nityeshaga/status/2044864114682741134) (April 2026) describing a "trust battery" implementation inspired by Tobi Lütke's mental model at Shopify. The original design has per-human batteries, autonomy tiers unlocked by battery %, and a dashboard UI.

### What was adopted

- **Nightly Judge/Reflector separation** — the core insight: if one agent both scores and improves, it optimizes for score instead of work.
- **Structural fixes over memory patches** — when a memory fails, encode the rule structurally (this was already harness philosophy; the loop reinforces it).
- **Re-explanation as flagship drain** — the source's most practical signal.
- **±4.5%/day cap** — prevents single-day swings from dominating the score.

### What was deliberately left out

- **Per-person batteries** — the harness is single-developer per project. One scalar is enough; a graph of per-human relationships adds complexity with no audience.
- **Autonomy tiers unlocked by battery %** — conflicts with the harness's non-negotiable "every spec gate requires explicit human approval" property. Score is informational, never gates.
- **Dashboard UI** — the harness is CLI. A plain-text scoreboard at the top of `hot-memory.md` gives the same trend signal without building UI.

## Architecture

```
.claude/memory/
├── hot-memory.md                  # Scoreboard header line updated by trust_score.py
├── observations.md                # [memory-gap] (from detector), [judge], [routine-*] entries
└── trust-score.jsonl              # Append-only score history, one record per nightly run

.claude/scripts/
├── detect_reexplanation.py        # Detector — finds re-explanation phrases in session transcript
└── trust_score.py                 # Score math, clamping, header rewrite

.claude/agents/kiro/
└── session-judge.md               # Haiku-tier adversarial scorer, emits verdict only

.claude/commands/kiro/
└── daily-maintenance.md           # Orchestrator: Judge → Reflect → Housekeeping → Score → Alert

.claude/kiro/settings/rules/
└── session-quality-rubric.md      # Charges/drains rubric with evidence requirement

.claude/hooks/
└── stop-hook.sh                   # Runs detector after each session, appends [memory-gap] obs
```

## The Four Components

### 1. Re-explanation Detector — the flagship drain signal

**File**: `scripts/detect_reexplanation.py`
**Trigger**: stop-hook (every session end), also callable from CI

Scans the session's user turns for phrases indicating the user had to re-explain context:

| Pattern | Example |
|---|---|
| `I already told/said/mentioned` | "I already told you to use the work email" |
| `as I said/mentioned` | "as I mentioned, tickets use FOO-123" |
| `we (already) discussed/covered this` | "we discussed this yesterday" |
| `remember (that) I said/told you` | "remember that I said staging runs first" |
| `stop asking/doing` | "stop asking about the config file location" |
| `like I said/told you` | "like I said, use the dry-run flag" |
| `how many times` | "how many times do I have to tell you" |
| `I('ve) told/said (you\|this)` | "I've told you three times now" |
| `again/repeatedly, I/we told/said/explained` | "again, we told the pipeline is async" |

Each hit = one memory the harness should have saved but didn't. Output: JSON array of `{phrase, context, suggested_memory_topic}`. Dedup rule: overlapping spans from different patterns deduped; near-but-distinct phrases kept separate.

Input modes:
- `--file PATH` — scan a plain-text file
- `--stdin` — scan stdin
- `--auto-transcript` — find most recent Claude Code `.jsonl` transcript for cwd and extract user turns

The stop-hook uses `--auto-transcript` and appends **one** `[memory-gap]` observation per calendar day (subsequent stops within the same day no-op so the observations file does not bloat during long workdays).

### 2. Session Judge — independent adversarial scorer

**File**: `agents/kiro/session-judge.md`
**Model**: Haiku (pattern matching, cheap pass)
**Trigger**: Step 1 of `/kiro:daily-maintenance`

Reads `observations.md` + `trace.log` for the last 24 hours and applies the rubric in `kiro/settings/rules/session-quality-rubric.md`. Emits a JSON verdict:

```json
{
  "window": "2026-04-20T00:00Z..2026-04-21T00:00Z",
  "positives": [{"tag": "root-cause-fix", "evidence": "observations.md 2026-04-20 [debug]", "weight": 1}],
  "negatives": [{"tag": "re-explanation", "evidence": "observations.md 2026-04-20 [memory-gap]", "weight": -2}],
  "score_delta": -1.0,
  "summary": "One sentence."
}
```

**Hard constraint on the Judge**: it proposes no fixes. The prompt is explicit — "if you catch yourself writing 'the harness should...', stop, delete it." This is the Judge/Reflector separation that Nityesh's design hinges on: a Judge that also improves would soften its scoring so the day looks better.

Idempotent: if a `[judge]` observation already exists for today, the Judge emits `score_delta: 0` with summary `"Already judged for this window"` and appends nothing new.

### 3. Reflector — consumes the Judge's drains

**File**: `agents/kiro/reflect-agent.md` (existing; not changed)
**Trigger**: Step 2 of `/kiro:daily-maintenance`

The existing `/kiro:reflect` pipeline, now seeded with the Judge's drains list as priority input. Each `[memory-gap]` drain should produce either:
- a new memory entry (if the gap is real), or
- an explanation in `patterns.md` of why it is a known false positive (rare)

The orchestrator passes the Judge's verdict JSON directly into the reflect-agent's prompt so the reflector knows what to prioritize.

### 4. Trust Score — scoreboard math

**File**: `scripts/trust_score.py`
**State**: `.claude/memory/trust-score.jsonl`
**Trigger**: Step 4 of `/kiro:daily-maintenance`

```bash
python3 .claude/scripts/trust_score.py apply --delta -1.0 --summary "..."
python3 .claude/scripts/trust_score.py show
```

Behavior:
- Starts at **20%** on fresh install (matches the source's "AI hasn't earned trust yet" framing)
- Clamps the applied delta to `[-4.5, +4.5]` (matches the source's cap)
- Clamps the score to `[0, 100]`
- **Idempotent per calendar day**: if a record already exists for today, skips without writing
- Rewrites the `## Harness Trust Score:` line at the top of `hot-memory.md`
- Appends to `trust-score.jsonl` with raw delta, applied delta, and timestamp for the 7-day trend

Output arrows: ▲ (up), ▼ (down), ▬ (flat). 7-day delta is `null` until there are records older than 7 days.

## The Nightly Loop

`/kiro:daily-maintenance` runs five steps. Each is error-isolated — a bad Judge pass does not block housekeeping.

```
┌──────────────────────────────────────────────────────────────┐
│ Stop-hook during the day                                     │
│   └─ detect_reexplanation.py ──► [memory-gap] observation    │
│                                  (once per calendar day)     │
└──────────────────────────────────────────────────────────────┘
                             │
         (night, via Windows Task Scheduler / SessionStart hook)
                             ▼
┌──────────────────────────────────────────────────────────────┐
│ /kiro:daily-maintenance                                      │
│                                                              │
│  Pre-check:  .claude/memory/ exists?                         │
│              today's [judge] already written?  → exit        │
│                                                              │
│  Step 1 ── session-judge ──► JSON verdict + [judge] obs      │
│             (reads observations + trace; proposes nothing)   │
│                                                              │
│  Step 2 ── reflect-agent  ──► new memory / patterns          │
│             (seeded with Judge's drains)                     │
│                                                              │
│  Step 3 ── housekeeping-agent ──► pruned / archived memory   │
│                                                              │
│  Step 4 ── trust_score.py apply --delta ... ──► scoreboard   │
│             (rewrites hot-memory.md header, appends jsonl)   │
│                                                              │
│  Step 5 ── unresolved [memory-gap] check ──► [routine-alert] │
│             (only if gaps remain after Step 2)               │
└──────────────────────────────────────────────────────────────┘
```

### Scheduling via Windows Task Scheduler

Auto-registered by `install.sh` on first install (and `update.sh` on existing installs) when running under WSL with `schtasks.exe` available. No manual setup needed. To force-recreate (e.g. after editing the schedule template):

```bash
bash ~/.claude/sdd-harness/scripts/setup-global-orchestrator.sh --force
```

Fires daily at 18:00 local (Israel) for all repos listed in `~/.claude/sdd-harness/projects.txt`. Each repo runs its own `daily-runner.sh`, maintaining its own memory, score history, and rubric application. A SessionStart hook provides catch-up: if the runner hasn't fired in >24h, opening any Claude session in the repo fires it silently in the background.

Opt out at install time:

```bash
SDD_SKIP_ROUTINE=1 ~/.claude/sdd-harness/install.sh /path/to/project
```

Or after the fact: `schtasks.exe /Delete /TN "SDD Daily Orchestrator"` (global) or `rm .claude/scripts/daily-runner.sh` (per-repo).

## Rubric at a Glance

See [`kiro/settings/rules/session-quality-rubric.md`](../../kiro/settings/rules/session-quality-rubric.md) for the full rubric.

### Charges (+1 each, max 5 per day)

- Clean gate pass — a spec phase completed without rejection or redo
- Self-caught mistake — harness found and fixed before the user flagged it
- Reused existing utility — cited a pre-existing function/pattern
- Cited memory during work — referenced an observation, pattern, or hot-memory entry
- Root-cause fix — debugging observation describes *why*, not just *what*
- Rule obeyed under pressure — `decision` observation cites a rule file as the reason a shortcut was rejected

### Drains (-2 each, max 5 per day)

- **Re-explanation** (flagship) — `[memory-gap]` observation from the detector
- Silent failure — agent returned success when output was wrong
- Gate bypass — implementation shipped without passing `/kiro:verify`
- Rationalized rule-skip — harness argued its way out of a rule (see `anti-rationalization.md`)
- Stale context — acted on a fact that files/git already showed had changed
- Churn — 3+ redo cycles on the same artifact without a captured learning

Asymmetric weighting (−2 vs +1) matches the existing `/kiro:validate-adversarial` design: concerns carry double weight because missed drift is costlier than unnecessary caution.

## Trust Score ≠ Autonomy

This is non-negotiable. The Trust Score is **observability only**. It never gates harness behavior.

- High score does not unlock skipping spec phase gates
- Low score does not force extra approval steps
- The scoreboard exists to make drift *visible*, not to drive decisions

The harness's safety property — every spec gate requires explicit human approval — is preserved regardless of score. This is the single most important constraint: if a future contributor tries to add "at ≥75% skip this gate" logic, that is a bug, not a feature. The rule belongs in `kiro/settings/rules/session-quality-rubric.md` ("Judging Constraints" section) and should be enforced there.

## Troubleshooting

### The Routine fired but nothing changed

Check the guard conditions in order:

1. `ls .claude/memory/hot-memory.md` — does the project even have memory bootstrapped? If not, Step 0 of the orchestrator exits cleanly. Run `/kiro:reflect` once manually to bootstrap.
2. `grep "^- $(date +%Y-%m-%d) \[judge\]:" .claude/memory/observations.md` — has the pipeline already run today? If yes, it's idempotent and will no-op. Delete the `[judge]` line to re-enable (intentional escape hatch).
3. `cat .claude/memory/trust-score.jsonl | tail -1` — does the last record have today's date? If so, Step 4 skipped (same-day guard).

### Detector produces nothing even though I re-explained things

- The detector scans **user turns only** from the JSONL transcript, not assistant output.
- `~/.claude/projects/<encoded-cwd>/` must contain at least one `.jsonl` file. If the session ended abnormally, the transcript may not be flushed.
- Test the detector directly: `echo "I already told you to use the dev branch" | python3 .claude/scripts/detect_reexplanation.py --stdin`.

### Score is stuck at 20%

- The Judge scored 0 for each run. Causes: empty observations window, every finding lacked evidence (the rubric requires citations), or all observations are already tagged `[judge]` (idempotent skip).
- Check: `python3 .claude/scripts/trust_score.py show` — if `records > 0` but `score == 20`, the Judge is consistently emitting `score_delta: 0`. Inspect the rubric and recent observations.

### Routine not registered

- `schtasks.exe /Query /TN "SDD Daily Orchestrator"` — does the Windows task exist?
- If not, run `bash ~/.claude/sdd-harness/scripts/setup-global-orchestrator.sh` from WSL (requires `schtasks.exe` on PATH). Use `--force` to recreate a broken task.
- `SDD_SKIP_ROUTINE=1` was set during install — run `update.sh` without it to retry.

### How do I reset a bad day?

Delete today's `[judge]` observation and the last line of `trust-score.jsonl`. The next Routine run will re-score.

```bash
sed -i "/^- $(date +%Y-%m-%d) \[judge\]:/d" .claude/memory/observations.md
sed -i '$ d' .claude/memory/trust-score.jsonl
```

## Future Considerations

The deliberate non-goals above are stable. If any of these come up in a future request, treat them as **scope expansions that require explicit design review**:

- **Multi-stakeholder batteries** would require observations to be tagged by author and the rubric to distinguish user-from-AI friction from user-from-user friction. The harness does not capture author metadata today.
- **Tiered autonomy** would require the spec workflow to accept a per-phase approval-level parameter. See the "Trust Score ≠ Autonomy" section above for the argument against.
- **Cross-repo score aggregation** would give one Trust Score across all installed projects. Not obviously useful — each repo has its own context and each project's score should stand alone.

## Related Documentation

- [`docs/memory/README.md`](../memory/README.md) — the memory tier architecture the battery loop plugs into
- [`docs/SDD-USAGE.md`](../SDD-USAGE.md#daily-maintenance-automated) — user-facing usage of `/kiro:daily-maintenance`
- [`docs/SDD-SETUP-GUIDE.md`](../SDD-SETUP-GUIDE.md#automated-hooks) — hook and Routine registration flow
- [`kiro/settings/rules/session-quality-rubric.md`](../../kiro/settings/rules/session-quality-rubric.md) — the full rubric the Judge applies
- [`kiro/settings/rules/anti-rationalization.md`](../../kiro/settings/rules/anti-rationalization.md) — rule the "rationalized rule-skip" drain enforces
