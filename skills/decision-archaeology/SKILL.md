---
name: decision-archaeology
description: "/why-style dig: trace a line/file/function back through git blame → commit → PR/issue → chat context to answer 'why does this exist'. Use when the reason behind existing code isn't in a comment and needs reconstructing."
metadata:
  type: skill
  source: codenewsletter — pstack pt.2
---

# Decision Archaeology

Answers "why is this here" for code with no comment explaining it. Distinct from
`[[repo-drift-review]]` (checks harness *structural* integrity — missing files, stale
links) — this reconstructs the *reasoning* behind one specific piece of existing code.

## When to Use This Skill

- User asks "why does this exist", "who decided this", "why is it done this way", pointing
  at a specific line, function, or file
- About to change or remove code and want to confirm the original constraint still holds
  before treating it as dead weight (Chesterton's Fence, but with real evidence instead
  of a guess)
- A review flags a line with no traceable rationale (pairs with `[[receiving-code-review]]`'s
  intent-provenance check — that's the checklist that flags it; this is the dig that answers it)

## Workflow

### Phase 1 — Blame the Target

`git blame -L <start>,<end> -- <file>` (or the whole line range if unspecified) to find the
commit(s) that introduced or last touched the code. If blame shows many small commits
(reformatting, rename-only), walk back further with `git log -L` or `git log --follow -p`
until you find the commit that changed *behavior*, not just formatting.

### Phase 2 — Read the Commit

`git show <sha>` for the full commit message and diff. Note:
- What else changed in the same commit (siblings often explain the "why" better than the
  line itself)
- Any `Fixes #N` / `Closes #N` / `Refs #N` / bare `#N` reference in the message

### Phase 3 — Follow the Reference

If Phase 2 found an issue/PR number and the repo has a GitHub remote: `gh pr view <N>` or
`gh issue view <N>` for the discussion, linked design doc, or reviewer back-and-forth. If
no number is present, check nearby commits (same day, same author) for one that does — a
multi-commit PR often has the rationale on only one of its commits.

### Phase 4 — Check Project Memory

If Phases 2–3 didn't surface a rationale, search project-local records dated near the
commit:
- `specs/` — was this covered by an approved spec?
- `.claude/memory/` — decisions, patterns, or `ERRORS.md` entries from that window
- `.claude/steering/` — a convention doc that predates and explains the choice

### Phase 5 — Synthesize

Report, don't just dump raw findings:

```
## Why: <file>:<line-range>

**Commit:** <sha short> — <date> — <author>
**Change:** <one line: what the commit actually did>
**Reason:** <the stated rationale, quoted or closely paraphrased from commit msg/PR/issue>
**Source:** <PR #N / issue #N / spec path / "none found">
**Still valid?** <does the stated constraint still hold today, based on what's changed since>
```

If no rationale is found anywhere (commit message is a code dump, no linked issue, no
memory entry), say so plainly — "no traceable reason found, oldest commit is `<sha>`,
author `<name>`" — rather than inventing a plausible-sounding one. A guessed rationale is
worse than an honest gap, because it gets treated as fact on the next read.

## Pitfalls

- **Stopping at the first commit found.** A rename or lint-fix commit is rarely the origin;
  keep walking `git log -L` until behavior actually changes.
- **Trusting the commit message over the diff.** Messages drift from what the diff really
  did, especially on squash-merges; read the diff to confirm the message's claim.
- **Inventing a rationale when none exists.** Report the gap instead — that gap is itself
  useful signal (candidate for `[[receiving-code-review]]`'s provenance check, or for
  removal once confirmed genuinely unexplained).
