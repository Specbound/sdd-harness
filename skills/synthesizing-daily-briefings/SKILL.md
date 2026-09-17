---
name: synthesizing-daily-briefings
description: Maintains projects.md/people.md context files and synthesizes a daily prioritized briefing from connected sources (git, GitHub, Jira, Slack) — evidence required, dedup, signal over coverage.
risk: safe
source: external
source_url: https://softwareleads.substack.com/p/maintaining-context-as-a-manager
---

# Synthesizing Daily Briefings

Adapted from James Samuel's "Maintaining Context as a Manager" (Parts 1–2). The
original problem: as scope grows, memory alone can't track every project, person, and
decision — but logging *everything* produces an unusable archive nobody re-reads.

## When to Activate

- User asks for a status digest: "what's my status", "daily briefing", "what changed
  since I last looked"
- User wants a recurring signal-over-noise summary across multiple projects or people
  they track, sourced from tools that are actually connected (git, GitHub, Jira/Confluence,
  Slack, etc.)
- User is deciding whether something is worth writing down for future reference (the
  capture filter below applies any time, not just at briefing time)

## Do Not Use When

- Grading this repo's own harness/session quality → `kiro:daily-maintenance`,
  `session-judge` (that's the harness auditing itself, not the user's external work)
- A one-off question answerable by reading a single file directly → just read it, don't
  invoke the full pipeline
- No `projects.md`/`people.md` exist yet and the user hasn't asked to start tracking
  anything → don't fabricate projects or people to fill the format; ask first (Phase 1)

## The Capture Filter (what's worth writing down)

Before logging anything to `projects.md` or `people.md`, it must satisfy at least one:

1. **Enables future action** — e.g. context needed to later build a plan, or a deferred
   task ("review this design doc next week").
2. **Reveals a pattern over time** — e.g. a person's growth across months, a project's
   evolving decisions, useful for later review.
3. **Helps someone else do their job well** — worth surfacing even if there's no time to
   act on it now.

Anything that fails all three is noise for the briefing, not a logging candidate.

## File Structure

Two files under `.claude/memory/manager/` (create the directory on first use — this is
distinct from the harness's own `.claude/memory/hot-memory.md` and from Claude's
cross-session auto-memory; it is the user's own tracked-entity ledger, scoped to this
project like the rest of `.claude/memory/*`):

- **`projects.md`** — one section per project: running history of decisions, open
  questions, concerns raised. Update by appending, not rewriting.
- **`people.md`** — one section per person: notes, feedback, outstanding action items,
  meeting context. Never infer performance judgments the user didn't state — record
  observations, not conclusions.

## Workflow

### Phase 1 — Load or Bootstrap

Read `projects.md`/`people.md` if they exist. If neither exists, this is the first run:
ask the user once whether to start tracking, and with what initial projects/people —
do not invent entries to fill the format. If the user declines, note that and stop; a
headless/scheduled run must skip silently in this case (see Automation below), not
fabricate content.

### Phase 2 — Gather Signal

Pull only what changed since the last briefing (track a `last-run` timestamp). For each
source, check availability before using it — skip and say so plainly if unavailable,
never silently omit:

| Source | How to check |
|---|---|
| Git history | `git log --since=<last-run>` in the current repo |
| GitHub | `gh` CLI, if authenticated |
| Jira/Confluence | Atlassian MCP tools, if authenticated this session |
| Slack/other chat | whatever MCP/integration is actually configured |

### Phase 3 — Filter, Tier, Dedup

- **Signal over coverage** — only include items needing a decision, approval,
  escalation, or indicating risk/regression. Skip routine no-action updates.
- **Priority tiers P0–P3** — P0/P1 dominate the briefing; P2/P3 get a one-line mention
  at most.
- **Evidence required** — never state "regression" or "issue" without a concrete
  pointer (commit, PR, message link, error text). Distinguish a *reported concern* from
  a *confirmed issue* explicitly in the wording.
- **Dedup across sources** — the same event surfaced in git + Slack + Jira is one line,
  not three; keep the strongest/most recent source.

### Phase 4 — Write the Briefing

Write Logseq-ready markdown to `.claude/reports/daily-briefings/<date>.md`: linked dates,
project names, and people names, with `TODO` markers for anything needing action. Answer
the guiding question directly: **what changed since I last looked, what matters, and
what do I need to do about it.**

### Phase 5 — Update the Ledger

Re-apply the Capture Filter to anything durable from Phases 2–4 (not the day's routine
noise) and append it to `projects.md`/`people.md` for future briefings to build on.

## Automation

Runs as a daily routine (`/kiro:daily-briefing`, wired into the daily orchestrator,
self-paced to once/day). The runner **must** no-op with a one-line skip note — never
fabricate — when `.claude/memory/manager/` doesn't exist yet, i.e. before Phase 1's
bootstrap has happened interactively at least once. This is a hook/routine + skill
split: the skill holds the judgment calls (what's signal, what's a duplicate, what
tier); the routine only handles scheduling and the no-op guard.

## Pitfalls

- **Logging everything** — defeats the point; re-apply the Capture Filter, don't skip it
  because "it might be useful."
- **Unevidenced claims** — "seems like it regressed" is not evidence; find the concrete
  pointer or label it a reported concern, not a finding.
- **Silent source omission** — if Jira/Slack isn't connected this session, say so in the
  briefing rather than just leaving projects related to it out with no explanation.
- **Fabricating entries on first run** — an empty ledger is not an invitation to invent
  plausible-sounding projects/people; ask the user.
