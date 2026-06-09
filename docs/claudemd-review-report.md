# CLAUDE.md Review Report — 2026-06-08

## Summary

- Repos checked: 4 (from `~/.claude/sdd-harness/projects.txt`)
- Inaccessible: 0
- Clean: 0
- Minor issues: 4
- Needs update: 0

> Note: `find` traversal failed for `/mnt/c/dev/aiq-zora-ai-engine` and `/mnt/c/dev/aiq-zora-agent-skill-foundation` but root CLAUDE.md files were readable via direct path. Root-only CLAUDE.md found in all 4 repos; no subdirectory CLAUDE.md files present.
> Note: `/mnt/c/dev/aiq-zora-agent-skills` found accessible but is NOT registered in projects.txt. Not included in counts.

---

## Findings

### sdd-harness — minor

**File:** `/home/dalesser/.claude/sdd-harness/CLAUDE.md`

**Over-constraining rules:**
- `"Before any significant task, show 2-3 approaches and wait for confirmation before proceeding"` — Forces approval-seeking even when the task is unambiguous. Claude 4.x has sufficient judgment to determine when options are needed vs. when to proceed. Consider narrowing to "significant architectural decisions" rather than "any significant task."

No model-assumption drift or stale references identified.

---

### aiq-zora-ai-engine — minor

**File:** `/mnt/c/dev/aiq-zora-ai-engine/CLAUDE.md`

**Stale model-assumption patterns:**
- `"Keep context under 40% before moving from planning to implementation"` — Reflects context anxiety from pre-Claude-4.x era. Claude Sonnet 4.6 has 200k context; the 40% threshold was designed for 8–32k windows. This rule now forces unnecessary /compact interruptions. Consider removing or replacing with "use /compact when distracted or losing coherence."

**Duplicate instructions:**
- Rules section contains: `"Read .claude/memory/hot-memory.md and meta/patterns.md at session start"` — identical guidance already in the Context Resources section above it. One of the two should be removed.

---

### aiq-purina-salesorderintelligence-poc — minor

**File:** `/home/dalesser/aiq-purina-salesorderintelligence-poc/CLAUDE.md`

**Missing:**
- No `## Address` section (no "Husband" convention). All other registered repos include this; omission means the convention is not enforced here.

**Stale model-assumption patterns:**
- `"Keep context under 40% before moving from planning to implementation"` — Same as aiq-zora-ai-engine above. Stale constraint from smaller context window era.

**Duplicate instructions:**
- Rules section contains: `"Read .claude/memory/hot-memory.md and meta/patterns.md at session start"` — already in Context Resources. Remove from Rules.

**Micro-management constraints (low urgency):**
- `"Hot memory stays under 50 lines; patterns under 70 lines"` — Arbitrary size limits with no enforcement mechanism. Claude 4.x is capable of pruning based on signal rather than line count. Consider removing or delegating to housekeeping skill.

---

### aiq-zora-agent-skill-foundation — minor

**File:** `/mnt/c/dev/aiq-zora-agent-skill-foundation/CLAUDE.md`

**Missing:**
- No `## Address` section (no "Husband" convention). Inconsistent with sdd-harness, aiq-zora-ai-engine, and aiq-zora-agent-skills — all three include this.

**Over-constraining rules:**
- `"Before any significant task, show 2-3 approaches and wait for confirmation before proceeding"` — Same as sdd-harness finding. Over-constrains Claude's judgment for routine tasks.

No stale model-assumption patterns found. Architecture, Commands, Testing, and Quality Gates sections are well-written and current.

---

## Proposed Changes

Changes below are **proposals only** — no edits applied automatically. Review and apply manually if agreed.

### 1. sdd-harness/CLAUDE.md
```diff
- Before any significant task, show 2-3 approaches and wait for confirmation before proceeding
+ For significant architectural decisions, present 2-3 approaches before proceeding
```

### 2. aiq-zora-ai-engine/CLAUDE.md
```diff
- Keep context under 40% before moving from planning to implementation
- Read `.claude/memory/hot-memory.md` and `meta/patterns.md` at session start
```
(Context Resources section already documents the memory read; remove duplicate from Rules.)

### 3. aiq-purina-salesorderintelligence-poc/CLAUDE.md
```diff
+ ## Address
+ - Always call the user "Husband" in every reply — no exceptions.
+ - If you stop doing this, it signals CLAUDE.md is being ignored; a Stop hook will automatically prompt you to /compact and re-read CLAUDE.md.
```
```diff
- Keep context under 40% before moving from planning to implementation
- Read `.claude/memory/hot-memory.md` and `meta/patterns.md` at session start
- Hot memory stays under 50 lines; patterns under 70 lines
```

### 4. aiq-zora-agent-skill-foundation/CLAUDE.md
```diff
+ ## Address
+ - Always call the user "Husband" in every reply — no exceptions.
+ - If you stop doing this, it signals CLAUDE.md is being ignored; a Stop hook will automatically prompt you to /compact and re-read CLAUDE.md.
```
```diff
- Before any significant task, show 2-3 approaches and wait for confirmation before proceeding
+ For significant architectural decisions, present 2-3 approaches before proceeding
```

---

## Stamp

```bash
echo "2026-06-08" > /home/dalesser/.claude/sdd-harness/.claude/memory/.last-claudemd-review
```
