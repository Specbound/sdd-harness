---
name: verification-skill-authoring
description: "Create a domain-specific verification skill that encodes manual checks as Claude-executable steps. Use when setting up a new project or domain that needs a companion verify skill."
risk: safe
source: local
---

# Verification Skill Authoring

Turn manual domain checks into a reusable `<domain>-verify` skill so Claude self-verifies mid-work without prompting.

## When to Use This Skill

- Setting up verification for a new project, domain, or tech stack
- Invoked automatically after a new skill is created (skill-extraction Phase 5d, skill-creator Phase 4d)
- User says "create a verify skill for X" or "encode my X review process"
- No existing `<domain>-verify` skill covers this domain

## Do Not Use This Skill When

- A verify skill for this domain already exists — augment it instead
- The domain is already covered by deterministic CI (lint/type/test) — those run without a skill

## Workflow

### Phase 1: Identify the Domain

Determine the verification domain from context:
- What was just built / what skill was just created?
- What is the primary artifact type? (UI, API endpoint, data pipeline, CLI output, generated file, etc.)

Name the companion skill: `<domain>-verify` (e.g., `frontend-verify`, `api-verify`, `pipeline-verify`).

### Phase 2: Elicit Manual Checks

Ask the user (or infer from context if obvious):

1. **What do you manually check after Claude makes a change in this domain?**
   - Walk through your mental checklist step by step.
2. **What tools do you use?** (browser, curl, logs, a dashboard, a specific CLI)
3. **What signals tell you something is wrong?** (error messages, visual artifacts, wrong output shape)
4. **Are any checks qualitative?** (layout looks right, tone is correct, numbers are plausible) — these need a rubric.

If the user struggles to articulate steps, offer the domain defaults below as a starting point and ask them to trim/add.

### Phase 3: Map Checks to Tools

Translate each manual check to a Claude Code tool:

| Manual check | Claude-executable equivalent |
|---|---|
| Open browser, look for errors | Chrome DevTools MCP → navigate, check console |
| Click around as a user would | Chrome DevTools MCP → click, screenshot |
| Run `curl` against endpoint | Bash: `curl -s <url>` + assert response shape |
| Check log output | Bash: `tail -n 50 <logfile>` or `docker logs <container>` |
| Read generated file | Read tool → scan for expected content |
| Run the app | Bash: `<start command>` → check exit code + stdout |
| Qualitative check | Define a rubric: list pass conditions explicitly |

For **qualitative checks**: write explicit pass/fail criteria. "Looks good" is not a criterion. Example: "Page must load within 3s, no layout shift above 0.1 CLS, no console errors."

### Phase 4: Draft the Skill

Generate `~/.claude/sdd-harness/skills/<domain>-verify/SKILL.md` using this template:

```markdown
---
name: <domain>-verify
description: "Verify <domain> changes end-to-end. Run after every <domain> change before claiming work complete."
risk: safe
source: local
---

# <Domain> Verify

Run a two-pass verification after every <domain> change. Fix issues and re-verify before responding.

## When to Use This Skill

- Any <domain> file or artifact was modified
- About to claim a <domain> change is done
- Invoked by the two-layer verification pattern

## Do Not Use This Skill When

- No <domain> files were changed
- This is a pure refactor with no behavioral change (run tests instead)

## Verification Pass 1: Correctness

[Steps to verify the change does what it should — tool calls, commands, assertions]

## Verification Pass 2: Quality / Side Effects

[Steps to check for regressions, performance, visual correctness, or side effects]

## Pass Criteria

[Explicit list of what PASS looks like — no ambiguity]

## Fail Signals

[Common failure patterns and what they indicate]
```

Keep the skill under 300 lines. Move rubrics or extended examples to `resources/`.

### Phase 5: Validate and Install

Run the standard quality checks:
- Frontmatter valid, `name` matches directory
- Trigger condition is specific ("after every frontend change" not "when useful")
- Every step uses a real Claude Code tool or Bash command
- Pass criteria are explicit

Write to `~/.claude/sdd-harness/skills/<domain>-verify/SKILL.md`, then sync:
```bash
cp -r ~/.claude/sdd-harness/skills/<domain>-verify ~/.claude/skills/
```

### Phase 6: Wire as a Trigger

After installation, suggest where to invoke the skill automatically:

- **In `finishing-a-development-branch`**: add domain detect → invoke verify before offering merge/PR options
- **In the project's `kiro:ship`**: reference the verify skill in Step 1
- **In CLAUDE.md** (optional): add a "Quality Gates" line: `<domain>-verify: after each <domain> change`

## Domain Defaults (Starting Points)

Use these if the user has no process written down yet:

**Frontend:**
1. Dev server running? (`npm run dev` exits 0 or is already running)
2. Target URL loads without console errors
3. Changed element renders and behaves as expected
4. No layout shift on adjacent elements
5. Mobile viewport renders correctly (if responsive)

**API / Backend:**
1. Service starts (`<start cmd>` exits 0)
2. Target endpoint returns expected status + shape (`curl -s`)
3. Edge cases tested (empty input, auth failure, large payload)
4. No new errors in application logs

**Data Pipeline:**
1. Pipeline runs without errors (`<run cmd>` exits 0)
2. Output shape matches schema (row count, column names, types)
3. Sample rows look plausible (no nulls where unexpected, values in range)
4. No duplicate keys in output

**CLI / Script:**
1. Script runs with happy-path args (`<cmd> <args>`)
2. Error cases print useful messages (missing arg, bad input)
3. Exit codes correct (0 on success, non-zero on failure)

## Related Skills

- `verification-before-completion` — the enforcement gate (evidence before claims); this skill creates the evidence-gathering tool
- `finishing-a-development-branch` — final step where verify runs before merge/PR
- `kiro:ship` — pre-ship pipeline that should reference the domain verify skill
- `tdd-workflow` — TDD red-green cycle; pairs with verify for end-to-end assurance
