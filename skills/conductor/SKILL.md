---
name: conductor
description: Track-based spec-driven development system — slash commands for setup, new-track, implement, status, revert, and manage. Use when creating/working a Conductor track (spec.md/plan.md/metadata.json), running the TDD task loop, checking progress, or reverting/archiving tracks.
---

# Conductor

A `conductor/` directory holds project context + a registry of **tracks** (feature/bug/chore/refactor work units). Each track moves through Setup (once) → New Track → Implement (loop) → Status (anytime) → Revert/Manage (as needed).

## Directory layout
```
conductor/
├── index.md              # navigation hub
├── product.md             # vision, goals, target users (WHAT/WHY)
├── product-guidelines.md  # voice/tone, terminology (HOW to communicate)
├── tech-stack.md          # languages, frameworks, deps, infra (WITH WHAT)
├── workflow.md             # TDD policy, commit/review conventions (HOW to work)
├── tracks.md               # registry: Active / Completed / Archived tables
├── setup_state.json        # resumable /conductor:setup progress
├── code_styleguides/{lang}.md
└── tracks/<track-id>/
    ├── spec.md    # requirements + acceptance criteria
    ├── plan.md    # phases → tasks → verification
    ├── metadata.json
    └── index.md
```
Keep artifacts synchronized: new feature → check tech-stack.md for new deps; completed track → update product.md; workflow change → update affected plan.md files. Don't scatter info outside this structure (resist new doc types).

## Track ID format
`{shortname}_{YYYYMMDD}` — 2-4 word kebab-case + creation date, e.g. `user-auth_20250115`. Collision → numeric suffix.

## Status markers (tracks.md and plan.md both use these)
| Marker | Meaning |
|---|---|
| `[ ]` | Pending |
| `[~]` | In progress |
| `[x]` | Complete (plan.md: include commit SHA) |
| `[!]` | Blocked (note reason) |
| `[-]` | Skipped intentionally |

## /conductor:setup (once per project, or `--resume`)
1. Detect greenfield (no .git/package.json/etc.) vs brownfield (existing code — scan manifests first, pre-populate, ask for confirmation).
2. Interactive Q&A, **one question per turn**, offer 2-3 suggested answers + "type your own", max 5 questions per section. Sections: Product (name/description/problem/users/goals) → Guidelines (voice/tone, design principles) → Tech Stack (languages/frontend/backend/db/infra) → Workflow (TDD strictness, commit strategy, review policy, verification checkpoints) → Style guides (languages to generate).
3. Persist progress to `setup_state.json` after every answer; verify each file write before continuing.
4. Generate all files in Directory layout above. On `--resume`, skip completed sections, verify previously-written files still exist.

## /conductor:new-track
1. Pre-flight: conductor initialized, tracks.md readable.
2. Classify: feature / bug / chore / refactor — each has a distinct question set.
3. Interactive spec gathering: **one question per turn, wait for response, max 6 questions.**
4. Generate `spec.md`: Overview, Functional/Non-Functional Requirements (FR-1/NFR-1 style, each with Acceptance/Target+Verification), Acceptance Criteria checklist, In/Out of Scope, Dependencies (internal/external), Risks & Mitigations table, Open Questions. **Show user for review before proceeding.**
5. Generate `plan.md`: phases (Setup/Foundation → Core Implementation → Integration → Polish), each with Tasks (`- [ ] **Task N.M**: description`) and a Verification subsection, plus a Checkpoints table (phase / SHA / date / status). **Show user for review before proceeding.**
6. Create `conductor/tracks/{id}/` (spec.md, plan.md, metadata.json, index.md), register in `tracks.md` and `conductor/index.md`.
7. Track sizing guideline: 1-5 days, 2-4 phases, 8-20 tasks total. >5 phases/>25 tasks → split into multiple tracks; <2 tasks/no verification needed → fold into an existing track instead.

### metadata.json schema
```json
{
  "id": "user-auth_20250115", "title": "...", "type": "feature|bug|chore|refactor",
  "status": "pending|in-progress|completed", "created": "ISO", "updated": "ISO",
  "current_phase": 1, "phases": {"total": 3, "completed": 1},
  "tasks": {"total": 12, "completed": 5, "in_progress": 1, "pending": 6},
  "commits": [], "dependencies": [], "tags": []
}
```

## /conductor:implement {trackId}
1. Pre-flight checks → load track context (spec.md, plan.md, metadata.json) → update track status to in-progress.
2. **Task Execution Loop**, one task at a time: if TDD — write failing test (Red) → implement (Green) → refactor; else implement directly → verify.
3. **Task Completion**: mark `[x]` in plan.md, commit with message `{commit_prefix}: {task description} ({trackId})`, record SHA in metadata.json `commits[]`.
4. **Phase Completion Check — CRITICAL: wait for explicit user approval before starting the next phase.** Run the phase's verification tasks first.
5. **Error handling** (tool/test/git failure): HALT immediately, present numbered options to the user — never silently retry or skip.
6. **Track Completion**: final verification against all acceptance criteria, offer doc sync (product.md/tech-stack.md), offer cleanup (archive/delete/keep).
7. **Critical rules**: never skip a verification checkpoint; stop on any failure; follow workflow.md strictly; keep plan.md updated as you go, not in a batch at the end; commit frequently (one task = one commit); always record commit SHAs (needed for revert).

## /conductor:status [track-id] [--detailed|--quick|--json]
- No arg: overall progress (tracks X/Y, tasks X/Y, progress bar), track summary table, current focus (active track/phase/task), next actions, blockers.
- With track-id: that track's spec summary + acceptance criteria, phase-by-phase task breakdown with `<-- CURRENT` marker, related commits, next steps.
- Task counting: count `- [x]/[~]/[ ] Task` line markers per plan.md; current phase = first phase with any incomplete task.
- Blockers: tasks marked `BLOCKED:`/`[!]`, or dependencies on an incomplete track.
- Errors: missing `conductor/product.md` → tell user to run `/conductor:setup` first; unknown track-id → list available tracks.

## /conductor:revert
1. Pre-flight: git repo must be clean (stash/commit/cancel uncommitted changes first).
2. Target: `{trackId}` (whole track) / `{trackId}:phase{N}` / `{trackId}:task{X.Y}` / or a guided menu.
3. Discover commits via `git log --grep` on the track ID / task markers; **display the full execution plan (commits, in reverse-chronological order) and require explicit `YES`** — not `y`/`yes`/enter.
4. Execute with `git revert --no-edit {sha}` per commit, newest first.
5. **On merge conflict: HALT immediately — never auto-resolve.**
6. Update plan.md markers (`[x]`/`[~]` → `[ ]`) and track status; don't make this its own separate commit.
7. **Safety rules**: NEVER `git reset --hard`; NEVER `git push --force`; NEVER auto-resolve conflicts; ALWAYS show the full plan before acting; REQUIRE explicit `YES`; HALT on any error; PRESERVE history (revert, don't rewrite).

## /conductor:manage (archive / restore / delete / rename / cleanup / list)
- Verify `conductor/` structure first; confirm destructive actions (delete/cleanup) explicitly before applying.
- Back up track data before delete; never remove an archived track without explicit approval.
- Keep `tracks.md` and metadata consistent after every operation.

## /conductor:validator
Read the conductor directory structure and check: (1) required files present (`index.md`, `product.md`, `tech-stack.md`, `workflow.md`, `tracks.md`), (2) track IDs match `{shortname}_{YYYYMMDD}`, (3) status markers consistent (`[ ]`/`[~]`/`[x]`) across tracks.md and each plan.md. Report what exists, what's missing, what's malformed — don't silently fix.

## Context artifact discipline
- Before starting any track: read product.md/tech-stack.md/workflow.md, flag anything stale, propose updates before implementing against it.
- Adding a dependency: check existing deps solve the need first; document rationale + version constraint in tech-stack.md.
- Completing a feature: move it from planned→implemented in product.md.
- **Anti-patterns to avoid**: stale context (update it as part of track completion, not later), context sprawl (no new doc types outside the defined structure), implicit context (anything referenced repeatedly belongs in an artifact), context hoarding (review context changes like code changes), over-specification (keep it focused on what actually changes AI/team behavior).

## Session continuity
Start: read `index.md` → check `tracks.md` for active work → open that track's `plan.md` for the current task. End: update plan.md progress, note blockers, commit WIP with a clear status, update tracks.md if status changed. Interrupted mid-task: mark it `[~]` with a note on the stopping point rather than leaving it ambiguous.
