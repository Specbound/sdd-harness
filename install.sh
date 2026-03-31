#!/bin/bash
# Usage: install.sh [/path/to/project]
# Installs the SDD harness into a project directory.
set -e

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="$(realpath "$PROJECT_DIR")"

echo "Installing SDD harness into: $PROJECT_DIR"

# --- Validate ---
if [ ! -d "$PROJECT_DIR/.git" ]; then
  echo "ERROR: $PROJECT_DIR is not a git repository."
  exit 1
fi

# --- Create directory structure ---
mkdir -p "$PROJECT_DIR/.claude/commands/kiro"
mkdir -p "$PROJECT_DIR/.claude/agents/kiro"
mkdir -p "$PROJECT_DIR/.claude/kiro/settings/rules"
mkdir -p "$PROJECT_DIR/.claude/kiro/settings/templates/memory/meta/glacier"
mkdir -p "$PROJECT_DIR/.claude/kiro/settings/templates/specs"
mkdir -p "$PROJECT_DIR/.claude/kiro/settings/templates/steering"
mkdir -p "$PROJECT_DIR/.claude/kiro/settings/templates/steering-custom"
mkdir -p "$PROJECT_DIR/.claude/hooks"
mkdir -p "$PROJECT_DIR/.claude/memory/meta/glacier"
mkdir -p "$PROJECT_DIR/.claude/memory/sessions"
mkdir -p "$PROJECT_DIR/.claude/docs"
mkdir -p "$PROJECT_DIR/.claude/scripts"
mkdir -p "$PROJECT_DIR/.claude/steering"
mkdir -p "$PROJECT_DIR/specs"

# --- Copy harness files ---
cp -r "$HARNESS_DIR/commands/" "$PROJECT_DIR/.claude/"
cp -r "$HARNESS_DIR/agents/"   "$PROJECT_DIR/.claude/"
cp -r "$HARNESS_DIR/kiro/"     "$PROJECT_DIR/.claude/"
cp -r "$HARNESS_DIR/scripts/"  "$PROJECT_DIR/.claude/"
cp    "$HARNESS_DIR/hooks/stop-hook.sh" "$PROJECT_DIR/.claude/hooks/"
chmod +x "$PROJECT_DIR/.claude/hooks/stop-hook.sh"

# --- Set up git post-commit hook ---
cp "$HARNESS_DIR/git-hooks/post-commit" "$PROJECT_DIR/.git/hooks/"
chmod +x "$PROJECT_DIR/.git/hooks/post-commit"
echo "  Git post-commit hook installed."

# --- Bootstrap memory from templates (skip if already initialized) ---
TEMPLATE_MEM="$HARNESS_DIR/kiro/settings/templates/memory"
if [ ! -f "$PROJECT_DIR/.claude/memory/hot-memory.md" ]; then
  cp "$TEMPLATE_MEM/hot-memory.md"             "$PROJECT_DIR/.claude/memory/"
  cp "$TEMPLATE_MEM/observations.md"           "$PROJECT_DIR/.claude/memory/"
  cp "$TEMPLATE_MEM/action-items.md"           "$PROJECT_DIR/.claude/memory/"
  cp "$TEMPLATE_MEM/entities.md"               "$PROJECT_DIR/.claude/memory/"
  cp "$TEMPLATE_MEM/meta/patterns.md"          "$PROJECT_DIR/.claude/memory/meta/"
  cp "$TEMPLATE_MEM/meta/self-observations.md" "$PROJECT_DIR/.claude/memory/meta/" 2>/dev/null || true
  echo "  Memory files initialized."
fi

# --- CLAUDE.md template (skip if exists) ---
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  cp "$HARNESS_DIR/templates/CLAUDE.md.template" "$PROJECT_DIR/CLAUDE.md"
  echo "  CLAUDE.md created from template — customize for your project."
fi

# --- settings.json template (skip if exists) ---
if [ ! -f "$PROJECT_DIR/.claude/settings.json" ]; then
  cp "$HARNESS_DIR/templates/settings.json.template" "$PROJECT_DIR/.claude/settings.json"
  echo "  .claude/settings.json created from template — review and customize."
fi

# --- Record install timestamp ---
date -Iseconds > "$PROJECT_DIR/.claude/.last-harness-check"

# --- Register project ---
if ! grep -qF "$PROJECT_DIR" "$HARNESS_DIR/projects.txt" 2>/dev/null; then
  echo "$PROJECT_DIR" >> "$HARNESS_DIR/projects.txt"
  echo "  Registered in $HARNESS_DIR/projects.txt"
fi

echo ""
echo "SDD harness installed successfully."
echo ""
echo "Next steps:"
echo "  1. Add to .gitignore: .claude/ specs/ CLAUDE.md (keep .claude/settings.local.json)"
echo "  2. Customize CLAUDE.md with your project name and context"
echo "  3. Run /kiro:steering to bootstrap project memory"
