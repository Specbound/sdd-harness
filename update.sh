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

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------
detect_os() {
  case "$(uname -s 2>/dev/null)" in
    Darwin)           echo "macos"   ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi ;;
    MINGW*|MSYS*|CYGWIN*) echo "gitbash" ;;
    *)                echo "unknown" ;;
  esac
}
SDD_OS="$(detect_os)"

# ---------------------------------------------------------------------------
# sync_dir <src> <dst_parent>
# Copies src as dst_parent/$(basename src), replacing any prior copy.
# rm-then-copy avoids both the macOS BSD cp trailing-slash content-dump and
# the GNU cp double-nesting issue when the destination already exists.
# ---------------------------------------------------------------------------
sync_dir() {
  local src="$1" dst_parent="$2"
  rm -rf "$dst_parent/$(basename "$src")"
  cp -r "$src" "$dst_parent/"
}

do_update() {
  local proj="$1"
  if [ ! -d "$proj/.claude" ]; then
    echo "  WARNING: $proj has no .claude/ — skipping (run install.sh first)"
    return
  fi
  echo "Updating: $proj  (OS: $SDD_OS)"

  # --- One-time cleanup: remove files misplaced by the old trailing-slash cp bug ---
  # Script files that were dumped into .claude/ root instead of .claude/scripts/
  for item in "$HARNESS_DIR/scripts"/*; do
    [ -e "$item" ] || continue
    name="$(basename "$item")"
    [ "$name" = "__pycache__" ] && continue
    rm -rf "$proj/.claude/$name"
  done
  # Doc subdirs that were dumped into .claude/ root instead of .claude/docs/
  for item in "$HARNESS_DIR/docs"/*/; do
    [ -d "$item" ] || continue
    name="$(basename "$item")"
    case "$name" in memory|hooks) continue ;; esac  # legitimate .claude/ root dirs
    rm -rf "$proj/.claude/$name"
  done
  rm -rf "$proj/.claude/settings"  # was kiro/settings/ dumped at wrong level

  # --- Sync harness directories (portable across macOS, Linux, WSL, Git Bash) ---
  sync_dir "$HARNESS_DIR/commands/kiro" "$proj/.claude/commands"
  sync_dir "$HARNESS_DIR/agents"        "$proj/.claude"
  sync_dir "$HARNESS_DIR/kiro"          "$proj/.claude"
  sync_dir "$HARNESS_DIR/scripts"       "$proj/.claude"
  sync_dir "$HARNESS_DIR/docs"          "$proj/.claude"
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
  # --- Sync harness skills globally (runs once per update, not per project) ---
  if [ -d "$HARNESS_DIR/skills" ] && [ "${_SDD_SKILLS_SYNCED:-0}" != "1" ]; then
    mkdir -p "$HOME/.claude/skills"
    for skill_dir in "$HARNESS_DIR/skills"/*/; do
      [ -d "$skill_dir" ] || continue
      sync_dir "$skill_dir" "$HOME/.claude/skills"
    done
    export _SDD_SKILLS_SYNCED=1
    echo "  Harness skills synced to ~/.claude/skills/"
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

# Refresh Raindrop Workshop wiring (env vars + venv installs) for all repos.
echo ""
echo "Refreshing Raindrop Workshop setup..."
bash "$HARNESS_DIR/scripts/raindrop-setup.sh" || \
  echo "  WARNING: raindrop-setup.sh returned non-zero — re-run manually if needed."

echo ""
echo "All projects updated to harness version $(cat "$HARNESS_DIR/VERSION")."
