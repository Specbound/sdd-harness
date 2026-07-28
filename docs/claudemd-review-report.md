# CLAUDE.md Review Report — 2026-07-26

## Summary
- Repos checked: 6
- Inaccessible: 0
- Clean: 1
- Minor issues: 0
- Needs update: 5

## Findings

### sdd-harness — needs-update
- `.claude/rules/lean-ctx.md` documents a `ctx_read`/`ctx_search`/`ctx_shell`/`ctx_edit`/`ctx_overview`/`ctx_compose`/`ctx_semantic_search`/`ctx_compress`/`ctx_knowledge`/`ctx_impact`/`ctx_callgraph`/`ctx_session` API (21 references) as if these were directly callable tools, and mandates "NEVER use native Read/Grep/Shell when ctx_* equivalents are available." Verified: no MCP server or tool registration exposes any `ctx_*` function — the only real artifact is the `lean-ctx` CLI binary (`/opt/homebrew/bin/lean-ctx`, v3.9.10), invoked via `Bash("lean-ctx ...")`, and a `PostToolUse(Read)` nudge hook that prints `ctx_read(...)`-style suggestions as a hint, not a working call. As written, the rule is unfollowable — there is no `ctx_read` to call. Fix: either rewrite the rule to shell out through `lean-ctx <subcommand>` via Bash, or drop the "NEVER use native..." mandate to a soft preference.
- Root `CLAUDE.md`'s "Serena (Python code intelligence — mandatory, not optional)" section requires `mcp__serena__get_diagnostics_for_file` and `mcp__serena__find_referencing_symbols` before any Python edit/rename. Verified: no `serena` binary anywhere on `PATH`, and no MCP server registration for Serena exists in `.claude/settings*.json`. Same failure mode as lean-ctx — a hard "mandatory" instruction pointing at nothing.
- Everything else (plan-before-code, atomic commits, spec review gate, `ruff`/`pytest` quality gates) still matches how this repo is actually used — no drift there.

### daa-llm-evaluation — needs-update
- Root `CLAUDE.md` and `.claude/CLAUDE.md` have diverged into two ~200-line near-duplicates that now **contradict each other** on remote infrastructure:
  - Root: *"Models run on GB10 (hostname: `gx10-c326`) via Tailscale VPN... Models located in `/models` on GB10."*
  - `.claude/CLAUDE.md`: *"Fine-tuning runs on the A100 80GB (SSH alias: `kolagt-u`, IP `10.111.111.4`, user `dlesser@flytrucks.com`)... Models located in `~/models/hf-direct`..."*
  - Different host, different IP/SSH alias, different model path. Whichever copy gets read first will send Claude to the wrong machine.
  - Root also has a "Knowledge System" section (the `knowledge/` note vault) that `.claude/CLAUDE.md` lacks entirely, and the two files' `rag_metrics` descriptions differ by one field ("override precision" present in `.claude/CLAUDE.md`, absent from root).
  - This is the same fork-and-drift pattern flagged in the 2026-07-16 review and it has not been resolved — recommend collapsing to one canonical file (delete the other, or reduce it to a one-line pointer) rather than hand-syncing two copies going forward.

### caresync-vercel — needs-update
- Root `CLAUDE.md`'s H1 is still the unfilled harness template placeholder: `# {{PROJECT_NAME}}` — never substituted with `caresync-vercel`.
- "Quality Gates" section mandates `ruff check` on every `.py` file write and `pytest -x --ignore=tests/integration` after each impl task — this is a Next.js/TypeScript project (`package.json`, `tsconfig.json`, no `pyproject.toml`, no Python present). These gates are dead instructions carried over unmodified from the (Python-oriented) harness template; same finding as the 2026-07-16 review, still unfixed.
- "Context Resources" table points at `.claude/docs/SDD-USAGE.md`, which does not exist in this repo (verified). `hot-memory.md`, `meta/patterns.md`, and `specs/` do exist, so only this one path is dead.

### whisper-pipeline — clean
- Fully project-specific, detailed, no template placeholders, no dead paths, no pre-4.x hand-holding. GitNexus block matches the indexed repo name. No action needed.

### video-automation — needs-update
- Root `CLAUDE.md` has the same unfilled `# {{PROJECT_NAME}}` placeholder and the same dangling `.claude/docs/SDD-USAGE.md` reference (missing, verified) as caresync-vercel — both look seeded from the same harness template with the placeholder swap skipped.
- `.claude/CLAUDE.md` (the file with the actual project instructions) has a "WORKFLOW RULES" section that is heavy pre-Claude-4.x micromanagement, unchanged since the last review:
  - "After creating each file, show me its contents so I can review before you continue" / "Do not create multiple files at once without showing me each one" — a stop-and-show gate per file.
  - "Add docstrings to every class and public method" / "Add type hints to every function signature" — blanket style mandate regardless of triviality.
  - "Before starting each phase, tell me... After each phase, give me a summary" — a rigid narration ritual that duplicates what current Claude already does contextually.
  - Not necessarily wrong if the user genuinely wants tight control on this experimental pipeline, but it reads as an artifact of an earlier, more failure-prone model generation. Worth confirming with the user whether it's still wanted here.

### TTS — needs-update
- Root `CLAUDE.md` ("pilot_sim") is otherwise a mature, well-maintained, project-specific document, but it has an internal self-contradiction that has persisted since the 2026-07-16 review:
  - "Read first" table + "Pronunciation lexicon" section state the per-scenario lexicon (`scenarios/<name>/*lexicon*.json`) is the primary mechanism and `data/he_lexicon.json` is "a legacy fallback only."
  - The closing "When working in this repo" section still instructs: *"Hebrew pronunciation overrides go in `data/he_lexicon.json`, not in code"* and *"Scenarios live as plain unvocalized Hebrew in `scenarios/he/`"* — pointing at the legacy global-fallback path and a `scenarios/he/` directory that doesn't match the actual per-scenario folder layout (`scenarios/<name>/`) documented everywhere else in the same file.
  - Following the closing section's instructions literally would mean editing the deprecated fallback lexicon instead of the per-scenario one — worth fixing so the last section agrees with the rest of the file.
