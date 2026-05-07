---
description: Register this project's nightly /kiro:daily-maintenance Claude Routine — run once after installing the harness in a new repo
allowed-tools: Bash, Task
---

# Kiro Setup Routine

Registers a nightly Claude Code Routine for this project so `/kiro:daily-maintenance`
runs automatically every night in the cloud, whether or not the developer has Claude open.
Run this once after installing the harness. Safe to re-run — checks for duplicates first.

## Steps

### Step 1 — Get project info

```bash
git remote get-url origin 2>/dev/null || echo "NO_REMOTE"
git rev-parse --show-toplevel 2>/dev/null | xargs basename
```

Normalize the remote URL:
- Strip `.git` suffix if present
- Convert SSH (`git@github.com:org/repo`) to HTTPS (`https://github.com/org/repo`)
- If no remote: tell the user to push to GitHub first and stop

### Step 2 — Check for existing routine

Use ToolSearch to load the RemoteTrigger tool schema:
```
ToolSearch: select:RemoteTrigger
```

Then call `RemoteTrigger { action: "list" }` and check if any existing routine
already references this repo's URL or project name. If one exists, report it and stop.

### Step 3 — Confirm with user

Show:
- **Repo URL**: the GitHub URL detected
- **Schedule**: nightly at 11pm Israel time (20:00 UTC), cron `0 20 * * *`
- **Model**: claude-sonnet-4-6
- **What it runs**: judge → reflect → housekeep → trust score → augment skills

Ask for confirmation before creating.

### Step 4 — Create the routine

Use RemoteTrigger with `action: "create"` and this body shape:

```json
{
  "name": "Kiro Daily Maintenance — <project-name>",
  "cron_expression": "0 20 * * *",
  "enabled": true,
  "job_config": {
    "ccr": {
      "environment_id": "env_01UXDipNSMfeiED2EL99tQpx",
      "session_context": {
        "model": "claude-sonnet-4-6",
        "sources": [
          { "git_repository": { "url": "<github-url>" } }
        ],
        "allowed_tools": ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
      },
      "events": [
        {
          "data": {
            "uuid": "<generate fresh lowercase v4 uuid>",
            "session_id": "",
            "type": "user",
            "parent_tool_use_id": null,
            "message": {
              "role": "user",
              "content": "<see prompt template below>"
            }
          }
        }
      ]
    }
  }
}
```

**Routine prompt template** (substitute `<project-name>` and today's date):

```
You are running the nightly Kiro Daily Maintenance pipeline for <project-name>. This is a fully automated nightly run — no user is present.

## Pre-check (MUST run first)

```bash
today=$(date +%Y-%m-%d)
if grep -q "^- $today \[judge\]:" .claude/memory/observations.md 2>/dev/null; then
  echo "routine-skip: already ran today (idempotent no-op)"
  exit 0
fi
```

If `.claude/memory/` does not exist, log `routine-skip: memory-not-bootstrapped` and exit.

## Step 1 — Judge

Read: `.claude/memory/observations.md`, `.claude/memory/trace.log` (if present), `.claude/memory/hot-memory.md`, `.claude/kiro/settings/rules/session-quality-rubric.md` (if present).

Analyze the last 24h. Score charges (clean completions, memory hits) and drains ([memory-gap], [revert], repeated errors, re-explanations). Compute score_delta in [-5, +5].

Append to observations.md:
`- YYYY-MM-DD [judge]: delta=X.X, charges=N, drains=N. Summary: "<one line>"`

## Step 2 — Reflect

Based on Judge drains and [memory-gap] entries: update `.claude/memory/hot-memory.md` with patterns that should be remembered. Do NOT touch the `## Harness Trust Score:` line.

Append: `- YYYY-MM-DD [reflect]: +N observations updated. Patterns promoted: N.`

## Step 3 — Housekeeping

If observations.md > 50 entries: archive oldest 20 to `.claude/memory/glacier/observations-YYYY-MM.md`. Validate hot-memory.md < 50 lines.

Append: `- YYYY-MM-DD [housekeeping]: archived=N entries, hot-memory=N/50 lines.`

## Step 4 — Update Trust Score

```bash
python3 .claude/scripts/trust_score.py apply --delta "<score_delta>" --summary "<summary>"
```

Skip silently if script missing.

## Step 5 — Surface unresolved memory-gaps

Count today's [memory-gap] entries not resolved by Step 2. If > 0:
`- YYYY-MM-DD [routine-alert]: N memory-gaps unresolved — re-explanation drain is compounding`

## Step 6 — Commit and push

```bash
git config user.email "routine@claude.ai"
git config user.name "Claude Routine"
git add .claude/memory/
git commit -m "chore: nightly maintenance $(date +%Y-%m-%d)"
git push
```

## Error isolation

Each step is independent. On failure: log `[routine-error]: step-N failed — <reason>` and continue.
```

### Step 5 — Output the result

Show:
- Routine name and ID
- Next scheduled run (converted to Israel time)
- Link: `https://claude.ai/code/routines/<routine-id>`
- Reminder: "To disable, visit the link above or set `SDD_SKIP_ROUTINE=1` before running `install.sh`"
