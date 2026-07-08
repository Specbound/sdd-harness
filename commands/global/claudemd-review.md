---
description: Audit the current repo's CLAUDE.md and AGENTS.md for bloat, stale rules, inferable filler, and duplication — rate each file, write a report, and stamp the bi-weekly review date
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
argument-hint: "[--apply]  (default: propose only)"
---

# CLAUDE.md Review

Audit the **current repository's** always-loaded instruction files against a lean-context rubric, rate them, write a findings report, and stamp the review date so the bi-weekly `session-start-hook.sh` reminder resets.

This command is fired automatically by `session-start-hook.sh` when `.claude/memory/.last-claudemd-review` is >14 days stale (the `[CLAUDEMD-REVIEW-DUE]` reminder). It also runs on demand. It is the **per-repo** counterpart to the harness-health-runner routine, which audits *all* registered repos into `docs/claudemd-review-report.md` — do not confuse the two or write to that file.

## Invocation context

- **Hook-invoked (silent):** the reminder says "run silently, before responding." Do the audit, write the report, stamp the date, and surface at most a one-line summary to the user (or nothing if all clean). Do NOT apply edits.
- **User-invoked (`/claudemd-review`):** print the full summary. Apply edits only with `--apply` (see Edit Policy).

## Scope — which files

Audit, in the current repo:
1. Root `CLAUDE.md`
2. Root `AGENTS.md`
3. Any nested `**/CLAUDE.md` and `**/AGENTS.md` (use Glob; skip `node_modules`, `.git`, `vendor`)

Do **not** audit the global `~/.claude/CLAUDE.md` here (it is not repo-scoped and the state file is per-repo). If a user explicitly asks to review the global file, do it as a one-off outside this command's stamp.

If a file does not exist, note it and move on. A repo with only a one-line `@AGENTS.md` in CLAUDE.md is the *ideal* state, not a finding.

## Rubric — apply every dimension to every file

| Dimension | Falsifiable check | Verdict weight |
|---|---|---|
| **Size budget** | `wc -l` > 200 lines → flag. Report the exact line count for every file. | needs-update if >200; minor if 150–200 |
| **Inferable from repo** | Any line stating the tech stack, framework names, or versions that are already in `package.json` / `pyproject.toml` / `Cargo.toml` / lockfiles → flag. The model reads these; restating them is pure token cost. | minor each; needs-update if 3+ |
| **Generic filler** | "Write clean code", "follow best practices", "use good naming", "handle errors properly" and similar advice that does not change a decision → flag. If a line would be true in every repo on earth, it earns nothing here. | minor each |
| **Duplication vs import** | A project `CLAUDE.md` that restates content also in `AGENTS.md` (or vice versa) instead of importing via a single `@AGENTS.md` line → flag; recommend the one-line import (`@AGENTS.md`) or a symlink (`ln -s AGENTS.md CLAUDE.md`). Also flag intra-file duplication (same instruction in two sections). | minor; needs-update if the bulk of the file duplicates | 
| **Stale model-assumption** | Rules premised on small context windows or pre-Claude-4.x behavior — e.g. "keep context under N%", aggressive `/compact` thresholds, "the model can't do X" where current models can → flag as stale. | minor each |
| **Over-constraining** | Blanket approval-gates or step-by-step micro-management applied to *all* tasks where model judgment suffices (e.g. "show 2-3 approaches before any task") → flag; suggest narrowing to the case that actually needs it. | minor each |
| **Signal test** | For any surviving line, ask: does this change what the agent does next? If not, it is filler → flag. | minor |

Never flag a line just because it is a strong project-specific instruction (an `## Address` convention, a scar-tissue safety rail, a canonical path). Those are exactly what earns its slot. The cut list targets filler, duplication, and staleness — not signal.

## Workflow

1. **Locate** the files (Glob). For each, capture `wc -l`.
2. **Read** each file fully.
3. **Cross-reference** the repo: read `package.json` / `pyproject.toml` / other manifests once, so you can tell which "stack" lines are inferable.
4. **Score** each file: `clean` (no findings) / `minor` (findings, none block) / `needs-update` (>200 lines OR 3+ inferable lines OR bulk duplication).
5. **Write the report** to `.claude/memory/claudemd-review-report.md` (per-repo — NOT `docs/`). Use the format below.
6. **Stamp** the date: `date +%F > .claude/memory/.last-claudemd-review`.
7. **Summarize** per invocation context (silent one-liner when hook-invoked; full summary when user-invoked).

## Report format

Write `.claude/memory/claudemd-review-report.md`:

```markdown
# CLAUDE.md Review Report — <YYYY-MM-DD>

## Summary
- Files checked: N
- Clean: N | Minor: N | Needs update: N
- Largest file: <path> (<lines> lines)

## Findings

### <path> — <clean|minor|needs-update> (<lines> lines)
- **<dimension>:** <quoted line or location> — <why it fails + concrete fix>
- ...
(one block per file; write "No findings." for clean files)

## Proposed Changes
Proposals only — not applied unless `--apply` was passed.
### <path>
```diff
- <line to cut or change>
+ <replacement, if any>
```
```

## Edit Policy

- **Default: propose only.** Write the diffs into the report; do not touch the instruction files.
- **`--apply`:** apply only *unambiguous, low-risk* fixes — removing an exact intra-file duplicate line, deleting a line that merely restates the manifest stack, replacing a stale threshold with the report's suggested wording. Never delete a project-specific instruction, safety rail, or convention on `--apply`; leave those as proposals for the human. After applying, re-run `wc -l` and note the new size in the report.
- Respect the harness rule: significant restructuring goes through the human review gate, never auto-applied.

## Output contract

- `.claude/memory/claudemd-review-report.md` written.
- `.claude/memory/.last-claudemd-review` stamped with today's date (`date +%F`) — this is what silences the hook for 14 days. Do not skip it, even when every file is clean.
