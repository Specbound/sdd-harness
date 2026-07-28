## Harness Drift Review — 2026-07-16

### Auto-Fixed

**MEMORY**
- No changes. All 11 indexed entries resolve to existing files, and every memory file is indexed. Clean.

**HOOKS**
- `HOOKS: removed dead hook → ccr-routine-added-notify.sh` — the `CronCreate` matcher block in `.claude/settings.json` pointed to `hooks/ccr-routine-added-notify.sh`, which does not exist on disk. Removed the entire matcher block (and its trailing array comma). JSON re-validated as well-formed.

**DOCS** (11 links repaired across 3 files)
- `DOCS: updated stale link → docs/skills/skill-extraction/README.md` (4 links): `../papers/README.md → ../../sources/papers/README.md`, `../git/README.md → ../../sources/git/README.md`, `../articles/README.md → ../../sources/articles/README.md`, `../x/README.md → ../../sources/x/README.md` (the `papers/git/articles/x` source dirs live under `docs/sources/`; each target is a unique match).
- `DOCS: updated stale link → docs/harness-documentation/SDD-USAGE.md` (1 link): `trust-battery/ → ../evaluation/trust-battery/` (single `trust-battery` dir, under `docs/evaluation/`).
- `DOCS: updated stale link → docs/evaluation/trust-battery/README.md` (6 links): off-by-one relative depth. `../memory/README.md → ../../memory/README.md`; `../harness-documentation/SDD-USAGE.md#… → ../../harness-documentation/…`; `../harness-documentation/SDD-SETUP-GUIDE.md#… → ../../harness-documentation/…`; `../../kiro/settings/rules/session-quality-rubric.md → ../../../kiro/…` (2 occurrences, lines 204 & 287); `../../kiro/settings/rules/anti-rationalization.md → ../../../kiro/…`. The `kiro/settings/rules/` files exist at the repo root; the corrected relative path resolves there deterministically.

### Flagged for Human Review

**Hook scripts on disk, not referenced in `.claude/settings.json` (13)** — may be intentionally dormant or pending registration; not auto-removed (skill never deletes scripts):
- `action-capture.sh`
- `address-check-hook.sh`
- `frontend-security-nudge.sh`
- `lean-ctx-nudge-hook.sh`
- `pre-tool-use-gitnexus.sh`
- `prompt-hook.sh`
- `raindrop-best-practices.sh`
- `scan-pii.sh`
- `setup-buffer-hook.sh`
- `skill-permissions-gate.sh`
- `skill-usage-tracker.sh`
- `tool-failure-capture.sh`
- `tool-failure-recall.sh`

Note: `action-capture.sh` and `tool-failure-capture.sh`/`tool-failure-recall.sh` correspond to features described in indexed memory (`project_memori_patterns.md` action-capture PostToolUse hook; tool-failure-memory skill). If those are meant to be live, they need registration in `settings.json`. Decide per script whether to register or retire.

**Cosmetic label mismatches (not link breakage) in `docs/skills/skill-extraction/README.md`** — the visible link labels still read `` `docs/papers/` ``, `` `docs/git/` ``, `` `docs/articles/` ``, `` `docs/x/` `` while the real paths are under `docs/sources/`. Link *targets* were fixed and now resolve; the display text was left as-is (relabeling is a judgment call, out of scope for unambiguous auto-fix). Update labels to `docs/sources/…` if desired.

**External `~`-notation links in `docs/security/privacy-filter/README.md` (3)** — `~/.claude/skills/secrets-management/`, `~/.claude/skills/gdpr-data-handling/`, `~/.claude/skills/security-scanning-security-sast/`. These point outside the docs tree to real, existing skill directories (verified on disk via `~` expansion). They will not resolve in a plain Markdown renderer (which does not expand `~`), but they are deliberate cross-references, not repo drift. Left untouched. Convert to absolute paths only if renderer-clickability matters.

**Docs tree is mirrored under `.claude/docs/`** — a parallel copy of `docs/` exists at `/home/dalesser/.claude/sdd-harness/.claude/docs/`. Only the canonical `docs/` tree (the skill's defined scope) was swept and fixed; the mirror was not. If the mirror is authoritative or synced, the same 11 link fixes may need to be propagated there (or the mirror re-synced). Confirm which copy is source-of-truth.

### Clean (no drift found)

- **Memory index** — 11/11 MEMORY.md entries resolve; 0 orphaned memory files.
- **Registered hooks** — 15 remaining hook references in `settings.json` all point to scripts that exist on disk (only `ccr-routine-added-notify.sh` was dead; now removed).
- **Doc links** — after fixes, all 22 local Markdown links across `docs/` resolve (0 unresolved).
