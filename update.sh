#!/bin/bash
# Usage: update.sh [/path/to/project]
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
  cp    "$HARNESS_DIR/hooks/stop-hook.sh" "$proj/.claude/hooks/"
  chmod +x "$proj/.claude/hooks/stop-hook.sh"
  if [ -d "$proj/.git" ]; then
    cp "$HARNESS_DIR/git-hooks/post-commit" "$proj/.git/hooks/"
    chmod +x "$proj/.git/hooks/post-commit"
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
  while IFS= read -r project; do
    [ -n "$project" ] && do_update "$project"
  done < "$HARNESS_DIR/projects.txt"
fi

# Update harness VERSION to today
echo "$(date +%Y-%m-%d)" > "$HARNESS_DIR/VERSION"
echo ""
echo "All projects updated to harness version $(cat "$HARNESS_DIR/VERSION")."
