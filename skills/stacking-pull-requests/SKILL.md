---
name: stacking-pull-requests
description: Reference for the harness's automated stacked-PR flow. Maps GitHub's native stacked pull requests (public preview, 2026-07-30, via the gh-stack CLI extension) onto SDD's one-task-one-commit convention — one task commit becomes one stack layer instead of everything bundling into a single PR. Load when a stack needs manual intervention (sync conflict, reordering, abandoning), when tuning the auto-trigger threshold, or when explaining why a branch did/didn't stack.
---

# Stacking Pull Requests

This is documentation for an **automated** mechanism, not a manual procedure. The
decision to stack — and the stacking itself — happens in two harness scripts, not
via this skill being invoked in the loop.

## When to Activate

- `gh stack sync` / `gh stack submit` failed or printed a conflict/divergence warning.
- User asks to reorder, insert, or fold layers in an existing stack.
- User wants to abandon a stack and fall back to one bundled PR.
- User wants to tune or disable the auto-trigger (`SDD_STACK_MIN_TASKS`, `SDD_SKIP_STACK`).
- User asks why a branch did or didn't auto-stack.

## Do Not Use When

- The stack is working normally (init'd, layers submitting cleanly) — nothing to
  troubleshoot means nothing to load this skill for.
- The user wants to *learn `gh stack`'s CLI from scratch* — point them at
  `gh stack --help` / GitHub's own docs instead; this skill isn't a CLI tutorial.
- The task is about a single-PR (non-stacked) branch's normal review flow — that's
  `create-pr` / `pr-babysit` territory, not this skill's.

## Where the automation lives

| Step | File | What it does |
|---|---|---|
| Per-task commit | `skills/git-pushing/scripts/smart_commit.sh` | Detects eligibility, inits the stack on the first task commit, uses `gh stack add` instead of `git commit` for every commit while a stack is active |
| Push / PR creation | `scripts/pr/detect_base_and_create.sh` | If `.git/gh-stack` exists, runs `gh stack submit --auto` (creates/updates every layer's PR) instead of `gh pr create` for one bundled PR |

## Eligibility rule (what triggers auto-init)

All of the following, checked in `smart_commit.sh` on every commit:

1. `gh` CLI present and the `github/gh-stack` extension installed.
2. No stack active yet for this branch (`.git/gh-stack` doesn't exist).
3. A `specs/<slug>/tasks.md` exists whose `<slug>` appears in the current branch name.
4. That spec has `SDD_STACK_MIN_TASKS` or more total tasks (checked + unchecked). Default: **2**.

If all four hold, the first task commit runs `gh stack init <branch>` and every commit
from then on (this branch, until the stack is abandoned) goes through `gh stack add`
instead of a plain commit, then `gh stack submit --auto` right away so each layer's PR
exists as soon as its task lands.

If `gh stack add` ever fails mid-stream, `smart_commit.sh` falls back to a plain
`git commit` for that task rather than blocking — the task's work still lands, just
outside the stack for that one commit.

## Manual controls

- **Disable for one commit or one branch:** set `SDD_SKIP_STACK=1` before calling
  `smart_commit.sh`, or before the branch's first task commit to prevent auto-init entirely.
- **Force-enable a branch that didn't auto-trigger** (e.g. slug didn't match branch
  name): run `gh stack init <branch>` yourself once — every commit after that is
  detected via `.git/gh-stack` and routed through the stack automatically.
- **Tune the threshold:** `SDD_STACK_MIN_TASKS=3 bash smart_commit.sh` (or export it
  for the session) if 2-task specs feel like too much stacking overhead.
- **Abandon a stack mid-flight, fall back to one bundled PR:** delete `.git/gh-stack`,
  then either squash the layer branches manually or let the next push hit the normal
  `gh pr create --fill --draft` path in `detect_base_and_create.sh`.

## When NOT to stack (use judgment before force-enabling)

- Tasks that aren't independently reviewable — e.g. task 2's diff only makes sense
  read alongside task 1's (a type definition and its first real usage, split awkwardly).
- The branch is shared with collaborators unfamiliar with reviewing stacked PRs.
- The team's review tooling (bots, required-check config) doesn't yet handle
  cascading-merge stacks correctly — check before relying on "merge top layer merges
  everything below it."

## Troubleshooting

- **Sync/rebase conflict:** the docs note that in a non-interactive terminal a
  divergence aborts `gh stack sync` rather than prompting. Run `gh stack sync`
  yourself in an interactive terminal to resolve it, then re-push.
- **Reordering or inserting a layer:** `gh stack modify` supports Insert and
  Fold up/Fold down operations on an existing stack.
- **Picking a stack to resume:** `gh stack checkout` opens a picker across local
  and remote stacks.
- **Full CLI reference:** this skill deliberately doesn't restate `gh stack`'s
  command surface — it's public preview and can change. Run `gh stack --help`,
  see https://github.com/github/gh-stack, or use the companion agent skill GitHub
  ships alongside the extension for exact syntax.

## Requirements

- GitHub CLI (`gh`) v2.0+
- `gh extension install github/gh-stack`
