<!-- L0: Quick reference — all SDD commands with usage examples -->

# SDD Usage Guide

How to use the Spec-Driven Development harness day-to-day.

---

## Project Memory

### `/kiro:steering` — Bootstrap or refresh project knowledge
Scans the codebase and generates `.claude/steering/` files (product, tech, structure).

```
/kiro:steering
```
Run once on a new project, or after major architectural changes.

### `/kiro:steering-custom` — Add domain-specific steering
Creates a focused steering doc for a specific domain.

```
/kiro:steering-custom database
/kiro:steering-custom authentication
/kiro:steering-custom api-standards
```

---

## Spec Workflow

### `/kiro:spec-init` — Start a new feature
Creates a spec workspace in `specs/` with metadata tracking.

```
/kiro:spec-init "Add revenue trend chart to dashboard"
```

### `/kiro:spec-requirements` — Generate requirements
Produces EARS-format requirements for an initialized spec.

```
/kiro:spec-requirements revenue-trend-chart
```

### `/kiro:spec-design` — Generate technical design
Researches the codebase and produces a design doc with architecture decisions.

```
/kiro:spec-design revenue-trend-chart
```

### `/kiro:spec-tasks` — Generate implementation tasks
Breaks the design into parallelizable tasks with dependencies.

```
/kiro:spec-tasks revenue-trend-chart
```

### `/kiro:spec-quick` — Fast path (requirements → design → tasks)
Runs all three spec phases in one command. Good for small features.

```
/kiro:spec-quick "Add retry logic to SQL query execution"
```

### `/kiro:spec-impl` — Implement from approved spec
Executes tasks via TDD (test first, then code, then verify). After each task's VERIFY step passes, a self-review agent automatically inspects the touched files for code reuse, quality, and efficiency issues, fixes confirmed issues (skipping false positives), and re-runs the tests — stopping and surfacing any failures before marking the task complete. The self-review findings appear in the final summary.

```
/kiro:spec-impl revenue-trend-chart
```

### `/kiro:spec-status` — Check spec progress
Shows current phase, approvals, and open tasks.

```
/kiro:spec-status revenue-trend-chart
```

---

## Validation

### `/kiro:validate-gap` — Requirements vs. code gap analysis
Checks what's been implemented vs. what's required.

```
/kiro:validate-gap revenue-trend-chart
```

### `/kiro:validate-design` — Design quality review
Reviews the design doc for completeness and consistency.

```
/kiro:validate-design revenue-trend-chart
```

### `/kiro:validate-impl` — Implementation validation
Verifies code matches the spec (requirements + design + tasks).

```
/kiro:validate-impl revenue-trend-chart
```

---

## Documentation Sync

### `/kiro:sync-docs` — Sync docs with code changes
Finds all `.md` files referencing changed code and updates them. Runs automatically at session end, but can be triggered manually.

```
/kiro:sync-docs
```

---

## Memory (Cog)

### `/kiro:reflect` — Mine session learnings
Reviews recent work, extracts observations, promotes patterns, updates hot-memory.

```
/kiro:reflect
```
Run after completing a spec, finishing a debugging session, or at end of a productive session.

### `/kiro:housekeeping` — Prune and archive memory
Archives old observations to glacier, enforces caps, validates formats.

```
/kiro:housekeeping
```
Run when the stop-hook nudges you, or periodically.

### `/kiro:evolve` — Audit harness rules
Measures memory health, detects friction patterns, proposes rule improvements.

```
/kiro:evolve
```
Run on demand when something feels off about the workflow.

### `/kiro:harness-fix` — Fix a specific agent mistake
When you observe the agent making a repeatable behavioral mistake, this command encodes a targeted prevention rule so it never happens again. Lighter than `/kiro:evolve` — fixes one thing immediately.

```
/kiro:harness-fix "agent keeps creating new utility files instead of reusing existing ones"
/kiro:harness-fix "agent runs the full test suite instead of targeted tests"
```
The rule is added to the appropriate agent file or rule file and distributed via `update.sh`.

---

## Jira Integration

### `/kiro:jira-solve` — Work on a Jira ticket with auto-commenting
Start a session tied to a Jira ticket. When you push code, a comment is automatically posted to the ticket describing what was done, why, and which files changed.

```
/kiro:jira-solve ZORAAI-1234
```

The ticket ID is captured at prompt time and stored in `~/.claude/state/active_jira_ticket`. After `git push`, a comment is posted automatically containing:
- Branch name and commit count
- Approach summary (extracted from `docs/` markdown if present)
- Files changed (from `git diff --name-only`)

The state is single-fire — subsequent pushes in the same session don't double-post.

**Prerequisites**: `~/.env.jira` with `JIRA_URL` and `JIRA_PAT` (or `JIRA_USERNAME` + `JIRA_API_TOKEN`).
See `.claude/docs/SDD-SETUP-GUIDE.md` → "Jira Integration" for full setup.

---

## AutoResearch (ML Experiments)

### `/kiro:autoresearch-init` — Interactive ML project setup
Asks leading questions about your research goal, data, model, metric, and constraints, then generates `program.md`, `train.py`, and `prepare.py`.

```
/kiro:autoresearch-init
/kiro:autoresearch-init "optimize a small transformer on our Python codebase"
```

### `/kiro:autoresearch` — Run autonomous experiment loop
Reads `program.md`, iterates on `train.py` (~5 min per experiment), keeps improvements, reverts failures.

```
/kiro:autoresearch          # run until stopped
/kiro:autoresearch 10       # run 10 iterations
```

**Prerequisites**: `uv` installed, `program.md` + `train.py` + `prepare.py` in project root. Run `uv run prepare.py` once before starting the loop.

See `docs/autoresearch/README.md` for full details.

---

## Skill Extraction (from Repositories)

### `/kiro:skill-extract-scan` — Analyze a repo for extractable skills
Scans a repository, scores candidate modules against the extraction rubric, and produces a reviewable plan.

```
/kiro:skill-extract-scan https://github.com/org/repo
/kiro:skill-extract-scan /path/to/local/repo
```

Output: `.claude/skill-extraction/<repo-name>/plan.md` with ranked candidates, scores, and rationale.

### `/kiro:skill-extract` — Generate SKILL.md files
Generates skills from an approved extraction plan, or runs the full pipeline with `-y`.

```
/kiro:skill-extract .claude/skill-extraction/repo/plan.md
/kiro:skill-extract https://github.com/org/repo -y
```

Output: `~/.claude/skills/<name>/SKILL.md` for each extracted skill.

See `docs/skill-extraction/README.md` for full details on scoring, workflow, and security.

---

## Typical Workflow

```
1. /kiro:steering                        ← once per project (or after big changes)
2. /kiro:spec-init "Add feature X"       ← start the feature
3. /kiro:spec-quick "Add feature X"      ← fast: requirements → design → tasks
   (review and approve each phase)
4. /kiro:spec-impl feature-x             ← implement via TDD
5. /kiro:reflect                         ← capture what you learned
```

For larger features, use the individual spec phases (`spec-requirements` → `spec-design` → `spec-tasks`) instead of `spec-quick` to review each phase separately.
