---
name: diff-teach
desc: "Two-turn predict-then-reveal drill for diffs/commits/time-windows: show the change, get the user's prediction, end the turn, then name exactly what they missed. Not a single-turn code explainer."
---

# Diff Teach

Close comprehension debt on code the user never read line-by-line — most of it
agent-written, per this harness's own PR-automation habits. The teaching value
is in the gap between what the user predicted and what actually happened, not
in a good explanation on its own.

## When to Use

- User points at a diff, commit, or time window and wants to actually
  understand it, not just have it summarized: "explain what changed since
  Monday", "quiz me on this diff", "make sure I understand PR #47 before it merges".
- Following up on agent-heavy work (auto-created PRs, the self-improving
  code-review routine) where code shipped without the user reading it closely —
  this is the harness's own "reviewer model mismatch" concern from CLAUDE.md,
  applied to the human reviewer instead of a second model.
- User explicitly asks to be taught/quizzed/tested on a change, not just told.

## Do Not Use When

- User wants a straight explanation with no interaction — that's
  `code-documentation-code-explain` (single-turn, narrative + diagrams). Use
  that skill instead when the ask is "explain this" with no signal they want
  to be tested.
- The target isn't a diff/commit/time-window — general algorithm or system
  walkthroughs with nothing new merged belong to `code-documentation-code-explain`.
- There's no diff to point at (empty range, no commits in the window) — say so
  and stop rather than inventing a drill.

## Workflow

### 1. Resolve the target

Accept one of three input shapes and resolve it to a concrete diff:

| Input | Resolve via |
|---|---|
| A diff or commit hash | `git show <hash>` |
| A time window ("since Monday", "since last commit") | `git log --since=<date> --oneline` then `git diff <first>~1..HEAD` |
| A concept ("the retry logic") | `git log -p --all -- <path/grep-scoped>` narrowed by content, not date |

If the range is empty, tell the user and stop — do not fabricate a drill from nothing.

### 2. Show, don't explain

Present the diff (or the relevant hunks if large — don't dump an entire noisy
diff, scope to what's actually teachable). Do **not** explain what it does yet.
Ask the user directly: "What do you think this changes, and why?"

### 3. End the turn

Stop here. Wait for the user's prediction. This is the step that makes this a
drill instead of an explainer — do not preempt it by continuing into an
explanation in the same turn.

### 4. Reveal the gap

When the user responds with their prediction, compare it against what the code
actually does. The reveal must **name the specific gap**, not restate a generic
explanation:

- If they got it right: confirm precisely, and add the one non-obvious detail
  they likely didn't think to check (edge case, ordering dependency, why it
  was written this way instead of the obvious alternative).
- If they got it wrong or partial: name exactly what part of their prediction
  was off and why — cite the specific line/behavior that contradicts it. Don't
  just explain the code from scratch; anchor the explanation to their miss.

### 5. Offer the next drill

If the source was a time window with multiple commits, offer to continue to
the next one. If it was a single diff/concept, stop — don't manufacture
additional rounds.

## Checklist

- [ ] Target resolved to an actual, non-empty diff before showing anything
- [ ] Explanation withheld until after the user's prediction
- [ ] Reveal names the specific gap, not a generic walkthrough
- [ ] Large diffs scoped to teachable hunks, not dumped whole

## Tools

```bash
git show <hash>
git log --since="<date>" --oneline
git diff <ref>~1..HEAD -- <path>
```

## Example: "quiz me on what changed since Monday"

1. `git log --since="Monday" --oneline` → 3 commits touching `auth/session.py`.
2. Show commit 1's diff (a session-timeout change). Ask: "What do you think
   this changes?"
3. User: "Extends session length."
4. Reveal: "Close — it extends the *idle* timeout, not total session length.
   Total session length is still capped by `MAX_SESSION_AGE` two lines up,
   which your answer didn't account for — a long-idle-but-old session still
   gets killed."
5. Offer commit 2.

## Relationship to `code-documentation-code-explain`

That skill is the right tool for a straight one-turn explanation. This skill
exists specifically for the predict-then-reveal interaction — when in doubt,
default to `code-documentation-code-explain` unless the user's request signals
they want to be tested, not told.
