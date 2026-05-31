# Skill Extraction from Repositories

Extract reusable knowledge and automation from code repositories and convert them into the right artifact for the Claude Code harness — skills, hooks, scripts, commands, or routines.

Based on the methodology from [Automating Skill Acquisition through Large-Scale Mining of Open-Source Agentic Repositories](https://arxiv.org/abs/2603.11808).

All resources used in extractions are logged by type:
- [`docs/papers/`](../papers/README.md) — scientific papers (arXiv)
- [`docs/git/`](../git/README.md) — GitHub repositories
- [`docs/articles/`](../articles/README.md) — online articles and blog posts
- [`docs/x/`](../x/README.md) — pasted text

---

## How It Works

The extraction follows a three-stage pipeline:

### Stage 1: Repository Structural Analysis
- Maps directory structure (entry points, core logic, config, docs, tests)
- Classifies repo type (library, framework, CLI, web app, ML project, agent system)
- Reads key documentation and dependency manifests

### Stage 2: Semantic Identification & Classification
- Identifies candidate modules encoding reusable knowledge or automation
- Scores each against a 4-criteria rubric (Recurrence, Code Quality, Domain Expertise, Generalizability)
- **Harness alignment check** — invokes `agent-harness-design` to map each candidate to the 6-component framework (ℛ/ℳ/𝒞/𝒮/𝒪/𝒢) and flag whether the target component is weak/partial/covered before proposing anything
- **Classifies each candidate into the right artifact type** (skill, hook, script, command, or routine)
- Cross-references existing `~/.claude/skills/` to avoid duplicates; defaults to extend-not-duplicate when coverage is partial
- Produces a ranked extraction plan for human review

### Stage 3: Artifact Generation
- Deep-reads each approved candidate's source code
- Generates the appropriate artifact based on classification:
  - `skill` → `~/.claude/skills/<name>/SKILL.md`
  - `hook` → `~/.claude/hooks/<name>.sh` + registration instructions
  - `script` → `~/.claude/scripts/<name>.sh`
  - `command` → `~/.claude/commands/<name>.md`
  - `routine` → `~/.claude/commands/<name>.md` + suggested cron schedule
- **Phase 5b — SkillOS Quality Gate** (new skills only): scores the skill against 4 dimensions (task relevance, operational validity, content quality, compression) before marking it complete. Failures block installation until fixed.
- **Phase 5c — Identity Alignment Check** (new skills only): invokes `agent-identity` in Mode B to validate description specificity, trigger sharpness, behavioral concreteness, and explicit exclusions. Runs after Phase 5b passes, before the skill is logged to the sources index.

---

## Artifact Types

| Type | Best for |
|------|---------|
| **skill** | Workflow patterns, decision trees, domain knowledge Claude applies when asked |
| **hook** | Auto-firing on Claude Code events (SessionStart, PreToolUse, PostToolUse, Stop) |
| **script** | Utility shell/Python scripts run directly, no Claude integration needed |
| **command** | Interactive `/slash-command` workflows with user arguments |
| **routine** | Recurring/scheduled operations (nightly maintenance, monitoring, reports) |

A single repo can yield candidates of multiple types. One candidate can also produce multiple artifacts if warranted.

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

### `/kiro:skill-extract <plan-or-repo>` — Generate artifacts

Generates artifacts from an approved plan, or runs the full pipeline.

```
# From a reviewed plan:
/kiro:skill-extract .claude/skill-extraction/my-repo/plan.md

# Full pipeline (no review gate):
/kiro:skill-extract https://github.com/org/repo -y
/kiro:skill-extract /path/to/local/repo -y
```

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
   - Check artifact types — adjust if the classification feels wrong
   - Remove candidates you don't want
   - Split a row into two if a candidate warrants multiple artifact types
3. /kiro:skill-extract .claude/skill-extraction/repo/plan.md
4. Verify: read generated artifacts, check hook registration comments
```

For trusted repos or quick extraction:
```
/kiro:skill-extract https://github.com/org/repo -y
```

---

## Security

- Source repos are cloned with `--depth 1` (shallow) to a temp directory
- Analysis is read-only — no code from the source repo is executed
- Scripts are not copied verbatim — knowledge is extracted and regenerated
- All artifacts default to `risk: unknown` unless purely informational
- Source provenance is recorded in every artifact's frontmatter or header

## Extracted Skills Index

Skills extracted and logged to `docs/sources/` by source type. See the relevant source index for full provenance.

### From arXiv papers (`docs/sources/papers/`)
- `agent-harness-design` — 6-component harness framework (ℛℳ𝒞𝒮𝒪𝒢) from arXiv:2605.26112; Phase 4 (Operational Diagnostics) added 2026-05-31
- `agent-execution-control` — Plan-Execute-Verify loop, gatekeeper pattern from arXiv:2605.18747
- `multi-agent-patterns` — functional role taxonomy, convergence types from arXiv:2605.18747
- `context-degradation` — context window failure modes
- `context-optimization` — context budget strategies

### From GitHub repositories (`docs/sources/git/`)
- `cag-implementation` — Cache-Augmented Generation (KV cache preloading) from hhhuang/CAG
- `rag-architect` — RAG design decision gates
- `rag-implementation` — RAG implementation patterns
- `llm-fine-tuning` — LLM fine-tuning workflow
- `prompt-engineering` — prompt engineering patterns (adapted from prompt-master)
- `frontend-performance` — frontend performance checklist from Linear breakdown
- `frontend-code-quality` — HTML/CSS/JS quality rules from bendc/frontend-guidelines
- `macro-evals` — macro-eval methodology from OpenAI cookbook
- `evaluation` — evaluation fundamentals
- `karpathy-guidelines` — 4-principle behavioral checklist for every coding task from multica-ai/andrej-karpathy-skills (2026-05-31)

### From online articles (`docs/sources/articles/`)
- `frontend-performance` — from performance.dev Linear breakdown (2026-05-27)
- `llm-eval-funnel` — from Spotify Engineering Blog (2026-05-27)
- `progressive-complexity-ladder` — from jxnl.co (2026-05-27)
- `cma-outcomes` — from Anthropic Cookbook (2026-05-27)
- `macro-evals` — from OpenAI Cookbook (2026-05-31)
- `instruction-architecture` — from walkinglabs.github.io/learn-harness-engineering Lectures 03–04 (2026-05-31)
- `feature-list-primitive` — from walkinglabs.github.io/learn-harness-engineering Lectures 07–08 (2026-05-31)
- `session-clean-state` — from walkinglabs.github.io/learn-harness-engineering Lectures 05, 12 (2026-05-31)
- `multi-agent-patterns` v1.3.0 enhancement — Agent vs. Workflow tool decision table + routing tree + ultracode mode, from claude.com/blog dynamic-workflows (2026-05-31)

_Last synced: 2026-05-31 (dynamic-workflows → multi-agent-patterns v1.3.0)_
