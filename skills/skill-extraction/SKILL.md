---
name: skill-extraction
description: "Analyze an external resource (link, repo, doc, tool) and extract relevant capabilities to integrate into the harness. Aggressively gates value — most candidates get rejected. Always proposes before implementing."
risk: safe
source: local
---

# Skill Extraction

Analyze an external resource and intelligently integrate its capabilities into the harness — as skills, hooks, scripts, commands, routines, or config changes — with user approval at every step.

**The default answer is skip.** Only propose something if it genuinely fills a gap the harness cannot already cover and earns its maintenance cost. A lean harness beats a bloated one. It is correct and expected for most candidates to be rejected.

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
5. **Dashboard** — read `~/.claude/sdd-harness/.dashboard/` to understand what widgets/panels already exist and what data they surface

The goal: understand gaps the resource could fill, identify what already exists and could be augmented instead of duplicated, and avoid adding anything that merely adds noise.

### Phase 3: Gap Analysis & Integration Mapping

Map the resource's capabilities to integration types, then ruthlessly filter them.

#### Step 3a: Integration Type Mapping

| Integration Type | Output path | When to use |
|---|---|---|
| **Augmentation** | Existing file (skill, hook, script, or dashboard widget) | Adding capability to an existing artifact — **ALWAYS preferred over creating new** |
| **Skill** | `~/.claude/skills/<name>/SKILL.md` | Reusable workflow, decision tree, domain knowledge Claude applies when asked |
| **Hook** | `~/.claude/hooks/<name>.sh` + settings.json | Automated behavior on Claude events (PreToolUse, PostToolUse, Stop, SessionStart) |
| **Script** | `~/.claude/scripts/<name>.sh` | Utility automation run directly — no Claude-specific integration needed |
| **Command** | `~/.claude/commands/<name>.md` | User-invokable `/slash-command` with arguments and an interactive workflow |
| **Routine** | `~/.claude/commands/<name>.md` + cron note | Recurring/scheduled operation (nightly maintenance, monitoring, reports) |
| **Config Change** | `~/.claude/settings.json` or `.claude/settings.json` | Settings, env vars, permissions, or MCP server entries |
| **Dashboard widget** | `~/.claude/sdd-harness/.dashboard/` | New panel or metric visible in the harness dashboard |

A single resource can map to multiple integration types. Before creating anything new, check whether the capability belongs in an existing artifact.

**Plan skill sequencing up front for compound tasks.** When a task will clearly need multiple skills, decide the full ordered skill plan — which skills, how many, and in what order — in a single reasoning pass, rather than invoking skills reactively one at a time and re-deciding after each. Deciding subset, count, and order together outperforms incremental retrieval (Generative Skill Composition, arXiv 2606.32025); the paper's constrained-decoding mechanism doesn't port to a prompting-only harness, but the principle — commit to the plan before executing it — does.

#### Step 3b: Hook Candidate Assessment (Mandatory)

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

#### Step 3c: Dashboard Assessment (Mandatory)

For every proposed item, ask:

- Does this produce **persistent output** (metrics, status, reports) a user would want to see across sessions? → Consider a dashboard widget or updating an existing one
- Does an **existing dashboard widget** already track something adjacent? → Augment it instead of creating a new panel
- Is this behavior already surfaced somewhere on the dashboard? → Skip the dashboard angle entirely

Only propose a dashboard change if the answer is clearly yes and no existing widget covers it.

#### Step 3d: Automation Assessment (Mandatory for every candidate)

For **every** candidate that survives initial filtering, explicitly answer:

> *"Can this be automated so the user never has to remember to invoke it?"*

| Verdict | Meaning | Action |
|---|---|---|
| **Auto — hook** | Fires on a Claude Code lifecycle event | Wire as a hook; skill (if any) becomes its logic |
| **Auto — routine** | Should run on a schedule (daily/weekly) | Wire into `daily-orchestrator.sh` with a cadence guard |
| **Auto — both** | Needs event trigger AND scheduled check | Propose both hook and routine |
| **Not automatable — user-invoked** | Genuinely requires user judgment to trigger | Skill or command only; document WHY it can't be automated |
| **Not automatable — contextual** | Only makes sense when user is actively working on something specific | Skill only, pulled when relevant |

The goal of the harness is to be self-sustaining. A skill the user must remember to invoke is a half-measure. If something can be automated, automate it. Only leave it as a user-invoked skill when automation would be wrong or dangerous.

#### Step 3e: Value Critic Gate (Mandatory — run before building the proposal)

Before including any candidate in the proposal, apply the harness critic test. For each candidate, answer:

1. **Already covered?** Does any existing skill, hook, script, or command cover >70% of this capability?
   → If YES, do **not** immediately reject. Invoke `Skill("better-call")` to compare the challenger against the incumbent. Use its verdict to determine the proposal path (see Step 3f below). Never default to rejection just because something already exists — the incumbent isn't automatically better.
2. **Hollow addition?** Does this add new *behavior*, or just new *text* the user could look up elsewhere? → If documentation only, skip.
3. **Maintenance cost justified?** Will the harness be measurably better with this? Or is this a "nice to have" that adds noise? → If uncertain, skip.
4. **Better as augmentation?** Could this be a single added section in an existing artifact rather than its own file? → Augment, don't create.
5. **Automation answer honest?** If the verdict is "not automatable", is that genuinely true — or just harder to wire? → Be honest.

**Only candidates that survive all five checks (or earn passage via a `better-call` verdict) reach the proposal.** A proposal with 1–2 high-value items is better than one with 7 mediocre ones.

#### Step 3f: Translate `better-call` Verdict into Proposal Path

After `better-call` returns its verdict block, map it to a proposal action:

| Verdict | Action |
|---|---|
| **KEEP INCUMBENT** | Reject the candidate. Add to "Rejected Candidates" with the `better-call` score table as evidence. |
| **ADOPT CHALLENGER** | Propose the new capability as a replacement or upgrade to the incumbent. Flag the incumbent for deprecation/removal in the proposal. |
| **AUGMENT INCUMBENT** | Propose targeted augmentation of the existing artifact. List only the specific ideas worth extracting; discard the rest of the challenger. |
| **MERGE** | Propose a unified artifact that supersedes both. Include a plan for removing the old incumbent after the merge lands. |
| **COEXIST** | Propose both as separate items; justify the non-overlap explicitly in the proposal body. |

Include the `better-call` score table and verdict in the proposal (for any verdict other than KEEP INCUMBENT) or in the "Rejected Candidates" section (for KEEP INCUMBENT). The user should be able to see exactly how the comparison was made.

### Phase 4: Proposal (REQUIRED — always show before implementing)

Present the full integration plan to the user. Format:

```
## Extraction Proposal: [Resource Name]

**Source:** [URL]
**Summary:** [1-2 sentence description of what the resource does]

---

### Proposed Integrations

#### 1. [Name] — [Type: Augmentation / Skill / Hook / Script / Command / Routine / Dashboard widget / Config]
**What:** [What this integration does]
**Why this adds value:** [The specific gap it fills — what currently fails or is missing without it]
**Automation path:** [hook event / routine cadence / not automatable + honest reason]
**Dashboard impact:** [Which existing widget is affected, or "none"]
**Implementation:** [What will be created or modified]
**Files:** [Paths of files to create or modify]

#### 2. [Name] — [Type]
...

---

### Rejected Candidates
[Every candidate considered but not proposed. For each: what it was, why it was rejected (already covered / hollow / low value / better as augmentation / maintenance cost not justified). This section is REQUIRED — an empty list means the critic gate did not run.]

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

**For Augmentations:**
- Read the existing artifact first (`ctx_read`). Make the smallest edit that adds the new capability. Do not restructure the existing file.
- If augmenting a skill, re-run the SkillOS Quality Gate (Phase 5b) on the modified skill.

**For Dashboard widgets:**
- Read `~/.claude/sdd-harness/.dashboard/` structure first to understand the existing widget contract.
- Augment an existing widget if the data fits. Create a new one only if no existing widget is a logical home for it.

After creating source artifacts, remind the user to run `bash ~/.claude/sdd-harness/update.sh` to roll them out to all registered repos (or `update.sh <repo>` for one).

### Phase 5b: SkillOS Quality Gate (for new and augmented skills)

Before marking any new skill complete, score it against four quality dimensions:

| Dimension | Check |
|---|---|
| **Task relevance** | Does this skill address a real, repeated task in this user's context — not hypothetical? |
| **Operational validity** | Are all steps executable using Claude Code's actual tools? No dead references? |
| **Content quality** | Clear frontmatter, named workflow phases, actionable steps — not just narration?<br>• Name in gerund form (e.g. `processing-pdfs`, not `pdf-tools`)<br>• Description in third person ("Processes X"/"Does Y") — never first/second person<br>• Reference files stay one level deep — no reference file links to another reference file<br>• Eval-driven: ≥3 evaluation scenarios + a no-skill baseline established before the docs were finalized |
| **Compression** | SKILL.md ≤5,000 words, description ≤200 chars, verbose content in `resources/`?<br>• Any reference file over 100 lines has a table of contents |

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

### Phase 5d: Verification Companion Check (for new skills only)

After Phase 5c passes, determine whether the new skill's domain has manual checks that should be encoded:

Ask: **"Does this domain involve manual checks a human would run after Claude's work?"**

Examples that warrant a companion verify skill:
- Visual inspection (UI, reports, generated docs)
- Running a service and checking behavior
- Sampling output for correctness or plausibility
- Checking logs, error output, or side effects

If YES → invoke `Skill("verification-skill-authoring")` to create a companion `<domain>-verify` skill before proceeding to Phase 6.

If NO (pure logic, already covered by CI, or the skill itself IS a verification skill) → skip and proceed.

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

- **The default answer is skip.** A proposal with 1–2 high-value items is better than one with 7 mediocre ones. Err toward rejection.
- **Augment before creating.** If an existing skill, hook, script, or dashboard widget can absorb this capability in a single added section, augment it. Never create a parallel artifact.
- **Automate or justify why not.** Every candidate must have an explicit automation verdict (hook / routine / not automatable + reason). A skill the user must remember to invoke is a half-measure.
- **Dashboard is part of the surface area.** If something produces persistent output or status, ask whether the dashboard should surface it — and whether an existing widget already does.
- **Never implement without approval.** The proposal step is mandatory, not optional.
- **Match harness conventions.** Read nearby files before creating new ones to follow existing patterns.
- **One resource can yield multiple integration types.** A repo might give a skill, a hook, and a command.
- **Rejected Candidates section is required.** An empty list means the critic gate did not run — go back to Step 3e.
- **Always log to the sources index first.** Phase 6 must be completed before the Phase 7 summary is shown — provenance is part of the deliverable, not optional metadata.
