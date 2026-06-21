---
name: skill-curator
description: "Apply weekly curation report: run description-budget audit, propose and apply merges/compressions/deletions with user approval."
risk: medium
source: local
---

# Skill Curator

Apply the weekly skill-curation report's recommendations locally, with human approval before touching anything. Also runs a description-budget audit as the interactive complement to the automated weekly sweep.

## Use this skill when

- The weekly skill-curator local runner has written `docs/skill-curation-report.md`
- You want to act on quality findings (merge, compress, delete)
- You want to audit system-reminder pressure from skill descriptions

## Do not use this skill when

- Creating a new skill — use `skill-extraction` or `kiro:spec-quick` instead
- The weekly report hasn't run yet (check `git log -- docs/skill-curation-report.md`)

---

## Workflow

### Phase 1: Load & Orient

1. Read `docs/skill-curation-report.md` from the sdd-harness repo
2. Run `git log -1 --format="%cr (%cd)" --date=short -- docs/skill-curation-report.md` to check freshness
3. If the report is older than 14 days, warn: the local skill-curator runner may not have run — check orchestrator logs at `~/.claude/sdd-harness/logs/orchestrator.log`

### Phase 2: Description Budget Audit

The automated runner already includes a description budget audit in its report. This phase lets you review it interactively and propose compressed descriptions inline.

1. Glob all files matching `~/.claude/skills/*/SKILL.md` plus `~/.claude/skills/SKILL.md`
2. For each file, extract the `description:` value from YAML frontmatter
3. Compute character count; estimate token cost: `ceil(chars / 4)`
4. Build a table and flag descriptions over threshold

**Thresholds:**
- > 150 chars: ⚠️ consider compression
- > 200 chars: 🔴 measurable system-reminder pressure — compress

**Report format:**
```
## Description Budget

Total: N skills | X chars | ~Y tokens

| Skill | Chars | Status |
|-------|-------|--------|
| skill-name | 92 | ✓ |
| long-skill | 183 | ⚠️ |
| very-long  | 217 | 🔴 |
```

**Grammar compression heuristics (from steipete/agent-scripts skill-cleaner):**
- Drop articles where meaning is unambiguous ("Analyze the resource" → "Analyze resource")
- Use imperative verb form, cut filler phrases ("Use when you need to" → implied)
- Replace "or"-separated noun lists with comma lists
- Preserve trigger nouns (product, tool, action, object) — these are load-bearing for skill routing

### Phase 3: Surface Consolidated Findings

Present all findings in one view before proposing any actions:

1. **From weekly report:** duplicate pairs, quality scores below threshold, and the **Usage Evidence** section — deprecate candidates (no invocation in 30d) and archive candidates (90d), backed by real `logs/skill-usage.jsonl` fire data rather than file mtime
2. **From Phase 2:** descriptions over the 150-char threshold

For each finding, determine the action type:

| Action | When |
|--------|------|
| **Merge** | Two skills have overlapping scope; keep the better one, fold unique content in |
| **Compress description** | Description > 150 chars; propose shorter text inline |
| **Delete** | Low quality score + cold (no invocation in 30d per Usage Evidence) + no unique content |
| **No action** | Flagged but justified; note reason explicitly. Never flag a `pinned: true` skill |

### Phase 4: Propose Actions

Present a numbered list — **always wait for user approval before executing:**

```
## Curator Proposal

1. Compress description — `multi-agent-patterns` (183 chars → ~95)
   Current:  "Multi-agent design patterns covering routing, handoffs, voting,
              fan-out/fan-in, swarm topologies, and adversarial validation."
   Proposed: "Multi-agent patterns: routing, handoff, voting, swarm, adversarial validation."

2. Merge — `rag-implementation` into `rag-architect` (87% body overlap per curation report)
   Keep: `rag-architect`; fold unique implementation steps into a new Phase 4

3. Delete — `csv-data-summarizer` (quality score 1.8/4, unused 45+ days, no unique content)

**Apply all? Or specify (e.g. "1 and 3", "skip 2", "only compressions"):**
```

### Phase 5: Execute Approved Changes

**Compress description:**
- Edit the `description:` line in the SKILL.md frontmatter
- Print char count before/after

**Merge:**
- Read both SKILL.md files fully
- Identify content in the merge-out skill not covered by the surviving skill
- Append it to the surviving skill under `### From: [merged-skill-name]`
- Show the surviving skill's new end section for review before deleting the other

**Delete:**
- Show the full SKILL.md one final time
- Delete the directory only after explicit confirmation ("yes, delete it")

**After all changes:** Re-run Phase 2 and show the delta:
```
Description budget: 3,140 chars → 2,890 chars (−250, −63 tokens)
```

### Phase 6: Update Source Log

Append a curation entry to `docs/skill-curation-report.md` under a new `## Local Curation — [date]` section noting what was merged/compressed/deleted and the description budget before/after.
