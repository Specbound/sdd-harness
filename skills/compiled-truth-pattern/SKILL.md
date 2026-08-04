---
name: compiled-truth-pattern
description: Structure for living knowledge documents and memory observations. Compiled synthesis at top (rewrite in place when evidence changes), append-only evidence at bottom. Use when writing memory, research output, or any document that will accumulate evidence over time.
triggers:
  - Writing a memory observation via save_observation
  - Creating or updating a memory file
  - Structuring a research output document
  - Writing a living document that will be updated over time
  - Maintaining project knowledge that accumulates evidence
  - Creating any document with both current understanding and historical evidence
  - Updating an existing memory observation with new findings
---

# Compiled Truth Pattern

Every living document has two jobs: showing what's true now, and preserving how we got there. Keep them in separate zones — one for rewriting, one for appending.

## The Two-Zone Structure

```markdown
## State
[Current synthesis — always reflects best current understanding as of YYYY-MM-DD]
Key fact with citation [Source: User, context, YYYY-MM-DD].
Another fact [Source: Meeting "title", YYYY-MM-DD].

## Evidence / Timeline
- YYYY-MM-DD | Initial finding [Source: ...]
- YYYY-MM-DD | Update: what changed and why [Source: ...]
- YYYY-MM-DD | Conflict resolved: new source supersedes old [Source: ...]
```

## Zone Rules

**State zone (top):**
- Always current — when new evidence arrives, **rewrite** (don't append)
- Represents compiled truth, not the latest update
- Should read as a coherent summary, not a changelog
- If sources conflict: note both, prefer most recent, explain the conflict

**Evidence zone (bottom):**
- **Append-only** — never edit past entries
- Every entry: `YYYY-MM-DD | description [Source: ...]`
- Grows over time; that's expected
- Preserves provenance so future readers can trace any state claim back to its source

## Source Attribution (on every fact in the State zone)

| Source type | Format |
|---|---|
| User statement | `[Source: User, context, YYYY-MM-DD]` |
| Meeting or conversation | `[Source: Meeting "title", YYYY-MM-DD]` |
| Document / file | `[Source: filename or path, YYYY-MM-DD]` |
| Web / research | `[Source: publication or URL, YYYY-MM-DD]` |
| Synthesis from multiple | `[Source: compiled from source-a, source-b, YYYY-MM-DD]` |

**Source precedence (highest → lowest):**
1. User's direct statements
2. Compiled truth from prior observations
3. Timeline entries (raw evidence)
4. External sources

## Memory Observation Template

When writing `save_observation`, structure the body like this:

```markdown
## State
[Current understanding as of YYYY-MM-DD]
[One to three paragraphs, each fact cited.]

## Evidence / Timeline
- YYYY-MM-DD | [First known record] [Source: ...]
- YYYY-MM-DD | [What changed] [Source: ...]
```

## Why Two Zones?

A flat append-only log becomes unreadable after a few updates. A flat rewrite-in-place document loses provenance — you can't tell why something is believed. The two-zone model solves both: the top always shows current truth, the bottom always shows the evidence trail.

## Updating an Existing Observation

When new evidence arrives:
1. **Rewrite the State section** to reflect the new truth (incorporate the new evidence)
2. **Append a new entry** to the Timeline section with the date and source
3. Do not leave stale facts in the State section — they belong only in the Timeline

Never append new facts to the State section. Rewrite it entirely to synthesize old + new.
