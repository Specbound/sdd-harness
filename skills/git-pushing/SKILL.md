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

## Constraints

- Repo conventions override this skill: respect project CLAUDE.md rules (e.g. atomic commits per task, files that must never be committed) before staging everything.
- If the script fails (no remote, detached HEAD, hooks rejecting the commit), fall back to explicit `git add`/`commit`/`push` commands and show the error rather than retrying the script.
