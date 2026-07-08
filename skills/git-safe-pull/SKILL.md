---
name: git-safe-pull
description: Pull remote changes while preserving all local work (uncommitted or committed). Use when the user wants to sync with remote without losing local changes, mentions "pull but keep my changes", "see what remote changed", or needs to resolve conflicts between local and remote.
---

# Git Safe Pull

Integrate remote changes into a branch that has local work, without losing anything. Works for both uncommitted edits and committed divergence.

## When to Use

- "Pull remote but keep my changes"
- "Sync with remote without losing local work"
- "See what changed upstream and merge it in"
- "Resolve conflicts so I have all changes"

## Step 1 — Inspect Before Pulling

Always fetch first to understand the divergence before touching anything:

```bash
git fetch origin
git log --oneline HEAD..origin/master    # commits remote has that you don't
git log --oneline origin/master..HEAD    # commits you have that remote doesn't
git status                               # uncommitted local changes
```

Read the output before proceeding. The situation determines the strategy.

## Step 2 — Choose Strategy

### Case A: Uncommitted local changes + remote is ahead (most common)

Use `--autostash --rebase`:

```bash
git pull --rebase --autostash origin master
```

Git will: stash your working-tree changes → fast-forward to remote → re-apply your stash on top. If there are no conflicts, you're done.

### Case B: Committed local divergence (both sides have commits)

Rebase your commits on top of remote:

```bash
git rebase origin/master
```

This replays your local commits on top of the remote's latest, keeping a linear history. Use `git rebase --abort` to bail if things go wrong.

If you prefer a merge commit instead:

```bash
git merge origin/master
```

### Case C: Mixed (uncommitted changes + committed divergence)

Stash first, then rebase, then pop:

```bash
git stash push -m "wip before safe-pull"
git rebase origin/master
# resolve any rebase conflicts, then:
git stash pop
# resolve any stash-pop conflicts
```

## Step 3 — Resolve Conflicts (if any)

During rebase or stash pop, conflicts appear as `<<<<<<< HEAD` markers in files.

For each conflicted file:
1. Open the file, find the markers
2. Keep both sides' changes (the goal is ALL changes, not one or the other)
3. Remove the `<<<<<<<`, `=======`, `>>>>>>>` markers
4. Stage the resolved file: `git add <file>`

Continue after resolving:
```bash
git rebase --continue   # if mid-rebase
# or for stash-pop conflicts: just commit after staging
```

Check nothing was missed:
```bash
git diff --check          # finds leftover conflict markers
git status                # should be clean or show only your work
```

## Step 4 — Verify

```bash
git log --oneline -5                    # confirm remote commits are in history
git diff origin/master                  # should show only your new local work, if any
```

## Quick Reference

| Situation | Command |
|-----------|---------|
| Uncommitted edits, remote ahead | `git pull --rebase --autostash origin master` |
| Both sides have commits | `git rebase origin/master` |
| Mixed | `git stash && git rebase origin/master && git stash pop` |
| Abort a failed rebase | `git rebase --abort` |
| Check for leftover conflict markers | `git diff --check` |
