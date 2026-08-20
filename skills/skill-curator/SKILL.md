---
name: skill-curator
description: "Apply weekly curation report: run description-budget audit, propose and apply merges/compressions/deletions with user approval."
risk: medium
source: local
---

# Skill Curator

Apply the weekly skill-curation report's recommendations locally, with human approval before touching anything. Also runs a description-budget audit as the interactive complement to the automated weekly sweep.

Framing note: per the taxonomy in *Self-Improvements in Modern Agentic Systems* (arXiv 2607.13104), this skill's own weekly audit routine is a scaffold-level self-improvement loop — the update target is the skill files themselves, and the change signal is usage/health metrics (Usage Evidence, description budget) plus human feedback (the Phase 4 approval gate below).

## Use this skill when

- The weekly skill-curator local runner has written `reports/skill-curation-report.md`
- You want to act on quality findings (merge, compress, delete)
- You want to audit system-reminder pressure from skill descriptions

## Do not use this skill when

- Creating a new skill — use `skill-extraction` or `kiro:spec-quick` instead
- The weekly report hasn't run yet (check `git log -- reports/skill-curation-report.md`)

---

## Workflow

### Phase 1: Load & Orient

1. Read `reports/skill-curation-report.md` from the sdd-harness repo
2. Run `git log -1 --format="%cr (%cd)" --date=short -- reports/skill-curation-report.md` to check freshness
3. If the report is older than 14 days, warn: the local skill-curator runner may not have run — check orchestrator logs at `$SDD_HARNESS/logs/orchestrator.log`

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
3. **Module-count audit:** for each skill, count distinct modules/components/reference-files bundled into its SKILL.md; flag any skill over 3 as a split candidate (SkillsBench, arXiv 2602.12670 — focused skills bundling ≤3 modules consistently outperform larger bundles in task pass-rate)
4. **Continuous eval-gate drift check** (Phase 3.5 below) — new failure modes observed in live skill invocations that the skill's original `skill-eval-gate` scenario set didn't cover
5. **From weekly report's `## Dependency Flags` section:** skills that are both a deletion/archive candidate AND cross-referenced by another skill, hook, agent, or command (per the runner's deterministic `skill-dependency-scan.sh` map). Treat this section as ground truth — do not re-derive it with your own search, and never propose a bare delete/merge for anything listed here.

For each finding, determine the action type:

| Action | When |
|--------|------|
| **Merge** | Two skills have overlapping scope; keep the better one, fold unique content in. Requires the merged-out skill is NOT in Dependency Flags, or its referrers are addressed as part of the same action |
| **Compress description** | Description > 150 chars; propose shorter text inline |
| **Split** | Skill bundles more than 3 distinct modules/components/reference-files (per Module-count audit) |
| **Delete** | Low quality score + cold (no invocation in 30d per Usage Evidence) + no unique content + NOT in Dependency Flags |
| **Delete + migrate references** | Same deletion criteria, but the skill IS in Dependency Flags — propose updating/removing each listed referrer (or folding the referenced logic into another skill) as one combined action, never a bare delete |
| **Add eval scenario** | Phase 3.5 drift check found a live failure mode the skill's `skill-eval-gate` scenario set doesn't cover |
| **No action** | Flagged but justified; note reason explicitly. Never flag a `pinned: true` skill |

### Phase 3.5: Continuous Eval-Gate Drift Check

`skill-eval-gate` scenarios are authored once, at skill-creation time, and never revisited — a skill can drift out of sync with how it's actually used without anyone noticing. This phase closes that loop, borrowed from the "continuous evaluation" stage of a prompt-eval maturity model (source: `docs/sources/articles/README.md`, "Eval Gates for Prompts").

1. Identify skills with a logged `skill-eval-gate` PASS verdict (check `reports/skill-curation-report.md` history / commit messages referencing the gate).
2. If Raindrop Workshop traces are available (`mcp__raindrop__query_traces`), pull recent invocations of those skills.
3. Run `active-observability`'s facet-clustering over the sampled traces to surface recurring failure patterns — a skill firing on the wrong trigger, an agent ignoring its steps, a task the skill claims to cover but visibly fails at.
4. For each new failure pattern not already represented in that skill's original scenario table, draft one concrete new scenario (realistic prompt + deterministic pass/fail check, matching `skill-eval-gate` Phase 1's format) and flag it as an **Add eval scenario** finding.
5. If Raindrop isn't connected or no traces exist yet for a skill, skip it silently — this phase only surfaces what live data shows, it never fabricates scenarios.

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

4. Add eval scenario — `pr-babysit` (live traces show it firing on draft PRs with no reviewers requested; original scenario set didn't cover this)
   New scenario: "PR opened as draft, no reviewers assigned" → pass = skill declines to nudge for review

5. Delete + migrate references — `active-observability` (quality score 2.1/4, unused 40+ days)
   ⚠️ REFERENCED — used by `hooks/claude/raindrop-best-practices.sh:25`, skill `skill-curator` (Phase 3.5)
   Must update these before/with deletion. Proposed: fold its facet-clustering step directly
   into `skill-curator` Phase 3.5, then update the hook's reference before removing the skill.

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

**Delete + migrate references:**
- **Hard rule:** if the target skill appears in the report's Dependency Flags section, do NOT delete or merge it until each listed referrer has been either (a) updated/edited to no longer depend on it, or (b) the user has explicitly confirmed it's safe to leave (e.g. that referrer is itself being removed in the same batch). A flagged skill is never a bare delete.
- Show each referrer file/skill and the proposed edit (updated reference, or the logic folded into the surviving skill) before touching anything
- Apply the referrer updates first, then delete the target directory, same confirmation gate as a plain Delete

**Add eval scenario:**
- Append the new scenario to whatever scenario table/list the target skill's own docs or eval history use for `skill-eval-gate` runs
- Note in the curation log which live failure pattern prompted it, so the provenance stays traceable

**After all changes:** Re-run Phase 2 and show the delta:
```
Description budget: 3,140 chars → 2,890 chars (−250, −63 tokens)
```

### Phase 6: Update Source Log

Append a curation entry to `reports/skill-curation-report.md` under a new `## Local Curation — [date]` section noting what was merged/compressed/deleted and the description budget before/after.
