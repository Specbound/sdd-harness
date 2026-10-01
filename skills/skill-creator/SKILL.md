---
name: skill-creator
description: "Create a new Claude Code skill from scratch following harness conventions. Covers brainstorming, file generation, SkillOS quality validation, and installation. Use when building a custom skill with no external source."
version: 1.3.0
risk: safe
source: community
---

# skill-creator

## Purpose

Guide the creation of new Claude Code skills end-to-end: collaborative brainstorming, file generation, quality validation, and installation into the two-tier skill hierarchy (`docs/skills/SKILL-HIERARCHY.md` — Library by default, registered under a domain master).

## When to Use This Skill

- User wants to create a skill from scratch (no external source — for extracting from an external resource, use `skill-extraction` instead)
- User wants to package a repeated workflow or domain pattern into a reusable skill
- User wants to extend Claude Code with a named, invokable capability

## Workflow

### Phase 1: Brainstorming & Planning

Ask the user:

1. **What should this skill do?** (Free-form description)
2. **When should it trigger?** List 3–5 trigger phrases / scenarios.
3. **What type is it?**
   - General-purpose workflow
   - Code generation/modification
   - Documentation creation
   - Analysis/investigation
   - Automation/integration
4. **One-sentence description** for the frontmatter (will be shown in skill lists — keep under 200 chars)

Capture responses before moving on.

**Size the skill before writing it** — pick the lightest tier that fits, to avoid over-building:
| Tier | Shape | When |
|---|---|---|
| Simple | Single `SKILL.md`, <200 lines | One technique, one trigger, no bundled files |
| Expanded | `SKILL.md` + a few `resources/` files | Multiple related concepts, 200-1000 lines total |
| Platform | `SKILL.md` dispatcher + many reference files | 10+ sub-areas that genuinely don't fit in one file |

Most skills should be Simple or Expanded — reach for Platform only when the domain is
actually that large.

### Phase 2: Prompt Enhancement (Optional)

Ask: "Would you like to refine the skill description using the `prompt-engineering` skill before generating files?"

- If yes: invoke `Skill("prompt-engineering")` with the current description as input, review the enhanced output with the user, and confirm before adopting it.
- If no or skill unavailable: proceed with original input.

### Phase 3: File Generation

Determine the skill name in kebab-case from the user's input.

Create the directory structure:
```
~/.claude/skills/<skill-name>/
├── SKILL.md          ← primary skill file (required)
└── resources/        ← extended docs/templates (create if needed)
```

Generate `SKILL.md` using this structure:

```markdown
---
name: <skill-name>
description: "<one-sentence description, ≤200 chars>"
risk: safe|unknown|caution
source: local
---

# <Skill Title>

## When to Use This Skill
[Trigger scenarios and prerequisites — concrete, not vague]

## Instructions

### Phase 1: [First Phase Name]
[Steps...]

### Phase 2: [Second Phase Name]
[Steps...]

## Success Criteria
[How to know the skill was applied correctly]

## Inputs and Outputs
[What the skill expects; what it produces]

## Safety
[Risk considerations, what NOT to do]

## Related Skills
[Links to other skills in the ecosystem]
```

**Writing rules:**
- Imperative / infinitive style ("Read the file", not "You should read the file")
- Named workflow phases, not unstructured running text
- Concrete steps, not descriptions of what steps would look like
- Keep SKILL.md under 2,000 words (ideal) / 5,000 words (maximum)
- Move anything longer (examples, templates, reference tables) into `resources/`
- Reference files stay **one level deep**: SKILL.md may link to a file in `resources/`, but that file must not link to further nested reference files — a reference chain invites partial `head -100` reads that miss content
- Any reference file over 100 lines gets a table of contents near the top
- Description reads as "Use when X" (trigger-first), never a workflow summary — it's the
  only thing the agent sees before deciding whether to load the skill, so it must predict
  WHEN to fire, not just describe what the skill contains
- Don't bundle `README.md`, `CHANGELOG.md`, or installation guides into the skill dir —
  agents don't need meta-docs, only `scripts/` (deterministic/repeated code),
  `references/` (detail loaded on demand), and `assets/` (output templates/boilerplate)
- No `@` force-loading inside cross-references between skills — it defeats progressive
  disclosure by pulling full content in regardless of whether it's needed

### Phase 4: Validation

After generating the file, run these checks:

**Structural checks:**
- Frontmatter present and valid YAML
- `name`, `description`, `risk` fields populated
- `name:` is kebab-case and matches the directory name under `~/.claude/skills/`
- `name:` uses gerund form (e.g. `processing-pdfs`, not `pdf-tools`)
- Description ≥ 25 characters and does not start with a vague phrase (`a skill that`, `this skill`, `skill for`, `use this skill`, `provides`)
- Description ≤ 200 characters
- At least one named workflow phase

**Content checks:**
- No second-person ("you should", "you can") — use imperative
- Description is third-person ("Processes X", "Validates Y") — never first-person ("I can help with...") or second-person ("You can use this to...")
- No vague trigger ("use when helpful") — triggers must be specific
- No dead tool references (verify any `Skill(...)` calls exist in the available skill list); MCP tool references use fully-qualified naming (`ServerName:tool_name`) to avoid ambiguous lookups

**Note:** When writing to `~/.claude/skills/<name>/SKILL.md`, the `skill-validate-hook.sh` PreToolUse hook will run automatically. Fix any errors it reports before the write proceeds — a hard block (exit 2) means the frontmatter must be corrected first.

### Phase 4b: SkillOS Quality Gate

Score the skill against four dimensions before installation:

| Dimension | Check |
|---|---|
| **Task relevance** | Addresses a real, repeated task — not a hypothetical? Would invoking it improve task success? |
| **Operational validity** | All steps executable with Claude Code's actual tools (Bash, Read, Edit, Write, WebFetch)? No phantom tool calls? |
| **Content quality** | Clear frontmatter, named phases, actionable steps — not just descriptive narration? |
| **Compression** | SKILL.md ≤ 5,000 words, description ≤ 200 chars, verbose content in `resources/`? |

Fix any failures before installation:
- Fails task relevance → narrow or reconsider the skill's scope
- Fails operational validity → fix broken tool references
- Fails content quality → add named phases and concrete steps
- Fails compression → move appendices to `resources/` and replace with a pointer

**Compression heuristic:** Skill content should be ≤ 30% of the context needed to do the task manually. A skill longer than that without proportional value is net-negative.

**Eval-driven development:** Before finalizing the skill's docs, invoke `Skill("skill-eval-gate")` to define ≥3 evaluation scenarios, run a no-skill baseline against the treatment, and gate on a measured pass-rate lift — self-assessed confidence is not sufficient (SkillsBench, arXiv 2602.12670: self-authored skills scored 1.3pts *below* no-skill baseline). Iterate the instructions against the gate's verdict rather than shipping the first draft untested.

**Per-tier testing:** Verify the skill works across Haiku/Sonnet/Opus, with tier-appropriate pass criteria — passing on one tier alone does not clear this gate.

**Script constants:** Any bundled script must justify every constant, timeout, or magic number inline ("solve, don't defer") rather than leaving it unexplained.

### Phase 4c: Identity Alignment Check

Invoke `Skill("agent-identity")` in **Mode B (skill identity check)** to validate the new skill's identity sharpness:

1. **Description specificity** — Does the description predict WHEN the skill fires — not just what it does?
2. **Trigger sharpness** — Are `When to Activate` conditions falsifiable by two independent readers?
3. **Behavioral concreteness** — Are the skill's instructions concrete steps, or descriptions of what steps would look like?
4. **Explicit exclusions** — Does the skill state what it does NOT do?

Fix any failures before installation. One sentence per fix is sufficient.

### Phase 4d: Verification Companion Check

After Phase 4c passes, determine whether this skill's domain has manual checks that should be encoded:

Ask: **"Does this domain involve manual checks a human would run after Claude's work?"**

Examples that warrant a companion verify skill:
- Visual inspection (UI, reports, generated docs)
- Running a service and checking behavior
- Sampling output for correctness or plausibility
- Checking logs, error output, or side effects

If YES → invoke `Skill("verification-skill-authoring")` to create a companion `<domain>-verify` skill before installation.

If NO (pure logic, already covered by CI, or the skill itself IS a verification skill) → skip and proceed.

### Phase 5: Installation (two-tier hierarchy)

Skills install into one of two tiers — see `docs/skills/SKILL-HIERARCHY.md` for the full
rules. **Default a new skill to the Library tier** so it costs no per-prompt context; only
pin it to the Listed tier if a hook/command will load it by name via `Skill("<name>")`.

1. Write the skill to the repo source: `skills/<skill-name>/SKILL.md` (both tiers live here).
2. Register it under a master (Library default):
   - Pick the owning domain from the 14 masters (`backend-dev`, `frontend-dev`, `languages`,
     `data-and-db`, `ai-ml-agents`, `devops-infra`, `observability-incident`, `security`,
     `code-quality`, `cloud-sdks`, `product-growth`, `integrations`, `docs-knowledge`,
     `harness-meta`).
   - Add one row to `skills/<master>/SKILL.md`'s table:
     `` | `<skill-name>` | <one-line what + when> | `~/.claude/skill-library/<skill-name>/SKILL.md` | ``
   - Add `<skill-name>` on its own line to `scripts/setup/skill-library.txt`.
3. Install: `bash scripts/setup/sync-skills.sh "$PWD"` (routes by the manifest).

Confirm it landed in the Library:
```bash
ls ~/.claude/skill-library/<skill-name>/
```

**Pin to Listed instead** (skip the manifest step, so it installs to `~/.claude/skills/`)
ONLY when a hook or command hard-invokes it via `Skill("<name>")`. Keep the Listed set small.
Anything that merely *references* a Library skill should `Read ~/.claude/skill-library/<name>/SKILL.md`,
never `Skill("<name>")`.

### Phase 6: Completion

Show a summary:

```
Skill created successfully.

  Name:     <skill-name>
  Location: ~/.claude/skill-library/<skill-name>/SKILL.md   (Library tier)
  Master:   <owning-master>  (row added to its router table)
  Words:    <word count>

Files:
  ✅ SKILL.md
  ✅ resources/ (if created)

Next steps:
  1. Test it: open the <owning-master> skill, confirm the new row routes to it
  2. Add examples or templates to resources/ if useful
  3. If it references other skills, verify those exist
```

## Key Principles

- **Named phases over prose.** A skill with "Phase 1: X, Phase 2: Y" is far more usable than a paragraph description.
- **Concrete over general.** "Read `~/.claude/settings.json`" beats "read the settings file."
- **Compression matters.** A bloated skill degrades context faster than it helps. Keep it tight.
- **One skill, one job.** If the skill is doing two unrelated things, split it.
- **Module cap (≤3).** A skill package should bundle at most 3 modules/components (scripts, templates, reference docs); beyond that, split it — focused skills with ≤3 modules outperform larger bundles (SkillsBench, arXiv 2602.12670).
- **Check for existing skills first.** Before creating, scan `~/.claude/skills/` — extending beats duplicating.
