---
name: create-pr
description: "Creates pull requests with captured before/after evidence in the body. Use when opening PRs, writing PR descriptions, or preparing changes for review."
source: "https://github.com/getsentry/skills/tree/main/plugins/sentry-skills/skills/create-pr"
risk: safe
---

# Create Pull Request

Create pull requests following Sentry's engineering practices.

## When to Use This Skill

Use this skill when:
- Opening pull requests
- Writing PR descriptions
- Preparing changes for review
- Following Sentry's code review guidelines
- Creating PRs that follow best practices

**Requires**: GitHub CLI (`gh`) authenticated and available.

## Prerequisites

Before creating a PR, ensure all changes are committed. If there are uncommitted changes, run the `sentry-skills:commit` skill first to commit them properly.

```bash
# Check for uncommitted changes
git status --porcelain
```

If the output shows any uncommitted changes (modified, added, or untracked files that should be included), invoke the `sentry-skills:commit` skill before proceeding.

## Process

### Step 1: Verify Branch State

```bash
# Detect the default branch
BASE=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')

# Check current branch and status
git status
git log $BASE..HEAD --oneline
```

Ensure:
- All changes are committed
- Branch is up to date with remote
- Changes are rebased on the base branch if needed

### Step 2: Analyze Changes

Review what will be included in the PR:

```bash
# See all commits that will be in the PR
git log $BASE..HEAD

# See the full diff
git diff $BASE...HEAD
```

Understand the scope and purpose of all changes before writing the description.

### Step 3: Write the PR Description

Use this structure for PR descriptions (ignoring any repository PR templates):

```markdown
<brief description of what the PR does>

<why these changes are being made - the motivation>

<alternative approaches considered, if any>

<any additional context reviewers need>
```

**Do NOT include:**
- "Test plan" sections
- Checkbox lists of testing steps
- Redundant summaries of the diff

**Do include:**
- Clear explanation of what and why
- Links to relevant issues or tickets
- Context that isn't obvious from the code
- Notes on specific areas that need careful review
- An `## Evidence` section (see Step 3b) — this is not a test plan. A test plan
  states what you intend to check; evidence is the captured result of having
  checked. The exclusion above bans the former, not the latter.

### Step 3b: Attach Runtime Evidence

Everything else in the description is your own account of your own work. The
reviewer cannot check it. Give them something they can.

Append to the body:

```markdown
## Evidence
**Before:** <symptom reproduced — screenshot, video, or command + output>
**After:**  <same probe, post-fix — screenshot, video, or command + output>
```

Which form to use:

| Change has... | Evidence |
|---|---|
| A visible surface (UI, report, generated doc) | Before/after screenshot or video |
| No visible surface (logic, perf, data) | Before/after numbers, or the failing then passing output of the same command |
| Genuinely nothing to show (docs, comments, pure rename) | One line saying so, under the same heading |

**Use the same probe both times.** A "before" from one command and an "after"
from a different one proves nothing — it is two unrelated facts side by side.

**Capture the before-state while reproducing the problem, before you fix it.**
This is the load-bearing rule and the easiest one to skip. Before the fix, the
capture is one command. After the fix it costs a revert, so it is usually
skipped, and what gets written instead is a description of the old behavior
recalled from memory and presented as an observation.

If the before-state is already gone, write `Before: not captured` and say why.
Never reconstruct it and present it as a capture.

`hooks/claude/pr-evidence-hook.sh` checks for the `## Evidence` heading on
`gh pr create` and nudges when it is missing. It does not block, and it cannot
tell real evidence from a plausible-looking paragraph — that part is on you.

### Step 4: Create the PR

```bash
gh pr create --draft --title "<type>(<scope>): <description>" --body "$(cat <<'EOF'
<description body here>
EOF
)"
```

**Title format** follows commit conventions:
- `feat(scope): Add new feature`
- `fix(scope): Fix the bug`
- `ref: Refactor something`

## PR Description Examples

### Feature PR

```markdown
Add Slack thread replies for alert notifications

When an alert is updated or resolved, we now post a reply to the original
Slack thread instead of creating a new message. This keeps related
notifications grouped and reduces channel noise.

Previously considered posting edits to the original message, but threading
better preserves the timeline of events and works when the original message
is older than Slack's edit window.

Refs SENTRY-1234
```

### Bug Fix PR

```markdown
Handle null response in user API endpoint

The user endpoint could return null for soft-deleted accounts, causing
dashboard crashes when accessing user properties. This adds a null check
and returns a proper 404 response.

Found while investigating SENTRY-5678.

## Evidence
**Before:** `curl -s /api/users/9821` -> `500`, traceback in api.log:441
**After:**  `curl -s /api/users/9821` -> `404 {"detail":"not found"}`

Fixes SENTRY-5678
```

### Refactor PR

```markdown
Extract validation logic to shared module

Moves duplicate validation code from the alerts, issues, and projects
endpoints into a shared validator class. No behavior change.

This prepares for adding new validation rules in SENTRY-9999 without
duplicating logic across endpoints.
```

## Issue References

Reference issues in the PR body:

| Syntax | Effect |
|--------|--------|
| `Fixes #1234` | Closes GitHub issue on merge |
| `Fixes SENTRY-1234` | Closes Sentry issue |
| `Refs GH-1234` | Links without closing |
| `Refs LINEAR-ABC-123` | Links Linear issue |

## Guidelines

- **One PR per feature/fix** - Don't bundle unrelated changes
- **Keep PRs reviewable** - Smaller PRs get faster, better reviews
- **Explain the why** - Code shows what; description explains why
- **Mark WIP early** - Use draft PRs for early feedback

## Editing Existing PRs

If you need to update a PR after creation, use `gh api` instead of `gh pr edit`:

```bash
# Update PR description
gh api -X PATCH repos/{owner}/{repo}/pulls/PR_NUMBER -f body="$(cat <<'EOF'
Updated description here
EOF
)"

# Update PR title
gh api -X PATCH repos/{owner}/{repo}/pulls/PR_NUMBER -f title='new: Title here'

# Update both
gh api -X PATCH repos/{owner}/{repo}/pulls/PR_NUMBER \
  -f title='new: Title' \
  -f body='New description'
```

Note: `gh pr edit` is currently broken due to GitHub's Projects (classic) deprecation.

## References

- [Sentry Code Review Guidelines](https://develop.sentry.dev/engineering-practices/code-review/)
- [Sentry Commit Messages](https://develop.sentry.dev/engineering-practices/commit-messages/)
