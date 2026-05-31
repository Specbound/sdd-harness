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

### Phase 0: Classify the Input Source

Inspect the input passed to the skill and classify it into exactly one source category. The category determines which `docs/sources/<category>/README.md` will be updated in Phase 7.

| Input shape | Category | Target file |
|---|---|---|
| Plain text (no URL) — a pasted thread, excerpt, or snippet | **x** | `docs/sources/x/README.md` |
| URL matching `github.com/<owner>/<repo>` (or `gitlab.com`, `bitbucket.org`) | **git** | `docs/sources/git/README.md` |
| URL on `arxiv.org`, `aclanthology.org`, `openreview.net`, `nature.com`, `science.org`, `acm.org`, `ieee.org`, or any other scientific journal/preprint server | **papers** | `docs/sources/papers/README.md` |
| Any other URL (blog post, docs page, vendor site, news, etc.) | **articles** | `docs/sources/articles/README.md` |

Decision rules:
- A URL classifies as **git** only if it points to a repository root or repo subpath — a link to a GitHub-hosted blog post (e.g. `*.github.io/post`) is **articles**.
- If a single input contains *both* a paper and its accompanying repo, log to the category of the primary input and cross-reference the other in the entry body (use the pattern `See also: [git/README.md](../git/README.md)` already established in existing entries).
- If you cannot confidently classify, stop and ask the user before continuing.

Record the chosen category — you will need it in Phase 7.

### Phase 1: Fetch & Understand the Resource

Use WebFetch or WebSearch to retrieve the content at the provided link. Focus on:
- README, docs, and primary entrypoints
- Key features, behaviors, and patterns it provides
- What problem it solves / what it automates

If the link is a GitHub repo, also check:
- `package.json` / `pyproject.toml` / config files for capabilities
- Any hooks, CLI commands, or automation scripts

If the input is plain text (category **x**), skip fetching — the content is the input itself. Summarize it in your own words for the subsequent phases.

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

After approval, implement each approved item.

**Write to HARNESS SOURCE, not the installed copies.** Anything created here must propagate to every machine and every repo via `install.sh`/`update.sh`. Those installers copy *from the harness source tree* (`~/.claude/sdd-harness/` — a symlink to the harness repo), not from the live `~/.claude/` install. So author each artifact in the source tree below, then sync once for immediate use this session. Never create a harness artifact only in `~/.claude/skills`, `~/.claude/commands`, or a single project's `.claude/` — it will be invisible to other repos and lost on the next update.

`HARNESS="$HOME/.claude/sdd-harness"` (resolve once; it symlinks to the repo).

**For Skills:**
- Create `$HARNESS/skills/<name>/SKILL.md` (frontmatter + named workflow phases). The installer loops `skills/*/` → `~/.claude/skills/`, so it becomes globally available on the next install/update.
- For immediate use this session: `cp -r $HARNESS/skills/<name> ~/.claude/skills/`.
- Keep SKILL.md focused; move extended reference content to a `resources/` subfolder.

**For Hooks:**
- Write `$HARNESS/hooks/<name>.sh` as a standalone bash script. install.sh/update.sh copy harness hooks into each project's `.claude/hooks/` and chmod them — add the new hook to those copy+chmod lists so it propagates.
- Include a `# REGISTRATION` comment block at the end of the file with the exact settings.json JSON to add. Register it in `templates/settings.json.template` (shipped to projects) so the hook is wired everywhere, not just locally.
- Use the `update-config` skill to write the local settings.json entry after confirming with the user.

**For Scripts:**
- Write `$HARNESS/scripts/<name>.sh` (or `.py`). The whole `scripts/` dir is synced into every project's `.claude/scripts/`, so this propagates automatically. If it must be executable, add a `chmod +x` line for it to both install.sh and update.sh (next to the `daily-runner.sh`/`macro-eval-runner.sh` ones).
- Include a usage comment at the top; handle missing arguments gracefully.

**For Commands:**
- Project-scoped (`/kiro:<name>`): write `$HARNESS/commands/kiro/<name>.md` — copied into every project's `.claude/commands/`.
- User-global (`/<name>`): write `$HARNESS/commands/global/<name>.md` — copied into `~/.claude/commands/`.
- Frontmatter (`description`, `allowed-tools`, `argument-hint`); body = structured instructions Claude follows when invoked.

**For Routines:**
- A scheduled routine = a `commands/kiro/<name>.md` pipeline + a `scripts/<name>-runner.sh` (headless `claude --print` driver, with an idempotency/cadence guard) + a wiring call in `scripts/daily-orchestrator.sh` `run_one()` (the existing per-repo daily loop). Self-pace via a `MIN_GAP_DAYS` guard so daily calls are cheap no-ops; gate with an `SDD_SKIP_<NAME>=1` opt-out. This reuses the one OS scheduler — do NOT add a second cron/launchd job unless the cadence genuinely can't ride the daily tick. See `scripts/macro-eval-runner.sh` + the orchestrator as the reference implementation.
- Add `chmod +x` for the runner to install.sh and update.sh, and self-sync it into `$HARNESS/.claude/scripts/` in update.sh's tail block.

**For Config Changes:**
- Use the `update-config` skill to apply local settings.json modifications, and mirror durable changes into `templates/settings.json.template` so they ship to every project.
- Always show the exact JSON diff before writing.

After creating source artifacts, remind the user to run `bash ~/.claude/sdd-harness/update.sh` to roll them out to all registered repos (or `update.sh <repo>` for one).

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

### Phase 5c: Identity Alignment Check (for all new skills)

After the SkillOS Quality Gate passes, invoke `Skill("agent-identity")` in **Mode B (skill identity check)**. This validates the new skill's identity sharpness against four dimensions:

1. **Description specificity** — Does the description predict WHEN the skill fires?
2. **Trigger sharpness** — Are `When to Activate` conditions falsifiable?
3. **Behavioral concreteness** — Are instructions concrete, not descriptive?
4. **Explicit exclusions** — Does the skill say what it does NOT do?

Fix any failures before logging to the sources index. Do not skip this step — vague skill identities accumulate into a harness where the wrong skill fires half the time.

### Phase 6: Log to the Sources Index (DO THIS BEFORE SHOWING THE SUMMARY)

Before printing any completion message, append an entry to the source-category README chosen in Phase 0. **Do not skip to the summary — write the file first, then report.** Without this step the harness loses the provenance trail that explains why skills were added.

**Target file:** `docs/sources/<category>/README.md` where `<category>` is one of `articles`, `git`, `papers`, `x` (from Phase 0).

**Entry format** — match the style already used in that file. The canonical template:

```markdown
---

## [Title — repo name, article title, paper title, or short label for pasted text]
**URL:** <source URL>   *(omit for category `x`)*
**Added:** YYYY-MM-DD   *(today's date in absolute form)*
**Source / Author:** <optional — publisher, author, or "Pasted text">

**What it's about:** [1–3 sentences — what the source covers, the problem it solves, key claims or data]

**What we added:**
- [Integration type]: `<name>` — [one-line description of why this fits the harness / the gap it fills]
- [Repeat for each integration created in Phase 5]
```

Field rules:
- For category **x**, omit the `**URL:**` line and use a short descriptive title plus the date.
- For category **papers**, prefer `**arXiv:**` over `**URL:**` when applicable; include `**Year:**` and `**Authors:**` if known.
- If the extraction added nothing (proposal rejected, nothing applicable), do **not** write an entry and skip Phase 6 entirely.
- If a related entry exists in another sources file (e.g. paper + accompanying repo), add a `See also: [<other-category>/README.md](../<other-category>/README.md)` line inside the entry.

Append the entry at the bottom of the file, separated by `---` from the previous entry, preserving chronological order (oldest first).

### Phase 7: Confirm & Summarize

After writing the sources index entry, show:

```
## Extraction Complete

✅ [Name] — [Type] → [file path]
✅ [Name] — [Type] → [file path]
⏭️  [Name] — skipped per your instruction

📝 Logged to docs/sources/<category>/README.md

**Test it:** [How to invoke/verify the new integration]
```

The `📝 Logged` line is required. If Phase 6 was skipped (nothing extracted), replace it with `⏭️ Sources index not updated (nothing extracted).`

## Key Principles

- **Never implement without approval.** The proposal step is mandatory, not optional.
- **Prefer augmenting over duplicating.** If a similar skill exists, propose extending it rather than creating a parallel one.
- **Match harness conventions.** Read nearby files before creating new ones to follow existing patterns.
- **One resource can yield multiple integration types.** A repo might give a skill, a hook, and a command.
- **Be explicit about skips.** Always tell the user what you decided not to extract and why.
- **Always log to the sources index first.** Phase 6 must be completed before the Phase 7 summary is shown — provenance is part of the deliverable, not optional metadata.
