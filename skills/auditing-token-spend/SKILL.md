---
name: auditing-token-spend
description: "Measures where tokens actually went from the transcripts — deduplicated totals, peak 5h window, per-tool amplified cost, and automation share — then names the cause rather than restating generic advice."
risk: safe
source: local
---

# Auditing Token Spend

Every other skill here that touches tokens is **prescriptive**:
`context-optimization`, `context-window-management`, `rtk-token-reduction`,
`cost-optimization` all tell you how to use less. None of them measure what was
actually used, so none can tell you *which* of their advice would have paid.

This one measures first. The script produces numbers; you produce the cause.

```bash
python3 $SDD_HARNESS/scripts/utils/token-forensics.py --days 30
python3 $SDD_HARNESS/scripts/utils/token-forensics.py --days 7 --project sdd-harness
python3 $SDD_HARNESS/scripts/utils/token-forensics.py --days 14 --json
python3 $SDD_HARNESS/scripts/utils/rtk-net-effect.py --days 30
```

Read-only, local transcripts only, no network.

## Use this skill when

- A usage limit was hit and you want to know what filled the window
- Spend jumped and nobody changed anything obvious
- Deciding whether a routine's cadence or an agent fan-out width is affordable
- Before acting on generic "reduce your context" advice — check what is actually big
- Reviewing whether a tool or hook that injects output is worth its cost

## Do not use this skill when

- You want to *reduce* usage and already know what is expensive → that is
  `context-optimization` / `rtk-token-reduction`. This finds the target; those act on it.
- You want per-session behavioral quality → `session-quality`, `keep-rate`
- You want live context pressure right now → the dashboard's Context Health tab

---

## Workflow

### Phase 1: Measure

Run the script over the window that matters. Default 30 days; use `--days 7`
when investigating a specific lockout, and `--limit` on a slow machine.

**Sanity-check the parser before trusting a single number.** The output reports
how many duplicate blocks it collapsed. If that count is **zero across many
transcripts**, the transcript format has changed and the dedup has become a
no-op — every figure below it is then inflated and must not be quoted. This is
the same canary `scripts/utils/dashboard-usage-dedup.test.sh` guards.

### Phase 2: Read the Four Signals

**Deduplicated total vs naive.** One API response is written as one JSONL line
per content block, each repeating the identical usage object. The gap between
the two figures (~80% on this machine) is the measurement error you avoid by
using this rather than summing the transcript directly.

**Peak 5h window.** This is what a usage limit measures. A large total spread
evenly across a week is fine; a much smaller one concentrated in five hours is
what locks you out. If the peak is close to the total, the spend is bursty and
the fix is scheduling, not volume.

**Automation share.** Read the `method` line before the number:

| Method shown | What it means |
|---|---|
| `exact (isSidechain)` | Subagent turns are tagged. The split is real. |
| `proxy (sessions under 5min)` | Subagent turns are **not** tagged in this transcript format. The number is a stand-in, not a measurement. |

As of 2026-08-30 it is the proxy: `isSidechain` is present on every assistant
line and `True` on none of them (0 of 6,423 across 150 transcripts, in sessions
that provably spawned agents). Each agent gets its own session file,
indistinguishable from a short human session. **Do not report the proxy as if it
were subagent cost, and never restate an unpopulated field as 0%** — unknown and
zero are different findings, and only one of them is true here.

**Per-tool amplified cost.** The important one, and the one that inverts naive
intuition. Context injected at request *i* is re-sent on every later request in
that session, so a tool result's real cost is its size times the number of
requests that followed it. A 20k-character read on turn 3 of a 200-turn session
is not 20k tokens, it is millions of cache-read tokens. A read of the same size
on the last turn costs almost nothing.

This is why the table ranks by what a tool **caused**, not what it **returned**.
A tool with modest returned-chars can top the amplified column purely by firing
early and often — and that is the one worth bounding.

### Phase 3: Name the Cause

State one cause, with the number that supports it. Not a list of observations.

| Shape | Likely cause | Action |
|---|---|---|
| One tool dominates amplified cost | Unbounded output injected early | Cap that tool's output (`tool-design` → output cap contract), or move the call later |
| Peak 5h ≈ total | Bursty, not voluminous | Stagger routines; the daily total is not the problem |
| High automation share + many short sessions | Routine cadence or fan-out width | Every fresh session pays full cache-creation on turn one — reduce spawn count before run length |
| High cache-create vs cache-read | Sessions too short to amortize the prompt | Fewer, longer sessions; check for a loop restarting the agent |
| High cache-read, flat output | Long sessions carrying a large early payload | Compact sooner, or stop injecting the payload |

### Phase 4: Act or Say Nothing

If nothing is anomalous, say so in one line and stop. A recurring report that
always finds a problem stops being read.

When there is a finding, route it rather than restating it:

- Tool output too large → `tool-design`, and bound it in the tool or hook itself
- Too much context retrieved → `lean-ctx` mode selection (`signatures`/`map` over `full`)
- Routine too frequent → the runner's `MIN_GAP_DAYS` guard
- Fan-out too wide → `dispatching-parallel-agents`, `model-tiers`
- Session too long before compaction → `compaction-discipline-hook.sh`, `context-compression`

Record durable findings with `ctx_knowledge(action="remember", ...)` so the next
audit starts from the last one instead of rediscovering it.

### Phase 5: RTK Net Effect (local savings vs global cost)

`token-forensics.py` measures spend; it cannot tell you whether a compression
layer's local savings are a net win. RTK reports raw shell output removed on
one command — it cannot see whether the agent, missing detail it needed, then
reran that command or re-read the same file later in the session. That is the
cost that would make a "saved" number net-negative globally.

`rtk-net-effect.py` measures that recovery-path signal directly from
transcripts: exact-match Bash rerun rate and Read reread rate within the same
session. It is the same instrument the dashboard's RTK layer note reads
(written daily by `routines/rtk-net-effect-runner.sh`).

```bash
python3 $SDD_HARNESS/scripts/utils/rtk-net-effect.py --days 30 --json
```

Read it as a caveat, not a verdict: a high rerun/reread rate is evidence, not
proof, that compression cost detail the agent had to go get back — a
genuinely new task can also re-issue an old command or re-read an old file.
Treat a rerun rate that is high *and* rising as the signal worth acting on;
a flat baseline rate is not itself a finding.

---

## Anti-patterns

- **Quoting the naive total.** It overstates by ~80%. Always use the deduplicated figure.
- **Ranking tools by returned bytes.** That is the column that looks obvious and
  is the wrong one. Rank by amplified.
- **Reporting the automation proxy as subagent cost.** It is labelled a proxy for
  a reason. So is the difference between unknown and zero.
- **Treating token estimates as exact.** Tool output is estimated at chars/4. The
  ranking is the product; the absolute is an order of magnitude, not a bill.
- **Auditing without acting.** A measurement nobody routes anywhere is a report,
  not a loop.
