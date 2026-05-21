## Harness Drift Review — 2026-05-20

### Auto-Fixed

- DOCS: updated stale link in `docs/trust-battery/README.md` → `../SDD-USAGE.md#daily-maintenance-automated` → `../harness-documentation/SDD-USAGE.md#daily-maintenance-automated`
- DOCS: updated stale link in `docs/trust-battery/README.md` → `../SDD-SETUP-GUIDE.md#automated-hooks` → `../harness-documentation/SDD-SETUP-GUIDE.md#automated-hooks`

Both links pointed to the harness root instead of `docs/harness-documentation/` where the files actually live.

---

### Flagged for Human Review

- **HOOKS: `scan-pii.sh` on disk but not registered in settings.json**
  - Path: `/home/dalesser/.claude/sdd-harness/.claude/hooks/scan-pii.sh`
  - The script is a standalone PII scanner (OpenAI Privacy Filter wrapper) that accepts `--staged`, a file path, or `.` as arguments. It exits 1 on high-severity PII (secrets, account numbers).
  - Decision needed: register as a `PreToolUse` hook (e.g. on `Write|Edit`), wire into a git pre-commit hook, or leave as an on-demand utility.

---

### Clean (no drift found)

- **MEMORY index**: all 10 entries in MEMORY.md have matching files; all 10 files in the memory dir are indexed. No stale entries, no orphaned files.
- **Hook scripts → settings.json**: all 12 scripts referenced in `sdd-harness/.claude/settings.json` exist on disk.
- **settings.json → scripts on disk**: all referenced scripts verified present (excluding `scan-pii.sh` which is the unregistered case above).
- **Doc links (all others)**: `FIRST-TIME-SETUP.md`, `../specs/2026-05-12-local-daily-maintenance-design.md`, `../../kiro/settings/rules/session-quality-rubric.md`, `../../kiro/settings/rules/anti-rationalization.md`, and `../memory/README.md` all resolve correctly.
