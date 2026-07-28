# CLAUDE.md Review Report — 2026-07-26

## Summary
- Repos checked: 6
- Inaccessible: 0
- Clean: 1
- Minor issues: 2
- Needs update: 1

## Since Last Review (2026-06-22)
- **Still open (5 weeks):** stale `.claude/docs/SDD-USAGE.md` path in `sdd-harness` and `aiq-zora-ai-engine` — neither was fixed.
- **Still open:** `Keep context under 40%` rule in `aiq-purina-salesorderintelligence-poc`.
- **Improved:** `aiq-zora-agent-skill-foundation` promoted from `minor` to `clean` — no new issues found this cycle.
- **Closed:** `aiq-zora-ai-engine` thinness noted again below; no structural additions since last run.

## Findings

### sdd-harness — minor

**Stale path (open since 2026-06-22):** Context Resources references `.claude/docs/SDD-USAGE.md` — this path does not exist. Correct path: `.claude/docs/harness-documentation/SDD-USAGE.md` (verified present).

**Steering bootstrap pending:** SessionStart fired `[STEERING-BOOTSTRAP-DUE]` — `.claude/steering/` has no steering files yet. Run `/kiro:steering` then `rm .claude/memory/.steering-bootstrap-pending`.

All other sections accurate: AI-Legible Code rules, Serena integration, quality gates, address convention ("Husband"), post-task and test output conventions.

**Proposed fix:**
```diff
- - `.claude/docs/SDD-USAGE.md` — read when you need SDD command reference
+ - `.claude/docs/harness-documentation/SDD-USAGE.md` — read when you need SDD command reference
```

---

### aiq-zora-ai-engine — needs-update

**Stale path (open since 2026-06-22):** References `.claude/docs/SDD-USAGE.md` — does not exist. Correct: `.claude/docs/harness-documentation/SDD-USAGE.md`.

**Missing sections (vs. other repos in fleet):**
- AI-Legible Code rules (blast radius, Rule of Three, vertical slices)
- Serena integration (`get_diagnostics_for_file`, `find_referencing_symbols`)
- SDD Workflow command list (`/kiro:spec-init`, `/kiro:reflect`, etc.)
- Post-Task and Test Output conventions

This is the thinnest CLAUDE.md in the fleet (1.7KB vs 3–6.7KB for others) and has not grown since the last sweep. Recommend syncing from sdd-harness template on next session.

**Proposed fix (minimum):**
```diff
- - `.claude/docs/SDD-USAGE.md` — read when you need SDD command reference
+ - `.claude/docs/harness-documentation/SDD-USAGE.md` — read when you need SDD command reference
```

---

### aiq-purina-salesorderintelligence-poc — minor

**Pre-Claude-4.x context budget rule (open since 2026-06-22):** `"Keep context under 40% before moving from planning to implementation"` is a Claude-3 era workaround. Claude 4.x reasons coherently at high context utilization; the 40% threshold creates unnecessary interrupt friction. Drop the hard number.

**Duplicate memory-read instruction:** `"Read .claude/memory/hot-memory.md and meta/patterns.md at session start"` appears in both the Context Resources section and the Rules section. Remove from Rules.

**Micro-managed memory file sizes:** `"Hot memory stays under 50 lines; patterns under 70 lines"` — the memory discipline hooks handle compaction; Claude does not benefit from explicit line limits in CLAUDE.md.

GitNexus section is accurate and well-maintained. No stale path references.

**Proposed fix:**
```diff
- - Keep context under 40% before moving from planning to implementation
+ (remove this line — hooks handle compaction)
- - Read `.claude/memory/hot-memory.md` and `meta/patterns.md` at session start
  (already covered by Context Resources above — remove from Rules)
```

---

### aiq-zora-agent-skill-foundation — clean

No issues found. Uses correct `.claude/docs/harness-documentation/SDD-USAGE.md` path. ERRORS.md documented as gitignored/local. Comprehensive architecture and testing documentation. Promoted from `minor` (last run) to `clean`.

---

## Open Action Items (carry-over)

| Item | Repo | Open Since | Priority |
|------|------|-----------|----------|
| Fix stale SDD-USAGE.md path | sdd-harness | 2026-06-22 | Medium |
| Fix stale SDD-USAGE.md path | aiq-zora-ai-engine | 2026-06-22 | High |
| Expand thin CLAUDE.md | aiq-zora-ai-engine | 2026-06-22 | Medium |
| Remove 40% context rule | aiq-purina-salesorderintelligence-poc | 2026-06-22 | Low |
| Run /kiro:steering | sdd-harness | 2026-07-26 | High |
