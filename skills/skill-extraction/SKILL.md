---
name: skill-extraction
description: "Analyze an external resource (link, repo, doc, tool) and extract relevant capabilities to integrate into the harness as skills, hooks, scripts, commands, routines, or config changes. Always proposes before implementing."
risk: safe
source: local
---

# Skill Extraction

Analyze an external resource and intelligently integrate its capabilities into the harness — as skills, hooks, scripts, commands, routines, or config changes — with user approval at every step.

## Use this skill when

- User provides a link, repo URL, or doc and wants to see what's useful for the harness
- User says "extract from this", "what can we get from this repo", "integrate this into the harness"
- User shares a tool, library, or framework and wants it adapted into the harness
- User wants to convert an external pattern into a hook, skill, command, or harness feature

## Do not use this skill when

- The user wants to create a skill from scratch with no external source
- The task is unrelated to the harness

## Workflow

### Phase 1: Fetch & Understand the Resource

Use WebFetch or WebSearch to retrieve the content at the provided link. Focus on:
- README, docs, and primary entrypoints
- Key features, behaviors, and patterns it provides
- What problem it solves / what it automates

If the link is a GitHub repo, also check:
- `package.json` / `pyproject.toml` / config files for capabilities
- Any hooks, CLI commands, or automation scripts

### Phase 2: Audit the Harness

Before proposing anything, understand what the harness already has. Read in parallel:

1. **Existing skills** — scan `~/.claude/skills/` for related skills to avoid duplication
2. **Hooks** — read `~/.claude/settings.json` and `.claude/settings.json` for existing hooks
3. **Harness docs** — check `~/.claude/sdd-harness/docs/` and `CLAUDE.md` for architecture context
4. **Memory** — check `~/.claude/projects/*/memory/MEMORY.md` for relevant project context

The goal: understand gaps the resource could fill, and avoid re-implementing what already exists.

### Phase 3: Gap Analysis & Integration Mapping

Map the resource's capabilities to integration types:

| Integration Type | Output path | When to use |
|---|---|---|
| **Skill** | `~/.claude/skills/<name>/SKILL.md` | Reusable workflow, decision tree, domain knowledge Claude applies when asked |
| **Hook** | `~/.claude/hooks/<name>.sh` + settings.json | Automated behavior on Claude events (PreToolUse, PostToolUse, Stop, SessionStart) |
| **Script** | `~/.claude/scripts/<name>.sh` | Utility automation run directly — no Claude-specific integration needed |
| **Command** | `~/.claude/commands/<name>.md` | User-invokable `/slash-command` with arguments and an interactive workflow |
| **Routine** | `~/.claude/commands/<name>.md` + cron note | Recurring/scheduled operation (nightly maintenance, monitoring, reports) |
| **Config Change** | `~/.claude/settings.json` or `.claude/settings.json` | Settings, env vars, permissions, or MCP server entries |

A single resource can map to multiple integration types.

#### Hook Candidate Assessment (Mandatory)

Before finalizing the integration map, evaluate each capability against the four hook signals:

1. Must it run **every time** the trigger fires — not just when Claude decides to?
2. Does it describe **enforcement** — block, log, validate, always, never?
3. Is it **lifecycle-aware** — on-session-start, on-finish, on-tool-use?
4. Would a **prompt or skill fail** to enforce it reliably?

If yes to any → add a Hook entry to the proposal.

For hooks, also determine:
- **Event**: `SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`, `UserPromptSubmit`
- **Strength**: soft gate (outputs a warning, Claude decides) vs. hard block (exits non-zero to prevent tool execution)
- **Matcher**: which tool name to match for PreToolUse/PostToolUse, or blank for all

### Phase 4: Proposal (REQUIRED — always show before implementing)

Present the full integration plan to the user. Format:

```
## Extraction Proposal: [Resource Name]

**Source:** [URL]
**Summary:** [1-2 sentence description of what the resource does]

---

### Proposed Integrations

#### 1. [Name] — [Type: Skill / Hook / Script / Command / Routine / Config]
**What:** [What this integration does]
**Why:** [Why this fits the harness / gap it fills]
**Implementation:** [What will be created/changed]
**Files:** [Paths of files to create or modify]

#### 2. [Name] — [Type]
...

---

### Skipped / Not Applicable
[List anything from the resource that was considered but not proposed, and why]

---

**Approve all? Or specify which to implement (e.g. "1 and 3", "skip 2", "change #1 to a hook instead"):**
```

**Wait for user response before proceeding.**

### Phase 5: Implement Approved Items

After approval, implement each approved item:

**For Skills:**
- Create `~/.claude/skills/<name>/SKILL.md` following the standard skill format (frontmatter + named workflow phases)
- Keep SKILL.md focused; move extended reference content to a `resources/` subfolder

**For Hooks:**
- Write `~/.claude/hooks/<name>.sh` as a standalone bash script
- Include a `# REGISTRATION` comment block at the end of the file with the exact settings.json JSON to add
- Use the `update-config` skill to write the settings.json entry after confirming with the user

**For Scripts:**
- Write `~/.claude/scripts/<name>.sh` (or `.py` if Python fits better)
- Include a usage comment at the top; handle missing arguments gracefully

**For Commands:**
- Write `~/.claude/commands/<name>.md` with frontmatter (`description`, `allowed-tools`, `argument-hint`)
- Body: structured instructions Claude follows when the command is invoked

**For Routines:**
- Same as Command format, plus append a `## Suggested Schedule` section with a cron expression
- Note that the user can register it with `/schedule`

**For Config Changes:**
- Use the `update-config` skill to apply settings.json modifications
- Always show the exact JSON diff before writing

### Phase 5b: SkillOS Quality Gate (for new skills only)

Before marking any new skill complete, score it against four quality dimensions:

| Dimension | Check |
|---|---|
| **Task relevance** | Does this skill address a real, repeated task in this user's context — not hypothetical? |
| **Operational validity** | Are all steps executable using Claude Code's actual tools? No dead references? |
| **Content quality** | Clear frontmatter, named workflow phases, actionable steps — not just narration? |
| **Compression** | SKILL.md ≤5,000 words, description ≤200 chars, verbose content in `resources/`? |

If any dimension fails, fix before proceeding:
- Fails task relevance → reconsider whether this is worth extracting at all
- Fails operational validity → fix broken tool references or dead links
- Fails content quality → add workflow phases and concrete steps
- Fails compression → move verbose appendices to `resources/` and replace with a short pointer

### Phase 6: Confirm & Summarize

After implementing, show:

```
## Extraction Complete

✅ [Name] — [Type] → [file path]
✅ [Name] — [Type] → [file path]
⏭️  [Name] — skipped per your instruction

**Test it:** [How to invoke/verify the new integration]
```

## Key Principles

- **Never implement without approval.** The proposal step is mandatory, not optional.
- **Prefer augmenting over duplicating.** If a similar skill exists, propose extending it rather than creating a parallel one.
- **Match harness conventions.** Read nearby files before creating new ones to follow existing patterns.
- **One resource can yield multiple integration types.** A repo might give a skill, a hook, and a command.
- **Be explicit about skips.** Always tell the user what you decided not to extract and why.
