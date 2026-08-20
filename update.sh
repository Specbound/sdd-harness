#!/bin/bash
# ──────────────────────────────────────────────────────────
# $SDD_HARNESS is set automatically by install.sh — no manual setup needed.
#
# Update all registered projects:
#   $SDD_HARNESS/update.sh
#
# Update a single project:
#   $SDD_HARNESS/update.sh /path/to/project
# ──────────────────────────────────────────────────────────
# Syncs harness files to all registered projects (or just one).
set -e

# Self-locate the harness root via the shared resolver — symlink/junction-safe,
# resolves to the real physical path, works on any machine/OS/clone location.
# Single source of truth: scripts/lib/resolve-harness-dir.sh. No hardcoded paths.
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/scripts/lib/resolve-harness-dir.sh"
. "$__here/scripts/lib/harness-pointer.sh"
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
  sync_dir "$HARNESS_DIR/rules"         "$proj/.claude"
  mkdir -p "$proj/.claude/memory/sessions"

  # --- Repair settings.json broken by the old template's trailing // comments ---
  # Claude Code parses settings.json as strict JSON; a malformed file loses every
  # permission rule and hook silently. Idempotent — valid files are left alone.
  if command -v python3 >/dev/null 2>&1; then
    python3 "$HARNESS_DIR/scripts/setup/repair-settings-json.py" "$proj" | grep -v '^OK ' || true
  fi
  if [ ! -f "$proj/.claude/settings.notes.md" ]; then
    cp "$HARNESS_DIR/templates/settings.notes.md.template" "$proj/.claude/settings.notes.md"
  fi

  # --- Reconcile the GitNexus managed block in CLAUDE.md ---
  # The block is committed; the .gitnexus/ index is gitignored and the MCP server
  # lives in local config. A fresh clone therefore inherits MUST/NEVER rules for
  # tools it cannot call. Strip the block when it is dead, repair it when it is
  # live. No-op for projects that never ran `gitnexus setup`.
  if [ -f "$HARNESS_DIR/scripts/setup/gitnexus-reconcile.sh" ]; then
    bash "$HARNESS_DIR/scripts/setup/gitnexus-reconcile.sh" "$proj" || true
  fi

  # --- Sync ALL hooks from canonical source ($HARNESS_DIR/hooks/claude/) ---
  # Every .sh in hooks/claude/ is propagated unconditionally to every project.
  # The harness is the source of truth; user-chosen wiring lives in settings.json.
  mkdir -p "$proj/.claude/hooks"
  for hook in "$HARNESS_DIR/hooks/claude/"*.sh; do
    [ -f "$hook" ] || continue
    name="$(basename "$hook")"
    cp "$hook" "$proj/.claude/hooks/$name"
    chmod +x "$proj/.claude/hooks/$name"
  done

  # --- chmod runtime scripts that need to be executable ---
  for s in orchestration/daily-runner.sh routines/macro-eval-runner.sh routines/skill-curator-runner.sh routines/harness-health-runner.sh routines/tool-failure-review-runner.sh routines/startup-payload-audit.sh routines/code-review-learning-runner.sh session/write_handoff.py pr/detect_base_and_create.sh; do
    [ -f "$proj/.claude/scripts/$s" ] && chmod +x "$proj/.claude/scripts/$s"
  done
  [ -f "$proj/.claude/scripts/utils/ollama_model_test.py" ] && chmod +x "$proj/.claude/scripts/utils/ollama_model_test.py"
  [ -f "$proj/.claude/scripts/integrations/blackhole/blackhole-cursor.py" ] && chmod +x "$proj/.claude/scripts/integrations/blackhole/blackhole-cursor.py"
  [ "$(uname)" = "Darwin" ] && xattr -cr "$proj/.claude/hooks/" 2>/dev/null || true
  if [ -d "$proj/.git" ]; then
    cp "$HARNESS_DIR/hooks/git/post-commit" "$proj/.git/hooks/"
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

  bash "$HARNESS_DIR/scripts/setup/generate-project-stack.sh" "$proj"
  date -Iseconds > "$proj/.claude/.last-harness-check"
  echo "  Done."
}

# --- Pre-ship gate: scan harness source for leaked secrets / over-broad perms ---
# Runs once before anything is copied into a target repo. A blocking finding
# (exit 1) aborts the whole update so secrets never propagate. Opt out with
# SDD_SKIP_SHIP_SCAN=1; tighten perm warnings to failures with SDD_SHIP_STRICT=1.
if [ "${SDD_SKIP_SHIP_SCAN:-0}" != "1" ] && [ -f "$HARNESS_DIR/scripts/lib/ship-safety-scan.sh" ]; then
  __scan_args=("$HARNESS_DIR")
  [ "${SDD_SHIP_STRICT:-0}" = "1" ] && __scan_args+=(--strict)
  if ! bash "$HARNESS_DIR/scripts/lib/ship-safety-scan.sh" "${__scan_args[@]}"; then
    echo "Aborting update — ship-safety scan failed. (Override: SDD_SKIP_SHIP_SCAN=1)" >&2
    exit 1
  fi
fi

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

# --- Persist harness root: THE single stored pointer to the harness ---
# Cross-repo hooks read this instead of having a path baked in. Rewritten on every
# update, so moving the harness and re-running update.sh heals every consumer.
write_harness_pointer "$HARNESS_DIR"
install_harness_pre_commit "$HARNESS_DIR"

# --- Export SDD_HARNESS to shell rc files so users can run scripts from anywhere ---
export SDD_HARNESS="$HARNESS_DIR"
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$rc" ]; then
    if grep -qF 'SDD_HARNESS=' "$rc"; then
      sed -i.bak "s|export SDD_HARNESS=.*|export SDD_HARNESS=\"$HARNESS_DIR\"|" "$rc" && rm -f "$rc.bak"
    else
      printf '\n# SDD Harness — set by update.sh; re-run if you move the repo\nexport SDD_HARNESS="%s"\n' "$HARNESS_DIR" >> "$rc"
    fi
    echo "  SDD_HARNESS set in $rc  ($HARNESS_DIR)"
  fi
done

# --- Sync harness's own .claude/ runtime from canonical sources ---
# hooks/claude/, scripts/, commands/kiro/, agents/, kiro/, docs/, rules/ are the
# canonical source of truth. The harness's runtime copy under .claude/ is regenerated
# each update — same six sync_dir targets every other registered project gets via
# do_update, just aimed at the harness's own .claude/ since do_update() itself
# deliberately skips the harness source (see guard above). Previously this block only
# synced scripts/, so .claude/agents/ and most of .claude/commands/kiro/ never existed
# here — Task-tool subagent_type lookups (skill-augment-agent, behavior-spec-agent, etc.)
# and slash commands were silently falling back to whatever short inline prompt text
# called them, not their full agents/kiro/*.md instructions.
for hook in "$HARNESS_DIR/hooks/claude/"*.sh; do
  [ -f "$hook" ] || continue
  name="$(basename "$hook")"
  cp "$hook" "$HARNESS_DIR/.claude/hooks/$name"
  chmod +x "$HARNESS_DIR/.claude/hooks/$name"
done
sync_dir "$HARNESS_DIR/commands/kiro" "$HARNESS_DIR/.claude/commands"
sync_dir "$HARNESS_DIR/agents"        "$HARNESS_DIR/.claude"
sync_dir "$HARNESS_DIR/kiro"          "$HARNESS_DIR/.claude"
# scripts/ is a nested directory — sync preserves subdirectory structure.
sync_dir "$HARNESS_DIR/scripts"       "$HARNESS_DIR/.claude"
sync_dir "$HARNESS_DIR/docs"          "$HARNESS_DIR/.claude"
sync_dir "$HARNESS_DIR/rules"         "$HARNESS_DIR/.claude"
find "$HARNESS_DIR/.claude/scripts" -name "*.sh" -exec chmod +x {} \;
[ "$(uname)" = "Darwin" ] && xattr -cr "$HARNESS_DIR/.claude/" 2>/dev/null || true

# Regenerate the harness's own settings.json from the template.
# Hook commands are `bash "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/x.sh"` — absolute when
# Claude Code exports CLAUDE_PROJECT_DIR, CWD-relative otherwise, machine-specific never.
# This block used to substitute {{HARNESS_DIR}} into an absolute path, which baked the
# install-time location into a generated file: moving the harness left 23 dead hook
# paths that failed silently, and check-no-hardcoded-paths.sh could not see them
# because it scanned neither JSON nor .claude/. Copy verbatim instead.
cp "$HARNESS_DIR/templates/settings.harness.json.template" \
  "$HARNESS_DIR/.claude/settings.json"
echo "  Harness settings.json regenerated (portable hook paths)."
bash "$HARNESS_DIR/scripts/setup/check-settings-json.sh" "$HARNESS_DIR/.claude/settings.json" \
  "$HARNESS_DIR/templates/settings.json.template" || \
  echo "  WARNING: settings JSON validation failed — see above."

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
        bash "$HARNESS_DIR/scripts/orchestration/setup-global-orchestrator.sh" || \
          echo "  WARNING: scheduled-task bootstrap returned non-zero."
      fi
      ;;
    macos)
      bash "$HARNESS_DIR/scripts/orchestration/setup-mac-orchestrator.sh" || \
        echo "  WARNING: launchd registration returned non-zero."
      ;;
    linux)
      bash "$HARNESS_DIR/scripts/orchestration/setup-linux-orchestrator.sh" || \
        echo "  WARNING: crontab registration returned non-zero."
      ;;
  esac
fi

# Refresh Raindrop Workshop wiring (env vars + venv installs) for all repos.
echo ""
echo "Refreshing Raindrop Workshop setup..."
bash "$HARNESS_DIR/scripts/setup/raindrop-setup.sh" || \
  echo "  WARNING: setup/raindrop-setup.sh returned non-zero — re-run manually if needed."

# Refresh headroom context compression wiring for all repos.
echo ""
echo "Refreshing headroom context compression setup..."
bash "$HARNESS_DIR/scripts/setup/headroom-setup.sh" || \
  echo "  WARNING: setup/headroom-setup.sh returned non-zero — re-run manually if needed."

# Refresh liteparse document parser install (owned in a dedicated >=3.10 venv).
echo ""
echo "Refreshing liteparse install..."
bash "$HARNESS_DIR/scripts/setup/liteparse-setup.sh" || \
  echo "  WARNING: liteparse setup returned non-zero — re-run manually: bash $HARNESS_DIR/scripts/setup/liteparse-setup.sh"

echo ""
echo "All projects updated to harness version $(cat "$HARNESS_DIR/VERSION")."
