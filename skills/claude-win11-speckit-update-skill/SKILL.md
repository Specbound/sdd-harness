---
name: claude-win11-speckit-update-skill
description: Use when updating an existing GitHub SpecKit installation on Windows 11 without clobbering local customizations. Performs a hash-diff + 3-way merge against the upstream SpecKit release instead of a blind overwrite.
source: "https://github.com/NotMyself/claude-win11-speckit-update-skill"
risk: safe
---

# Claude Win11 SpecKit Update

## When to Use

Trigger when asked to update a local SpecKit installation (the GitHub SpecKit spec-driven-development toolkit) to a newer release, on Windows 11, where the local copy has been customized and a naive overwrite would lose those edits.

Do **not** use for a fresh SpecKit install — this skill is for updating an existing one safely.

## How It Works

A hash-diff + 3-way merge, not a copy-and-replace:
1. Hash every tracked file in the current local SpecKit install.
2. Compare against the hashes of the target upstream release.
3. Files unchanged locally (hash matches the old upstream release) are safe to overwrite outright.
4. Files that differ from both the old and new upstream release (i.e., locally customized) are 3-way merged: old-upstream vs. new-upstream vs. local, so local customizations survive unless they directly conflict with an upstream change.
5. Genuine conflicts are surfaced for manual resolution rather than silently resolved either direction.

## Command

`/speckit-updater` with flags:

| Flag | Purpose |
|------|---------|
| `--target <version>` | Upstream release/tag to update to (defaults to latest) |
| `--dry-run` | Show what would change without writing anything |
| `--force` | Skip the 3-way merge and overwrite (use only when local customizations are known to be disposable) |
| `--backup` | Snapshot the current install before applying changes |
| `--conflicts-only` | Re-run just the conflict-resolution step after a prior run left conflicts open |

## Caveats

- Upstream repo (`github/spec-kit`) was archived 2026-02-01 — this skill's behavior is verified against the last release before archival and cannot be re-checked against future SpecKit updates. If SpecKit resumes active development under a new home, re-verify the flag set and merge behavior before trusting this skill again.
- Always run `--dry-run` first on an install with any local customization — the merge is best-effort, not guaranteed conflict-free.
