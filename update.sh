#!/bin/bash
# ──────────────────────────────────────────────────────────
# Update all registered projects:
#   ~/.claude/sdd-harness/update.sh
#
# Update a single project:
#   ~/.claude/sdd-harness/update.sh /path/to/project
# ──────────────────────────────────────────────────────────
# Syncs harness files to all registered projects (or just one).
set -e

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"

do_update() {
  local proj="$1"
  if [ ! -d "$proj/.claude" ]; then
    echo "  WARNING: $proj has no .claude/ — skipping (run install.sh first)"
    return
  fi
  echo "Updating: $proj"
  cp -r "$HARNESS_DIR/commands/" "$proj/.claude/"
  cp -r "$HARNESS_DIR/agents/"   "$proj/.claude/"
  cp -r "$HARNESS_DIR/kiro/"     "$proj/.claude/"
  cp -r "$HARNESS_DIR/scripts/"  "$proj/.claude/"
  cp -r "$HARNESS_DIR/docs/"     "$proj/.claude/"
  mkdir -p "$proj/.claude/memory/sessions"
  cp    "$HARNESS_DIR/hooks/stop-hook.sh"              "$proj/.claude/hooks/"
  cp    "$HARNESS_DIR/hooks/session-start-hook.sh"    "$proj/.claude/hooks/"
  cp    "$HARNESS_DIR/hooks/pre-tool-use-gitnexus.sh" "$proj/.claude/hooks/"
  cp    "$HARNESS_DIR/hooks/revert-detect-hook.sh"    "$proj/.claude/hooks/"
  cp    "$HARNESS_DIR/.claude/hooks/impeccable-detect-hook.sh" "$proj/.claude/hooks/"
  chmod +x "$proj/.claude/hooks/stop-hook.sh"
  chmod +x "$proj/.claude/hooks/session-start-hook.sh"
  chmod +x "$proj/.claude/hooks/pre-tool-use-gitnexus.sh"
  chmod +x "$proj/.claude/hooks/revert-detect-hook.sh"
  chmod +x "$proj/.claude/hooks/impeccable-detect-hook.sh"
  if [ -d "$proj/.git" ]; then
    cp "$HARNESS_DIR/git-hooks/post-commit" "$proj/.git/hooks/"
    chmod +x "$proj/.git/hooks/post-commit"
  fi
  bash "$HARNESS_DIR/generate-project-stack.sh" "$proj"
  # Remind to register Routine if not already done (opt-out via SDD_SKIP_ROUTINE=1)
  if [ "${SDD_SKIP_ROUTINE:-0}" != "1" ]; then
    local pname
    pname="$(basename "$proj")"
    echo "  Reminder: run /kiro:setup-routine in Claude Code to ensure nightly Routine is registered for $pname."
  fi
  date -Iseconds > "$proj/.claude/.last-harness-check"
  echo "  Done."
}

if [ -n "$TARGET" ]; then
  do_update "$(realpath "$TARGET")"
else
  if [ ! -s "$HARNESS_DIR/projects.txt" ]; then
    echo "No registered projects. Run install.sh in a project first."
    exit 0
  fi
  while IFS= read -r project || [ -n "$project" ]; do
    [ -n "$project" ] && do_update "$project"
  done < "$HARNESS_DIR/projects.txt"
fi

# Update harness VERSION to today
echo "$(date +%Y-%m-%d)" > "$HARNESS_DIR/VERSION"

# Ensure global Windows scheduled task is registered (idempotent — skips if it
# already exists). Honors SDD_SKIP_ROUTINE=1 to opt out.
if [ "${SDD_SKIP_ROUTINE:-0}" != "1" ] && command -v schtasks.exe >/dev/null 2>&1; then
  bash "$HARNESS_DIR/scripts/setup-global-orchestrator.sh" || \
    echo "  WARNING: scheduled-task bootstrap returned non-zero."
fi

echo ""
echo "All projects updated to harness version $(cat "$HARNESS_DIR/VERSION")."
