---
name: codex-review
description: Drive the Codex CLI's `codex review` over a diff, with a CHANGELOG gate and a fix-what-it-finds rule. Use when asked for a Codex code review.
risk: unknown
source: community
---

# codex-review

## Precondition — check this first

```bash
command -v codex || echo "codex CLI not installed"
```

`codex` is **not installed on this machine** (checked). Without it nothing in
this file runs. Say so and stop, or use the harness's own `/code-review`
instead — do not hand back a review that was never executed.

The upstream install line `npx skills add -g BenedictKing/codex-review` also
cannot run here: `npx` is absent.

## Why the CHANGELOG step exists

`codex review --uncommitted` shows the tool what was done. It does not show
what you were trying to do. Writing the intent into `CHANGELOG.md` *before*
the review turns one input into two, and the review gets better. That is the
whole reason for step 1 — it is not bookkeeping.

## Steps

**1. Read the working tree.**

```bash
git diff --name-only && git status --short
```

Uncommitted changes → carry on. Clean tree → skip to `codex review --commit HEAD`.

**2. Gate on CHANGELOG.** If `git diff --name-only | grep -iE 'changelog'`
returns nothing, write the entry yourself from `git diff --stat` and
`git diff` — insert under `[Unreleased]` with an `Added` / `Changed` / `Fixed`
heading. Do not ask the user to do it.

**3. Stage untracked files.** Codex reports a P1 on files git does not track:

```bash
git ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do git add -- "$f"; done
```

This touches new files only; modified files stay unstaged.

**4. Size the job, then run it.**

```bash
git diff --stat HEAD | tail -1
```

`HEAD` matters: plain `git diff --stat` misses staged changes and `--cached`
misses unstaged. Read the last line only — per-file lines have no totals.
Git drops `insertions(+)` or `deletions(-)` entirely when zero, and says
`1 file changed` in the singular; parse for both.

| Condition (first match wins) | Effort | Timeout |
|---|---|---|
| ≥30 files or ≥2000 changed lines | `xhigh` | 40 min |
| ≥10 files | `xhigh` | 15 min |
| ≥500 changed lines | `xhigh` | 15 min |
| ≥300 insertions or ≥300 deletions | `xhigh` | 15 min |
| anything else | `high` | 10 min |

Run lint first, then review, in one isolated subtask so the diff does not
land in the main context:

```bash
# Python; swap the first half per language
black . && ruff check --fix . && \
  codex review --uncommitted --config model=gpt-5.3-codex --config model_reasoning_effort=high
```

Go: `go fmt ./... && go vet ./...`. Node: `npm run lint:fix`.

**5. Fix what it finds.** P0, P1 and P2 get fixed in the same run, then the
command is run again to confirm. Report only after the recheck. P3 and below
may be reported as-is. Keep each fix to the issue named — no side refactors.
If Codex says the CHANGELOG and the code disagree, decide which one is wrong
and correct that one.

## CLI reference

`codex review [OPTIONS] [PROMPT]`

| Option | Meaning |
|---|---|
| `--uncommitted` | staged + unstaged + untracked |
| `--base <BRANCH>` | diff against a branch |
| `--commit <SHA>` | one commit |
| `--title <TITLE>` | label shown in the summary |
| `-c, --config <k=v>` | config override |

`--uncommitted`, `--base` and `--commit` are mutually exclusive, and none of
them can be combined with a bare `[PROMPT]`. Must run inside a git repo.

## Provenance

Ported from upstream `BenedictKing/codex-review` v2.1.9 `SKILL.md`, trimmed to
the parts that are instructions rather than restatement. The absence of
`codex` and `npx` here was checked with `command -v`. Nothing in this file was
executed against the Codex CLI, so the thresholds, flags and model name are
upstream's claims, not verified behaviour.
