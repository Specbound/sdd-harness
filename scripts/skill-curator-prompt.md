You are running the weekly SKILL-CURATOR SWEEP for the sdd-harness. This invocation runs LOCALLY (not in Anthropic cloud), so you have full access to:

- `~/.claude/skills/` via the Skill tool
- The full repo file tree (you are already in the repo's working directory)
- `.claude/memory/` and all gitignored files

Today's date: TODAY_PLACEHOLDER

Execute the three phases below in order. Each is error-isolated — if one phase fails, log and continue.

---

## Phase 1 — Skill Quality Audit

Glob all files matching `~/.claude/skills/*/SKILL.md` plus any top-level `~/.claude/skills/SKILL.md`.

For each skill file:
1. Read the YAML frontmatter: `name`, `description`, `source`, `risk`
2. Score against the four SkillOS quality dimensions:
   - **Task relevance** (0–3): Is the trigger clear? Would a model know when to invoke this?
   - **Operational validity** (0–3): Are instructions accurate and still executable as written?
   - **Content quality** (0–3): Is it free of fluff, duplication, and stale references?
   - **Compression ratio** (0–3): Does it replace more context than it consumes?
3. Flag skills with total score ≤ 6 as low-quality candidates
4. Identify duplicate pairs: skills with substantially overlapping scope

Compression heuristic: skill content should be ≤30% of the context it would replace manually.

---

## Phase 2 — Description Budget Audit

For each skill found in Phase 1, check the `description:` frontmatter value:
- Compute character count; estimate token cost: `ceil(chars / 4)`
- Flag: > 150 chars ⚠️ consider compression; > 200 chars 🔴 measurable system-reminder pressure

Grammar compression heuristics (apply when proposing shorter text):
- Drop articles where meaning is unambiguous
- Use imperative verb form, cut filler phrases ("Use when you need to" → implied)
- Replace "or"-separated noun lists with comma lists
- Preserve trigger nouns — these are load-bearing for skill routing

Build the budget table but do NOT apply changes — leave that for human-invoked `/skill-curator`.

---

## Phase 3 — Memory Governance Health Audit

Check the five compaction-discipline hook failure modes:

1. `.claude/hooks/stop-hook.sh` — verify it still writes `observations.md` entries; check that the memory-conventions rule reference is intact
2. `.claude/hooks/session-start-hook.sh` — verify catch-up trigger logic is present and reads `.last-routine-run`
3. `kiro/settings/rules/memory-conventions.md` — verify the file exists and has not been emptied or truncated
4. `.claude/memory/observations.md` — check recency: last entry should be within 7 days (flag if stale)
5. `.claude/memory/hot-memory.md` — check recency: flag if last-modified > 14 days

For each failure mode, record: `ok`, `warn` (degraded but recoverable), or `critical` (broken).

---

## Phase 4 — Write Report

Write `docs/skill-curation-report.md` with this structure:

```
# Skill Curation Report — TODAY_PLACEHOLDER

## Summary
- Skills audited: N
- Low-quality flags: N
- Duplicate pairs: N
- Description flags (>150 chars): N
- Memory governance: <ok|warn|critical>

## Description Budget

Total: N skills | X chars | ~Y tokens

| Skill | Chars | Status |
|-------|-------|--------|
| ...   | ...   | ...    |

## Quality Findings

### Low-Quality Candidates
[skill name] — score N/12 — [reason]

### Duplicate Pairs
[skill A] ↔ [skill B] — [overlapping scope summary]

## Memory Governance Health

| Check | Status | Notes |
|-------|--------|-------|
| stop-hook writes observations | ok | |
| session-start catch-up logic | ok | |
| memory-conventions.md intact | ok | |
| observations.md recency | ok | last entry: DATE |
| hot-memory.md recency | ok | last modified: DATE |
```

If `docs/skill-curation-report.md` already exists, REPLACE it entirely (this is the canonical weekly snapshot).

---

## Output

Emit a single summary line:

```
Skill curator sweep complete: N skills audited, N flags, governance=<ok|warn|critical>
```
