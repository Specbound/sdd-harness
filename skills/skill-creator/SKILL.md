---
name: skill-creator
description: "Create a new Claude Code skill from scratch following harness conventions. Covers brainstorming, file generation, SkillOS quality validation, and installation. Use when building a custom skill with no external source."
version: 1.3.0
risk: safe
source: community
---

# skill-creator

## Purpose

Guide the creation of new Claude Code skills end-to-end: collaborative brainstorming, file generation, quality validation, and installation into `~/.claude/skills/`.

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
- Named workflow phases, not unstructured prose
- Concrete steps, not descriptions of what steps would look like
- Keep SKILL.md under 2,000 words (ideal) / 5,000 words (maximum)
- Move anything longer (examples, templates, reference tables) into `resources/`

### Phase 4: Validation

After generating the file, run these checks:

**Structural checks:**
- Frontmatter present and valid YAML
- `name`, `description`, `risk` fields populated
- Description ≤ 200 characters
- At least one named workflow phase

**Content checks:**
- No second-person ("you should", "you can") — use imperative
- No vague trigger ("use when helpful") — triggers must be specific
- No dead tool references (verify any `Skill(...)` calls exist in the available skill list)

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

### Phase 5: Installation

The skill is written to `~/.claude/skills/<skill-name>/SKILL.md` directly — no symlinks needed for Claude Code.

Confirm the file was written:
```bash
ls ~/.claude/skills/<skill-name>/
```

If the skill is also useful in a specific project, note that the user can copy or symlink it to `<project>/.claude/skills/<skill-name>/` for project-scoped availability.

### Phase 6: Completion

Show a summary:

```
Skill created successfully.

  Name:     <skill-name>
  Location: ~/.claude/skills/<skill-name>/SKILL.md
  Words:    <word count>

Files:
  ✅ SKILL.md
  ✅ resources/ (if created)

Next steps:
  1. Test it: mention the trigger phrases in a new conversation
  2. Add examples or templates to resources/ if useful
  3. If it references other skills, verify those exist
```

## Key Principles

- **Named phases over prose.** A skill with "Phase 1: X, Phase 2: Y" is far more usable than a paragraph description.
- **Concrete over general.** "Read `~/.claude/settings.json`" beats "read the settings file."
- **Compression matters.** A bloated skill degrades context faster than it helps. Keep it tight.
- **One skill, one job.** If the skill is doing two unrelated things, split it.
- **Check for existing skills first.** Before creating, scan `~/.claude/skills/` — extending beats duplicating.
