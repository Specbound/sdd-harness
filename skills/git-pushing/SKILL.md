---
name: git-pushing
description: Stage, commit with a conventional message, and push in one step. Use when the user asks to commit and push, push to remote/GitHub, or save and share their work.
---

# Git Push Workflow

Stage all changes, create a conventional commit, and push to the remote branch in one step.

## Workflow

Run the bundled script (absolute path — works from any CWD):

```bash
bash ~/.claude/skills/git-pushing/scripts/smart_commit.sh
```

With a custom message:

```bash
bash ~/.claude/skills/git-pushing/scripts/smart_commit.sh "feat: add feature"
```

The script handles staging, conventional commit message generation, the Claude footer, and `push -u` for new branches.

**Stacked PRs:** if `gh-stack` is installed and the current branch matches a
multi-task spec (`specs/<slug>/tasks.md`), the script auto-detects this on the
first task commit and routes every commit through `gh stack add` (one task = one
stack layer) instead of a plain commit, submitting each layer's PR immediately.
See the `stacking-pull-requests` skill for the eligibility rule and manual overrides.

## Constraints

- Repo conventions override this skill: respect project CLAUDE.md rules (e.g. atomic commits per task, files that must never be committed) before staging everything.
- If the script fails (no remote, detached HEAD, hooks rejecting the commit), fall back to explicit `git add`/`commit`/`push` commands and show the error rather than retrying the script.
