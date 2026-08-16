# Git Conflict Resolution

`SKILL.md` pointed here for advanced conflict resolution strategy — this was previously a dead reference (the file didn't exist). Adapted from mattpocock/skills' `resolving-merge-conflicts` (MIT).

## The 5-Step Discipline

A conflict marker tells you *where* two changes collide, not *why* either change was made. Resolving by pattern-matching the diff syntax (accept-yours / accept-theirs, or splicing both blindly) throws away that intent and reintroduces the bug either branch was written to avoid.

1. **See the current state.** `git status`, `git diff` — know exactly which files conflict and whether you're mid-merge or mid-rebase (they resolve differently: `--continue`/`--abort` target different operations).
2. **Find each side's primary source.** Read the commit messages and, where available, the PR description or linked issue for *both* changes. You're reconstructing why each hunk exists, not just what it changed.
3. **Resolve each hunk to preserve both intents where possible.** Where the two changes are genuinely incompatible, pick the one that matches the merge's stated goal, and leave a comment noting the trade-off you made and why. **Never invent new behavior** to paper over the conflict — if neither side's code cleanly resolves it, that's a signal to go ask, not to guess.
4. **Run the project's automated checks** — typically typecheck, then tests, then format/lint, in that order — and fix anything the merge broke before it broke it a second time in the next commit.
5. **Finish the operation.** Stage everything and commit (merge) or continue rebasing until every commit is replayed (rebase). **Never `--abort`** as a way to escape a conflict you don't understand — that just defers the same conflict to whoever merges next, with less context than you have right now.

## Worked Example

```bash
# 1. See current state
git status
# both modified: src/auth/session.py

# 2. Find primary sources — both sides touched the same function
git log --oneline main -- src/auth/session.py | head -5
git log --oneline HEAD -- src/auth/session.py | head -5
# main: "fix: extend session timeout to 24h (closes #412 — users losing work on long sessions)"
# HEAD: "feat: add device fingerprint to session validation (security review action item)"

# 3. Resolve preserving both intents — this is a compatible conflict:
#    keep the 24h timeout AND add the fingerprint check, don't drop either
$EDITOR src/auth/session.py

# 4. Run checks in order
mypy src/auth/session.py
pytest tests/auth/test_session.py
ruff format src/auth/session.py

# 5. Finish
git add src/auth/session.py
git rebase --continue   # or: git commit, if this was a merge
```

## When the Conflict Really Is Incompatible

Not every conflict has a "preserve both" resolution — sometimes the two changes contradict each other (one branch removes a field the other branch's new code depends on). In that case:

- Pick the resolution that matches the *merge's* stated goal (what is this merge/rebase actually trying to accomplish?), not whichever side happens to be `ours`/`theirs` in the tool's framing.
- Leave an inline comment at the resolution site noting the trade-off and why — the next person to touch this code needs the same context you just reconstructed in step 2, and won't get it from the diff alone.
- If you can't determine which side should win without guessing, stop and ask rather than inventing a compromise — see step 3's "never invent new behavior."

## See Also

- `SKILL.md`'s Workflow 5 (Recover from Mistakes) for reflog-based recovery if a resolution goes wrong after it's already committed.
- `SKILL.md`'s "Best Practices" #7 (branch before risky operations) — create a backup branch before a rebase you expect to have many conflicts, so a botched resolution is a `git reset --hard backup-branch` away, not a re-derivation from scratch.
