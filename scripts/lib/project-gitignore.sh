# shellcheck shell=bash
# =============================================================================
# project-gitignore.sh — keep harness-generated files out of a project's repo.
# =============================================================================
# Everything the harness writes into a project is regenerable output, not
# source: .claude/ and specs/ are rebuilt by install.sh / update.sh, CLAUDE.md
# is templated per project, AGENTS.md is written by `lean-ctx setup`, ERRORS.md
# is a per-machine failure log, and the editor/agent tool dirs are local state.
# None of it belongs in the project's history.
#
# Two halves, both enforced — no per-project opt-out:
#   1. every entry below is an active line in the project's .gitignore;
#   2. any of those paths git already tracks is untracked (`git rm --cached`),
#      because an ignore rule never untracks a file git already has. The files
#      stay on disk; the project's next commit records their removal.
#
# Both install.sh (first-time) and update.sh (every sync) call this, so a
# project installed before an entry was added picks it up on the next update.
#
# Usage:
#   . "$__here/scripts/lib/project-gitignore.sh"
#   ensure_gitignore "$PROJECT_DIR"
# =============================================================================

# The full local-only set. Add here and every installed project inherits it.
SDD_GITIGNORE_ENTRIES=(".claude/" "specs/" "CLAUDE.md" "AGENTS.md" "ERRORS.md"
                       ".cursor/" ".serena/" ".gitnexus/" ".worktrees/" ".mcp.json")

# Append any missing entries to <project_dir>/.gitignore, idempotently, then
# untrack any harness path the project's index still holds.
# A commented-out entry (`# .claude/`) does not count as present: it is not an
# opt-out, and the active line is appended after it.
# Always returns 0 — callers run under `set -e`, and "nothing to add" is the
# normal case on every re-run, not a failure.
ensure_gitignore() {
  local project_dir="$1"
  local gitignore="$project_dir/.gitignore"
  local entry added=false
  touch "$gitignore"
  for entry in "${SDD_GITIGNORE_ENTRIES[@]}"; do
    # Match the exact line to avoid false positives (e.g. ".claude/" vs ".claudeignore").
    if ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
      if [ "$added" = false ]; then
        # Separate from prior content with a blank line + header, once.
        [ -s "$gitignore" ] && printf '\n' >> "$gitignore"
        echo "# SDD harness — local-only, never committed" >> "$gitignore"
        added=true
      fi
      echo "$entry" >> "$gitignore"
    fi
  done
  if [ "$added" = true ]; then
    echo "  Added harness entries to .gitignore (${SDD_GITIGNORE_ENTRIES[*]})."
  fi
  untrack_harness_paths "$project_dir"
  return 0
}

# Remove every harness path from <project_dir>'s git index, keeping the files
# on disk. No-op outside a git work tree or when nothing harness is tracked.
untrack_harness_paths() {
  local project_dir="$1"
  local entry tracked total=0
  git -C "$project_dir" rev-parse --is-inside-work-tree > /dev/null 2>&1 || return 0
  for entry in "${SDD_GITIGNORE_ENTRIES[@]}"; do
    tracked="$(git -C "$project_dir" ls-files -- "$entry" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${tracked:-0}" -gt 0 ] || continue
    if git -C "$project_dir" rm -r --cached --quiet -- "$entry" > /dev/null 2>&1; then
      total=$((total + tracked))
    else
      echo "  WARNING: could not untrack $entry in $project_dir" >&2
    fi
  done
  if [ "$total" -gt 0 ]; then
    echo "  Untracked $total harness file(s) (kept on disk) — commit to record the removal."
  fi
  return 0
}
