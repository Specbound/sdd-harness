---
name: pr-babysit
desc: "Background-watches a PR's CI and reviews after auto-create via Monitor, not blocking polls. Triages failures/comments, fixes pre-authorized items. Never merges, rebases, force-pushes, or approves CI."
---

# PR Babysit

Watch a PR to green after it's opened — CI runs, review comments land — without
blocking the session on a poll loop and without silently drifting stale against
its base branch.

## When to Use

- A PR was just auto-created (by `pr-auto-create-hook.sh` / `pr-mention-nudge.sh`)
  and needs someone watching CI/review feedback until it's mergeable.
- User says "babysit this PR", "watch CI on #123", "keep an eye on this PR".
- Resuming a PR conversation after a break to check what happened while away.

## Do Not Use When

- No PR exists yet for the branch — run the auto-create flow first
  (`scripts/pr/detect_base_and_create.sh`).
- The user wants a one-shot check of current CI state, not ongoing watching —
  just run `gh pr checks <n>` directly.
- The task requires merging, rebasing, force-pushing, or approving CI —
  see Authority Boundary below. This skill never does those regardless of how
  the request is phrased.

## Workflow

### 1. Identify the PR

```bash
gh pr view --json number,title,headRefName,baseRefName,url
```

If ambiguous (multiple PRs from this branch, or none), ask which PR before continuing.

### 2. Check branch currency before watching

A PR can go green on CI and still be stale against its base. Before starting the
watch, check for drift:

```bash
git fetch origin "$base_branch" --quiet
git merge-base --is-ancestor "origin/$base_branch" HEAD || echo "STALE: base has moved, rebase may be needed"
```

If stale, tell the user — do not auto-rebase (see Authority Boundary). Merging
main into a stale branch without asking risks conflicts the user didn't expect.

### 3. Start the background watch

Use the **Monitor** tool, not a blocking `gh pr checks --watch` loop — this is
the key difference from `iterate-pr`'s approach. One `Monitor` call watches CI
and review state and only produces a notification when something changes:

```bash
prev=""
while true; do
  cur=$(gh pr checks "$PR_NUMBER" --json name,bucket 2>/dev/null | jq -r '.[] | "\(.name):\(.bucket)"' | sort)
  reviews=$(gh pr view "$PR_NUMBER" --json reviews --jq '.reviews | length')
  snapshot="$cur|reviews:$reviews"
  if [ "$snapshot" != "$prev" ]; then
    echo "$snapshot"
    prev="$snapshot"
  fi
  gh pr checks "$PR_NUMBER" --json bucket --jq 'all(.bucket != "pending")' 2>/dev/null | grep -q true && break
  sleep 30
done
```

Pick a poll interval matched to how fast CI actually moves (30s default; widen
for slow pipelines). Set a budget so the watch doesn't run forever: default to
an 8-hour active-watch cap and a 3-day wall-clock cap — if either is hit, stop
and tell the user CI/review is still pending rather than watching indefinitely.

### 4. On each notification, triage

When the Monitor fires, pull the actual failure or comment and triage it using
`iterate-pr`'s process (already installed at `~/.claude/skills/iterate-pr/SKILL.md`
— follow its Investigate Failures / Validate Feedback / Address Valid Issues
steps rather than re-deriving them here):

1. **CI failure** — read the failing job's log, determine root cause (real bug
   vs. flaky/infra), fix if real.
2. **Review comment** — read it, decide if it's actionable, fix if valid, reply
   if it needs clarification instead of a code change.
3. **Commit and push** the fix (plain push — the destructive-op guard blocks
   force-push regardless, see Authority Boundary).
4. Let the watch loop pick up the new CI run automatically.

### 5. Stop conditions

Stop the watch (`TaskStop` on the Monitor) when any of:

- All checks pass and no unresolved review comments remain → tell the user
  it's ready for merge (but do not merge it).
- The active-watch or wall-clock budget is exhausted → tell the user watching
  stopped and why, with current status.
- A failure needs a decision only the user can make (ambiguous review comment,
  a design question) → surface it and stop, don't guess.

## Authority Boundary

| Action | Authorized? |
|---|---|
| Fix code in response to CI failure or review comment | Yes |
| Commit and push (plain push) | Yes |
| Reply to a review comment | Yes |
| Merge the PR | **No — always ask** |
| Rebase onto a moved base branch | **No — always ask** |
| Force-push | **No — hard-blocked** by `git-destructive-guard-hook.sh` regardless of this skill |
| Approve/dismiss CI checks, approve the PR itself | **No — never** |

This mirrors the harness's existing system-wide destructive-op boundary — this
skill doesn't need to re-implement the guard, just respect it.

## Tools

```
Monitor({command: "<poll loop above>", description: "CI/review state on PR #123", persistent: true})
gh pr checks <n> --json name,bucket
gh pr view <n> --json reviews,comments
TaskStop(task_id) — when a stop condition is hit
```

## Example: "babysit PR #47"

1. `gh pr view 47 --json number,headRefName,baseRefName` → branch `feat/x`, base `main`.
2. Currency check: `main` hasn't moved since branch point → not stale.
3. Start Monitor with 30s poll on checks + review count.
4. Notification: `lint:fail`. Read log → unused import. Fix, commit, push.
5. Notification: all checks pass, 1 new review comment requesting a rename.
   Valid → rename, commit, push.
6. Notification: all checks pass, 0 unresolved comments → stop watch, tell user
   PR #47 is ready for merge review.

## Handoff to `iterate-pr`

`iterate-pr` (marketplace skill) already encodes a solid single-shot CI/feedback
triage loop — this skill wraps it in Monitor-based background watching plus the
branch-currency check and explicit authority boundary that `iterate-pr` doesn't
have. Don't duplicate its triage logic; invoke it (or follow its steps inline)
for the actual "diagnose and fix" work once a notification fires.
