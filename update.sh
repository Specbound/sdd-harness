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

# Self-locate the harness root via the shared resolver — symlink/junction-safe,
# resolves to the real physical path, works on any machine/OS/clone location.
# Single source of truth: scripts/lib/resolve-harness-dir.sh. No hardcoded paths.
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/scripts/lib/resolve-harness-dir.sh"
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
  local src="${1%/}" dst_parent="$2"   # strip trailing slash: BSD cp dumps CONTENTS when src ends in /
  rm -rf "$dst_parent/$(basename "$src")"
  cp -r "$src" "$dst_parent/"
}

do_update() {
  local proj="$1"
  # Never run do_update on the harness source itself — its .claude/ is maintained
  # by the self-sync block at the tail of this script. Treating it as a target
  # repo makes file-onto-itself copies (e.g. impeccable-detect-hook.sh) abort
  # under `set -e`. Skip it whether listed by absolute or symlinked path.
  if [ "$(cd "$proj" 2>/dev/null && pwd -P)" = "$(cd "$HARNESS_DIR" 2>/dev/null && pwd -P)" ]; then
    echo "Skipping $proj — harness source (self-managed)."
    return
  fi
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

  # --- Sync ALL hooks from canonical source ($HARNESS_DIR/hooks/) ---
  # Every .sh in hooks/ is propagated unconditionally to every project.
  # The harness is the source of truth; user-chosen wiring lives in settings.json.
  for hook in "$HARNESS_DIR/hooks/"*.sh; do
    [ -f "$hook" ] || continue
    name="$(basename "$hook")"
    if [ "$name" = "stop-hook.sh" ]; then
      sed "s|{{HARNESS_DIR}}|$HARNESS_DIR|g" "$hook" > "$proj/.claude/hooks/$name"
    else
      cp "$hook" "$proj/.claude/hooks/$name"
    fi
    chmod +x "$proj/.claude/hooks/$name"
  done

  # --- chmod runtime scripts that need to be executable ---
  for s in daily-runner.sh macro-eval-runner.sh skill-curator-runner.sh harness-health-runner.sh tool-failure-review-runner.sh; do
    [ -f "$proj/.claude/scripts/$s" ] && chmod +x "$proj/.claude/scripts/$s"
  done
  [ -f "$proj/.claude/scripts/ollama_model_test.py" ] && chmod +x "$proj/.claude/scripts/ollama_model_test.py"
  [ "$(uname)" = "Darwin" ] && xattr -cr "$proj/.claude/hooks/" 2>/dev/null || true
  if [ -d "$proj/.git" ]; then
    cp "$HARNESS_DIR/git-hooks/post-commit" "$proj/.git/hooks/"
    chmod +x "$proj/.git/hooks/post-commit"
  fi
  # --- Sync harness skills + global commands (runs once per update, not per project) ---
  if [ "${_SDD_GLOBAL_SYNCED:-0}" != "1" ]; then
    if [ -d "$HARNESS_DIR/skills" ]; then
      mkdir -p "$HOME/.claude/skills"
      for skill_dir in "$HARNESS_DIR/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        sync_dir "${skill_dir%/}" "$HOME/.claude/skills"
      done
      echo "  Harness skills synced to ~/.claude/skills/"
    fi
    if [ -d "$HARNESS_DIR/commands/global" ]; then
      mkdir -p "$HOME/.claude/commands"
      for cmd_file in "$HARNESS_DIR/commands/global"/*.md; do
        [ -f "$cmd_file" ] || continue
        cp "$cmd_file" "$HOME/.claude/commands/"
      done
      echo "  Global commands synced to ~/.claude/commands/"
    fi
    export _SDD_GLOBAL_SYNCED=1
  fi

  bash "$HARNESS_DIR/generate-project-stack.sh" "$proj"
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

# --- Sync harness's own .claude/ runtime from canonical sources ---
# hooks/ and scripts/ are the canonical source of truth. The harness's runtime
# copy under .claude/ is regenerated each update so its own hooks/scripts cannot
# drift from the source. stop-hook.sh gets {{HARNESS_DIR}} substituted to an
# absolute path because Claude Code's hook runner does not set CWD.
for hook in "$HARNESS_DIR/hooks/"*.sh; do
  [ -f "$hook" ] || continue
  name="$(basename "$hook")"
  if [ "$name" = "stop-hook.sh" ]; then
    sed "s|{{HARNESS_DIR}}|$HARNESS_DIR|g" "$hook" > "$HARNESS_DIR/.claude/hooks/$name"
  else
    cp "$hook" "$HARNESS_DIR/.claude/hooks/$name"
  fi
  chmod +x "$HARNESS_DIR/.claude/hooks/$name"
done
# scripts/ is a flat directory sync — every script available in source is available at runtime.
sync_dir "$HARNESS_DIR/scripts" "$HARNESS_DIR/.claude"
for s in "$HARNESS_DIR/.claude/scripts/"*.sh; do
  [ -f "$s" ] && chmod +x "$s"
done
[ "$(uname)" = "Darwin" ] && xattr -cr "$HARNESS_DIR/.claude/" 2>/dev/null || true

# Regenerate the harness's own settings.json from the template.
# Substitutes {{HARNESS_DIR}} with the actual path so hook commands use absolute paths —
# Claude Code's hook runner does not set CWD to the project directory.
sed "s|{{HARNESS_DIR}}|$HARNESS_DIR|g" "$HARNESS_DIR/templates/settings.harness.json.template" \
  > "$HARNESS_DIR/.claude/settings.json"
echo "  Harness settings.json regenerated (paths resolved to $HARNESS_DIR)."

echo "$(date +%Y-%m-%d)" > "$HARNESS_DIR/VERSION"

# Self-register harness in projects.txt (idempotent) — same logic as install.sh.
touch "$HARNESS_DIR/projects.txt"
if ! grep -qF "$HARNESS_DIR" "$HARNESS_DIR/projects.txt" 2>/dev/null; then
  { echo "$HARNESS_DIR"; cat "$HARNESS_DIR/projects.txt"; } > "$HARNESS_DIR/projects.txt.tmp" \
    && mv "$HARNESS_DIR/projects.txt.tmp" "$HARNESS_DIR/projects.txt"
  echo "  Harness self-registered in projects.txt (first entry)."
fi

# Ensure daily orchestrator is registered (idempotent, OS-aware).
# Honors SDD_SKIP_ROUTINE=1 to opt out.
if [ "${SDD_SKIP_ROUTINE:-0}" != "1" ]; then
  case "$SDD_OS" in
    wsl|gitbash)
      if command -v schtasks.exe >/dev/null 2>&1; then
        bash "$HARNESS_DIR/scripts/setup-global-orchestrator.sh" || \
          echo "  WARNING: scheduled-task bootstrap returned non-zero."
      fi
      ;;
    macos)
      bash "$HARNESS_DIR/scripts/setup-mac-orchestrator.sh" || \
        echo "  WARNING: launchd registration returned non-zero."
      ;;
    linux)
      bash "$HARNESS_DIR/scripts/setup-linux-orchestrator.sh" || \
        echo "  WARNING: crontab registration returned non-zero."
      ;;
  esac
fi

# Refresh Raindrop Workshop wiring (env vars + venv installs) for all repos.
echo ""
echo "Refreshing Raindrop Workshop setup..."
bash "$HARNESS_DIR/scripts/raindrop-setup.sh" || \
  echo "  WARNING: raindrop-setup.sh returned non-zero — re-run manually if needed."

# Refresh headroom context compression wiring for all repos.
echo ""
echo "Refreshing headroom context compression setup..."
bash "$HARNESS_DIR/scripts/headroom-setup.sh" || \
  echo "  WARNING: headroom-setup.sh returned non-zero — re-run manually if needed."

echo ""
echo "All projects updated to harness version $(cat "$HARNESS_DIR/VERSION")."
