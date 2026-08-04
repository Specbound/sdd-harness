## Harness Drift Review — 2026-08-04

### Auto-Fixed

**MEMORY**
- No changes. All 11 indexed entries resolve to existing files, and every memory file in `memory/` is indexed. Clean.

**HOOKS**
- No changes. All 22 hook references in `.claude/settings.json` point to scripts that exist on disk. No dead hook entries found.

**DOCS**
- No changes. All 20 local path-style Markdown links across `docs/` resolve to existing files.

### Flagged for Human Review

**Hook scripts on disk, not referenced in `.claude/settings.json` (14)** — may be intentionally dormant or pending registration; not auto-removed (skill never deletes scripts):
- `agent-trace-hook.sh`
- `ai-writing-guard-hook.sh`
- `frontend-security-nudge.sh`
- `lean-ctx-nudge-hook.sh`
- `pr-auto-create-hook.sh`
- `pr-mention-nudge.sh`
- `pre-tool-use-gitnexus.sh`
- `prompt-hook.sh`
- `raindrop-best-practices.sh`
- `reject-feedback-hook.sh`
- `scan-pii.sh`
- `skill-usage-tracker.sh`
- `tool-failure-capture.sh`
- `tool-failure-recall.sh`

Note: since the 2026-07-16 review, `action-capture.sh`, `address-check-hook.sh`, `setup-buffer-hook.sh`, and `skill-permissions-gate.sh` have been registered in `settings.json` and are now clean. The remaining 14 are new or still-unregistered — decide per script whether to register or retire. `tool-failure-capture.sh`/`tool-failure-recall.sh` still correspond to the `tool-failure-memory` skill per indexed memory; if that skill is meant to be live, it needs a hook registration.

**Docs tree is mirrored under `.claude/docs/`** — a parallel copy of `docs/` exists at `/home/dalesser/.claude/sdd-harness/.claude/docs/`. Only the canonical `docs/` tree (the skill's defined scope) was swept this run. If the mirror is authoritative or synced, confirm whether it also needs auditing.

### Clean (no drift found)

- **Memory index** — 11/11 MEMORY.md entries resolve; 0 orphaned memory files.
- **Registered hooks** — 22/22 hook references in `settings.json` point to scripts that exist on disk.
- **Doc links** — 20/20 local Markdown links across `docs/` resolve (0 unresolved).
