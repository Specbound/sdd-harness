---
name: context-management-context-restore
description: "Use when designing or writing session save/restore mechanisms — what to capture before a session ends (compaction, subagent spawn, explicit save), how to structure it for cheap re-reading, and how restoration should surface it without re-injecting full history."
---

# Context Save & Restore

Session continuity across compaction, subagent handoff, or a fresh session tomorrow depends on writing a small, structured snapshot *before* context is lost — not on reconstructing it afterward. Restoration is then just: read the snapshot, don't replay the transcript.

## Two Trigger Models

| Trigger | When it fires | Output |
|---|---|---|
| **Automatic snapshot** | Pre-compaction, pre-subagent-spawn — any event that's about to drop context | Single overwritten file (e.g. `handoff/latest.md`) — always the most recent state, no history |
| **Manual save** | User explicitly asks to checkpoint ("save session X") | Named, timestamped file (e.g. `sessions/session-{date}-{name}.md`) — persists, never overwritten |

Both trigger models write the same structural shape (below); they differ only in overwrite-vs-append and in who initiates the write. A harness needs the automatic one to avoid silent loss at compaction/spawn boundaries, and the manual one for deliberate checkpoints the user wants to return to by name.

**Surfacing on restore:** don't inject the snapshot into context automatically — surface a short pointer at session start ("a handoff snapshot exists at `<path>`") and let the agent read it on demand. Auto-injecting defeats the point: the whole reason to snapshot was to keep the next context window small.

## What to Capture

**Progress tracker** (facts, derivable from git/spec state, not opinion):
- Feature/spec name and path, if one exists
- Git baseline (earliest relevant commit) and current HEAD
- Tasks completed vs. remaining (spec task IDs if applicable)
- Blocking issues, or explicitly "None"
- Next action — specific enough to execute without re-reading the conversation

**Narrative sections** (evidence-backed, not summarized-from-memory):

| Section | Rule |
|---|---|
| What WORKED | Every item needs evidence — test output, build success, not "it worked" |
| What did NOT work | Exact error or reason, not a paraphrase |
| What has NOT been tried | Specific next approach + steps, not "explore alternatives" |
| Current state of files | From `git status`/`git diff`, not recollection |
| Exact next step | Command/action → expected result → what comes after |

## Capture Discipline

- **Evidence required** — a "worked" claim without evidence is not a snapshot, it's a guess that will mislead the next session.
- **No duplication** — don't restate content already in specs, ADRs, commits, or diffs; reference them by path (`specs/checkout-flow/design.md`) instead of copying.
- **Redact secrets** — strip API keys, tokens, passwords from evidence/errors before they land in a file that will be read (and possibly committed) later.
- **No opinion** — report facts; let the resuming agent (or human) decide what to do with them.
- **Bounded size** — 3–7 bullets per section. A snapshot that's as long as the transcript it replaces has failed at its one job.

## Relevance and Staleness

A snapshot is only useful if the reader can tell how stale it is before trusting it:
- Always timestamp the write.
- Record the git branch and HEAD/baseline commit so staleness is checkable against current `git log`, not assumed.
- Prefer pointers over copies for anything that changes independently (specs, commit history) — a copied fact can silently drift from the source; a path reference can't.
- When restoring, validate the pointer before trusting it: if the referenced spec file no longer exists or HEAD has moved far past the recorded baseline, say so rather than restoring silently.

## Anti-Patterns

- **Reaching for vector DBs / knowledge graphs for session handoff** — this is a small, short-lived, single-reader artifact; structured markdown read on demand solves it. Add retrieval infrastructure only if you're querying across hundreds of sessions, not for single-session resume (see `agent-memory-systems` for when structured memory actually earns its cost).
- **Auto-injecting the full snapshot into every new context** — turns a cheap pointer into a permanent tax on every session, defeating the reason it was written small.
- **Treating the snapshot as a full context replacement** — it's a map back to the evidence (specs, commits, diffs), not a substitute for reading them. A resuming agent that trusts the snapshot's text over the artifacts it points to will repeat the mistakes `agent-memory-systems`' "summary substitution" anti-pattern describes.
- **One giant file for all sessions** — named per-session files (or an overwritten single "latest" for the automatic case) beat one growing log; a growing log needs its own retrieval problem solved before it's useful.
- **Vague next-step** — "continue working on the feature" gives the resuming agent nothing to execute; a next step must name a command or action and its expected result.

## Integration

Pairs with `agent-memory-systems` for longer-lived, cross-session knowledge (preferences, durable facts) — session handoff is deliberately short-lived and single-purpose by contrast. Pairs with `dispatching-parallel-agents` for the subagent-spawn trigger case: a spawning agent's context is about to fork, so a handoff snapshot lets the parent resume cleanly after the subagent returns.
