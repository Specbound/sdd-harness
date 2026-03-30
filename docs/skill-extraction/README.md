# Skill Extraction from Repositories

Extract reusable procedural knowledge ("skills") from code repositories and convert them into standardized SKILL.md files for the Claude Code skill ecosystem.

Based on the methodology from [Automating Skill Acquisition through Large-Scale Mining of Open-Source Agentic Repositories](https://arxiv.org/abs/2603.11808).

---

## How It Works

The extraction follows a three-stage pipeline:

### Stage 1: Repository Structural Analysis
- Maps directory structure (entry points, core logic, config, docs, tests)
- Classifies repo type (library, framework, CLI, web app, ML project, agent system)
- Reads key documentation and dependency manifests

### Stage 2: Semantic Skill Identification
- Identifies candidate modules encoding reusable knowledge
- Scores each against a 4-criteria rubric (Recurrence, Code Quality, Domain Expertise, Generalizability)
- Cross-references existing `~/.claude/skills/` to avoid duplicates
- Produces a ranked extraction plan for human review

### Stage 3: SKILL.md Generation
- Deep-reads each approved candidate's source code
- Maps knowledge to the skill tuple: (Applicability Conditions, Policy, Termination Criteria, Interface)
- Generates standardized SKILL.md files with proper frontmatter and sections
- Creates `references/` subdirectories for large assets

---

## Commands

### `/kiro:skill-extract-scan <repo>` — Analyze and plan

Scans a repository and produces an extraction plan for review.

```
/kiro:skill-extract-scan https://github.com/org/repo
/kiro:skill-extract-scan /path/to/local/repo
/kiro:skill-extract-scan org/repo
```

Output: `.claude/skill-extraction/<repo-name>/plan.md`

### `/kiro:skill-extract <plan-or-repo>` — Generate skills

Generates SKILL.md files from an approved plan, or runs the full pipeline.

```
# From a reviewed plan:
/kiro:skill-extract .claude/skill-extraction/my-repo/plan.md

# Full pipeline (no review gate):
/kiro:skill-extract https://github.com/org/repo -y
/kiro:skill-extract /path/to/local/repo -y
```

Output: `~/.claude/skills/<skill-name>/SKILL.md` for each extracted skill.

---

## Scoring Rubric

Each candidate is scored on 4 criteria (0-3 scale, max 12):

| Criterion | What it measures |
|-----------|-----------------|
| Recurrence | How universally reusable is this pattern? |
| Code Quality | Is it well-structured, documented, tested? |
| Domain Expertise | Does it encode non-obvious specialist knowledge? |
| Generalizability | Can it apply beyond this specific repo? |

**Threshold**: Score >= 6 to include, >= 9 is high priority.

**Modifiers**: -2 for existing skill overlap, +1 for good docs, +1 for test coverage, -1 for heavy coupling.

Full rubric: `.claude/kiro/settings/rules/skill-extraction-scoring.md`

---

## Typical Workflow

```
1. /kiro:skill-extract-scan https://github.com/interesting/repo
2. Review .claude/skill-extraction/repo/plan.md
   - Remove candidates you don't want
   - Adjust scores or rationale if needed
3. /kiro:skill-extract .claude/skill-extraction/repo/plan.md
4. Verify: read a generated SKILL.md, test trigger keywords
```

For trusted repos or quick extraction:
```
/kiro:skill-extract https://github.com/org/repo -y
```

---

## Generated Skill Format

Each extracted skill follows the standard SKILL.md format:

```yaml
---
name: skill-name
description: "Concise description with trigger keywords"
risk: safe|unknown|caution
source: https://github.com/org/repo
---
```

Sections:
- **When to Use This Skill** — Trigger scenarios and prerequisites
- **Instructions** — Core procedural knowledge (the workflow)
- **Success Criteria** — How to verify correct application
- **Inputs and Outputs** — What the skill expects and produces
- **Safety** — Risk considerations and common pitfalls
- **Related Skills** — Connections to existing ecosystem skills

---

## Security

- Source repos are cloned with `--depth 1` (shallow) to a temp directory
- Analysis is read-only — no code from the source repo is executed
- Scripts are not copied verbatim — knowledge is extracted and regenerated
- All skills default to `risk: unknown` unless purely informational
- Source provenance is recorded in every skill's frontmatter
