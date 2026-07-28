# Drift Review Report — SDD Harness

**Date:** 2026-07-12
**Scope:** Full harness sweep — structural integrity, install↔source sync, documentation drift
**Method note:** The requested `repo-drift-review` skill does not exist (not registered, nothing matching `*drift*` on disk). The sweep was fulfilled with the two registered skills that cover the same ground — `kiro:harness-validate` (structural drift) and `kiro:sync-docs` (doc drift) — plus a deterministic source-tree ↔ installed-copy diff.

---

## Verdict

**7 drift findings, 7 auto-fixed. 3 advisory items left for human decision.**

---

## Auto-Fixed

### 1. Hardcoded paths in hook usage comments (CRITICAL — path guard)
`check-no-hardcoded-paths.sh` flagged two hooks whose registration-example comments embedded `/home/dalesser/.claude/sdd-harness/...`:

- `.claude/hooks/setup-buffer-hook.sh:50`
- `.claude/hooks/skill-permissions-gate.sh:64`

**Fix:** rewritten to the relative convention used by every compliant hook (`bash .claude/hooks/<name>.sh`). Guard now passes clean.

### 2. Broken command → agent references (CRITICAL — runtime breakers)
- `commands/kiro/harness-test.md:35` (+ installed copy): `subagent_type="steering"` → agent is registered as `steering-agent`. **Fixed in both copies.**
- `commands/kiro/validate-adversarial.md:37` (+ installed copy): `subagent_type="validate-adversarial"` → agent is registered as `validate-adversarial-agent`. **Fixed in both copies.**

### 3. Agent naming-convention drift
`jira-solve-agent.md` declared `name: kiro/jira-solve-agent` — the only agent with a path-prefixed name. It was functional (registered and referenced consistently), so this was convention drift, not breakage. **Normalized to `jira-solve-agent`** in the agent frontmatter (source + installed) and in the prose reference in `jira-solve.md` (source + installed) — 4 files, kept consistent.

### 4. Installed skills newer than source tree (retro-vendor violation)
Four skills were edited in `~/.claude/skills/` without vendoring back to `skills/` — exactly what the harness-skills-in-source rule forbids:

| Skill | Installed edit | What changed |
|---|---|---|
| `agent-harness-design` | Jul 9 | new "Governance Without Enforcement" anti-pattern + `resources/examples/` dir |
| `csv-data-summarizer` | Jul 12 | curated rewrite (tighter description, procedure-style body) |
| `git-pushing` | Jul 12 | curated rewrite |
| `rtk-token-reduction` | Jul 12 | rescoped to "advanced usage not covered by always-loaded RTK.md" |

The Jul 12 edits look like today's skill-curation run updating installed copies directly. **Fix:** copied installed → source for all four (including the `resources/` dir).

### 5. Stale / missing installed kiro commands
Source commands updated Jul 8 had installed copies from May 31; two were never installed at all:

- Stale: `autoresearch.md` (Agent Recipe section), `jira-solve.md` (triage pre-gate), `spec-init.md` (pref-elicit pre-check), `spec-quick.md` (triage gate + Step 1.5)
- Never installed: `loop.md`, `pref-elicit.md`

**Fix:** copied source → installed for all six. Both trees now diff clean.

## No Drift Found

- **Documentation drift (`kiro:sync-docs`):** all changed files since HEAD~1 are `.md`/harness files — no source-code changes for docs to lag behind.
- **Memory caps:** hot-memory 28/50 lines, patterns 18/70 — within caps.
- **L0 headers:** 7/7 memory files compliant.
- **Templates:** all 26 exist; every referenced path valid.
- **Rules:** `lean-ctx.md` well-formed.
- **Orphaned installs:** no installed kiro command lacks a source counterpart.

## Advisory (not auto-fixed — human decision needed)

1. **5 unreferenced agents** (no command invokes them): `gitnexus-setup-agent`, `harness-fix-agent`, `harness-updater`, `prompt-diagnosis-agent`, `spec-refactor-agent`. Some may be invoked ad-hoc by skills or the daily orchestrator rather than commands — deleting is destructive, so left alone. Decide: integrate, document as ad-hoc, or remove.
2. **`.claude/steering/` does not exist** despite CLAUDE.md listing it as a context resource. Run `/kiro:steering` to bootstrap, or drop the reference.
3. **`observations.md` at cap (50/50 entries).** Next reflect/housekeeping run should archive to glacier before appending.
