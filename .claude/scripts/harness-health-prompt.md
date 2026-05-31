You are running the bi-weekly HARNESS HEALTH SWEEP. This invocation runs LOCALLY (not in Anthropic cloud), so you have full access to:

- The full file system, including all registered repos listed in `~/.claude/sdd-harness/projects.txt`
- `~/.claude/skills/` via the Skill tool
- The full repo file tree (you are already in the sdd-harness working directory)

Today's date: TODAY_PLACEHOLDER

Execute Phase 1 and Phase 2 in order. Each is error-isolated — if one phase fails, log the failure and continue.

---

## Phase 1 — CLAUDE.md Review

**Goal:** Audit all CLAUDE.md files across registered repos for stale instructions, over-constraining rules from pre-Claude-4.x habits, and model-assumption drift.

Steps:
1. Read `~/.claude/sdd-harness/projects.txt` (skip blank lines and lines starting with `#`)
2. For each repo path:
   a. If the path does not exist on disk or has no `.claude/` dir, mark as **inaccessible** and note it
   b. Read `CLAUDE.md` (root) and `.claude/CLAUDE.md` if present
   c. Audit for these failure modes:
      - Instructions that assume Claude < 4.x behavior (e.g., "always use Plan mode for X", overly prescriptive step sequences that modern Claude handles automatically)
      - Stale references to tools, commands, or paths that no longer exist
      - Over-constraining rules that limit Claude's judgment unnecessarily
      - Contradictions between root CLAUDE.md and project-level CLAUDE.md
3. Rate each repo: `clean` | `minor` (cosmetic, low-urgency) | `needs-update` (stale/incorrect instructions)

Write findings to `docs/claudemd-review-report.md`:

```
# CLAUDE.md Review Report — TODAY_PLACEHOLDER

## Summary
- Repos checked: N
- Inaccessible: N
- Clean: N
- Minor issues: N
- Needs update: N

## Findings

### [repo-name] — <clean|minor|needs-update>
[Finding or "No issues found"]

...
```

---

## Phase 2 — Iterative Skill Repair

**Goal:** Apply a Review→Repair→Validate loop to skills flagged as low-quality in the most recent curation report.

Steps:
1. Read `docs/skill-curation-report.md`. Find skills listed under **Low-Quality Candidates**.
2. For each flagged skill (max 3 per run, prioritize lowest score first):
   a. **Review** — read the skill file at `~/.claude/skills/<name>/SKILL.md`
   b. **Repair** — rewrite to improve against the four SkillOS dimensions:
      - Task relevance: clear trigger conditions
      - Operational validity: accurate, executable instructions
      - Content quality: no fluff, no stale references
      - Compression ratio: ≤30% of the context it replaces
   c. **Validate** — re-score the repaired version; only write if the total score improved by ≥ 2 points
   d. If score delta ≤ 1 after repair, mark as **stalled** (don't write)
3. Apply approved repairs by writing the updated SKILL.md files directly.

Append to `docs/skill-curation-report.md`:

```
## Iterative Repair Run — TODAY_PLACEHOLDER

| Skill | Before | After | Status |
|-------|--------|-------|--------|
| skill-name | 5/12 | 9/12 | repaired |
| skill-name | 4/12 | 5/12 | stalled — delta too small |
```

If `docs/skill-curation-report.md` does not exist, note it and skip Phase 2.

---

## Output

Emit a single summary line:

```
Harness health sweep complete: N repos reviewed, N skills repaired, N stalled
```
