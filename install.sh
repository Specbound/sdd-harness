#!/bin/bash
# =============================================================================
# SDD Harness Installer
# =============================================================================
# Installs the SDD harness into one project or every project in projects.txt.
#
# IMPORTANT: this is a bash script. On Windows it does NOT run from PowerShell
# or CMD directly:
#   - running the .sh             -> "Missing expression after unary operator '!'"
#   - "~/.claude/.../install.sh"  -> "not recognized as the name of a cmdlet"
# The reliable fix on Windows is to run it through Git Bash (see PowerShell
# section below), or just open a Git Bash terminal and run the plain commands.
#
# -----------------------------------------------------------------------------
# COPY-PASTE COMMANDS
# -----------------------------------------------------------------------------
# Single project (Git Bash / WSL2 / macOS / Linux):
#   ~/.claude/sdd-harness/install.sh /path/to/project
#   ~/.claude/sdd-harness/install.sh                      # current directory
#   ~/.claude/sdd-harness/install.sh /path/to/project --with-gitnexus
#
# All registered projects (skips ones already installed — .claude/kiro/ present):
#   ~/.claude/sdd-harness/install.sh --all
#   ~/.claude/sdd-harness/install.sh --all --force        # re-sync EVERY project
#   ~/.claude/sdd-harness/install.sh --all --with-gitnexus
#   ~/.claude/sdd-harness/install.sh --all --with-gitnexus --skip-embeddings
#
# From Windows PowerShell, invoke Git Bash with the call operator (&) and a
# full path to bash.exe. `bash` is usually NOT on the PowerShell PATH, and `~`
# is not expanded as an argument, so use a relative/concrete script path:
#   # run from inside the sdd-harness repo directory:
#   & "C:\Program Files\Git\bin\bash.exe" install.sh --all --with-gitnexus
#   # or with an explicit project (note /c/... style path for bash):
#   & "C:\Program Files\Git\bin\bash.exe" install.sh /c/dev/my-project --with-gitnexus
#   # one-off from anywhere (let bash expand ~ via -c):
#   & "C:\Program Files\Git\bin\bash.exe" -c "~/.claude/sdd-harness/install.sh --all"
#
# -----------------------------------------------------------------------------
# ARGUMENTS & FLAGS
# -----------------------------------------------------------------------------
#   (no path)         install into the current directory
#   /path/to/project  install into that project
#   --all             install into every project listed in projects.txt,
#                     skipping any that already have the harness (.claude/kiro/)
#   --force           with --all: re-sync even projects already installed
#                     (use this to roll out harness updates everywhere)
#   --with-gitnexus   configure GitNexus code intelligence integration
#   --skip-embeddings pass --skip-embeddings to GitNexus indexing (faster)
# =============================================================================
set -e

# Self-locate the harness root via the shared resolver — symlink/junction-safe,
# resolves to the real physical path, works on any machine/OS/clone location.
# Single source of truth: scripts/lib/resolve-harness-dir.sh. No hardcoded paths.
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/scripts/lib/resolve-harness-dir.sh"
WITH_GITNEXUS=false
SKIP_EMBEDDINGS=false   # legacy no-op: GitNexus 1.6.5 has embeddings OFF by default
WITH_EMBEDDINGS=false   # opt-in to semantic-search embeddings during indexing
ALL=false
FORCE=false

# ---------------------------------------------------------------------------
# OS detection — used for platform-specific behaviour throughout this script.
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
#
# Why not plain `cp -r src/ dst/`?
#   macOS (BSD cp): trailing slash on the source dumps the *contents* of src
#   into dst instead of creating dst/src/. Linux/WSL/Git Bash (GNU cp) do not
#   have this problem, but they do double-nest when dst/src already exists.
#   rm-then-copy is idempotent and identical across all platforms.
# ---------------------------------------------------------------------------
sync_dir() {
  local src="${1%/}" dst_parent="$2"   # strip trailing slash: BSD cp dumps CONTENTS when src ends in /
  rm -rf "$dst_parent/$(basename "$src")"
  cp -r "$src" "$dst_parent/"
}

# Parse arguments — positional first, then flags
POSITIONAL_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --with-gitnexus)   WITH_GITNEXUS=true ;;
    --skip-embeddings) SKIP_EMBEDDINGS=true ;;   # no-op (kept for back-compat)
    --with-embeddings) WITH_EMBEDDINGS=true ;;
    --all)             ALL=true ;;
    --force)           FORCE=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

# ===========================================================================
# install_project <PROJECT_DIR>
# Per-project installation. Returns non-zero on failure instead of exiting,
# so --all can continue to the next project. Machine-global steps (skills,
# global commands, harness settings regen, raindrop, OS orchestrator) live
# OUTSIDE this function and run once — see install_globals.
# ===========================================================================
install_project() {
  local PROJECT_DIR
  PROJECT_DIR="$(realpath "$1")" || { echo "ERROR: cannot resolve path: $1"; return 1; }

  echo "Installing SDD harness into: $PROJECT_DIR  (OS: $SDD_OS)"

  # --- Validate ---
  if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "ERROR: $PROJECT_DIR is not a git repository."
    return 1
  fi

  # --- Create directory structure (only dirs not managed by cp below) ---
  mkdir -p "$PROJECT_DIR/.claude/hooks"
  mkdir -p "$PROJECT_DIR/.claude/memory/meta/glacier"
  mkdir -p "$PROJECT_DIR/.claude/memory/sessions"
  mkdir -p "$PROJECT_DIR/.claude/docs"
  mkdir -p "$PROJECT_DIR/.claude/steering"
  mkdir -p "$PROJECT_DIR/.claude/commands"
  mkdir -p "$PROJECT_DIR/specs"

  # --- chmod runtime scripts that need to be executable ---
  for s in daily-runner.sh macro-eval-runner.sh skill-curator-runner.sh harness-health-runner.sh tool-failure-review-runner.sh; do
    [ -f "$PROJECT_DIR/.claude/scripts/$s" ] && chmod +x "$PROJECT_DIR/.claude/scripts/$s"
  done
  [ -f "$PROJECT_DIR/.claude/scripts/ollama_model_test.py" ] && chmod +x "$PROJECT_DIR/.claude/scripts/ollama_model_test.py"

  # --- Copy harness files ---
  sync_dir "$HARNESS_DIR/commands/kiro" "$PROJECT_DIR/.claude/commands"
  sync_dir "$HARNESS_DIR/agents"        "$PROJECT_DIR/.claude"
  sync_dir "$HARNESS_DIR/kiro"          "$PROJECT_DIR/.claude"
  sync_dir "$HARNESS_DIR/scripts"       "$PROJECT_DIR/.claude"
  sync_dir "$HARNESS_DIR/docs"          "$PROJECT_DIR/.claude"

  # glacier/ is empty in the harness source; create it explicitly after kiro sync
  mkdir -p "$PROJECT_DIR/.claude/kiro/settings/templates/memory/meta/glacier"

  # --- Sync ALL hooks from canonical source ($HARNESS_DIR/hooks/) ---
  # Every .sh in hooks/ is installed unconditionally — even hooks the user may not
  # wire up immediately. The harness is the source of truth; mandatory propagation.
  for hook in "$HARNESS_DIR/hooks/"*.sh; do
    [ -f "$hook" ] || continue
    local name
    name="$(basename "$hook")"
    if [ "$name" = "stop-hook.sh" ]; then
      sed "s|{{HARNESS_DIR}}|$HARNESS_DIR|g" "$hook" > "$PROJECT_DIR/.claude/hooks/$name"
    else
      cp "$hook" "$PROJECT_DIR/.claude/hooks/$name"
    fi
    chmod +x "$PROJECT_DIR/.claude/hooks/$name"
  done

  # --- chmod runtime scripts that need to be executable ---
  local s
  for s in daily-runner.sh macro-eval-runner.sh skill-curator-runner.sh harness-health-runner.sh tool-failure-review-runner.sh; do
    [ -f "$PROJECT_DIR/.claude/scripts/$s" ] && chmod +x "$PROJECT_DIR/.claude/scripts/$s"
  done

  # --- Set up git post-commit hook ---
  cp "$HARNESS_DIR/git-hooks/post-commit" "$PROJECT_DIR/.git/hooks/"
  chmod +x "$PROJECT_DIR/.git/hooks/post-commit"
  echo "  Git post-commit hook installed."

  # --- Bootstrap memory from templates (skip if already initialized) ---
  local TEMPLATE_MEM="$HARNESS_DIR/kiro/settings/templates/memory"
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

  # --- settings.json for target project (skip if exists) ---
  if [ ! -f "$PROJECT_DIR/.claude/settings.json" ]; then
    cp "$HARNESS_DIR/templates/settings.json.template" "$PROJECT_DIR/.claude/settings.json"
    echo "  .claude/settings.json created from template — review and customize."
  fi

  # --- Generate project stack summary (used by agents to understand the codebase) ---
  bash "$HARNESS_DIR/generate-project-stack.sh" "$PROJECT_DIR" || \
    echo "  WARNING: generate-project-stack.sh returned non-zero — stack file may be missing."

  # --- Record install timestamp ---
  date -Iseconds > "$PROJECT_DIR/.claude/.last-harness-check"

  # --- Register project ---
  if ! grep -qF "$PROJECT_DIR" "$HARNESS_DIR/projects.txt" 2>/dev/null; then
    echo "$PROJECT_DIR" >> "$HARNESS_DIR/projects.txt"
    echo "  Registered in $HARNESS_DIR/projects.txt"
  fi

  # --- Optional: GitNexus integration (per-project) ---
  if [ "$WITH_GITNEXUS" = true ]; then
    echo ""
    echo "Setting up GitNexus code intelligence..."

    if command -v gitnexus >/dev/null 2>&1 || npx gitnexus --version >/dev/null 2>&1; then
      # GitNexus 1.6.5: embeddings are OFF by default (the legacy --skip-embeddings
      # flag no longer exists). Pass --embeddings only when explicitly requested.
      local ANALYZE_FLAGS=""
      [ "$WITH_EMBEDDINGS" = true ] && ANALYZE_FLAGS="--embeddings"

      # GitNexus is a native (Node/Windows) tool. Launched from MSYS2/Git Bash it
      # misreads an MSYS-style cwd ("/c/...") as "Not a git repository", so pass an
      # explicit NATIVE path via cygpath when available. No-op on macOS/Linux.
      local GN_PATH="$PROJECT_DIR"
      command -v cygpath >/dev/null 2>&1 && GN_PATH="$(cygpath -w "$PROJECT_DIR")"

      if [ ! -d "$PROJECT_DIR/.gitnexus" ]; then
        echo "  Indexing repository with GitNexus..."
        (cd "$PROJECT_DIR" && npx gitnexus analyze "$GN_PATH" $ANALYZE_FLAGS)
        echo "  Repository indexed."
      else
        echo "  Repository already indexed (.gitnexus/ exists)."
      fi

      if ! grep -qF '.gitnexus/' "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        echo "" >> "$PROJECT_DIR/.gitignore"
        echo "# GitNexus index (local, regenerable)" >> "$PROJECT_DIR/.gitignore"
        echo ".gitnexus/" >> "$PROJECT_DIR/.gitignore"
        echo "  Added .gitnexus/ to .gitignore."
      fi

      if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
        if ! grep -q '"gitnexus"' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null; then
          echo "  NOTE: Add GitNexus MCP server to .claude/settings.json:"
          echo '    "mcpServers": { "gitnexus": { "command": "npx", "args": ["-y", "gitnexus", "mcp"] } }'
          echo "  Or run /kiro:gitnexus-setup inside Claude Code for automatic configuration."
        else
          echo "  GitNexus MCP already configured in settings.json."
        fi
      fi

      (cd "$PROJECT_DIR" && npx gitnexus setup 2>/dev/null) || true
      echo "  GitNexus editor integration registered."
    else
      echo "  WARNING: gitnexus not found. Install with: npm install -g gitnexus"
      echo "  Skipping GitNexus setup. Run /kiro:gitnexus-setup later inside Claude Code."
    fi
  fi
}

# ===========================================================================
# install_globals
# Machine-wide setup that must run exactly once regardless of how many
# projects are installed: harness skills, global commands, the harness's own
# settings.json, Raindrop tracing, and the OS-level daily orchestrator.
# ===========================================================================
install_globals() {
  # --- Install harness skills globally ---
  if [ -d "$HARNESS_DIR/skills" ]; then
    mkdir -p "$HOME/.claude/skills"
    for skill_dir in "$HARNESS_DIR/skills"/*/; do
      [ -d "$skill_dir" ] || continue
      sync_dir "${skill_dir%/}" "$HOME/.claude/skills"
    done
    echo "  Harness skills installed to ~/.claude/skills/"
  fi

  # --- Install global commands ---
  if [ -d "$HARNESS_DIR/commands/global" ]; then
    mkdir -p "$HOME/.claude/commands"
    for cmd_file in "$HARNESS_DIR/commands/global"/*.md; do
      [ -f "$cmd_file" ] || continue
      cp "$cmd_file" "$HOME/.claude/commands/"
    done
    echo "  Global commands installed to ~/.claude/commands/"
  fi

  # --- Regenerate harness's own settings.json with absolute paths ---
  # Always regenerate so hook paths reflect the actual harness location on this machine.
  sed "s|{{HARNESS_DIR}}|$HARNESS_DIR|g" "$HARNESS_DIR/templates/settings.harness.json.template" \
    > "$HARNESS_DIR/.claude/settings.json"
  echo "  Harness settings.json generated (paths resolved to $HARNESS_DIR)."

  # --- Raindrop Workshop setup (idempotent) ---
  echo ""
  echo "Setting up Raindrop Workshop tracing..."
  if bash "$HARNESS_DIR/scripts/raindrop-setup.sh"; then
    :
  else
    echo "  WARNING: raindrop-setup.sh returned non-zero."
    echo "  Re-run manually: bash $HARNESS_DIR/scripts/raindrop-setup.sh"
  fi

  # --- Headroom context compression setup (idempotent) ---
  echo ""
  echo "Setting up headroom context compression..."
  if bash "$HARNESS_DIR/scripts/headroom-setup.sh"; then
    :
  else
    echo "  WARNING: headroom-setup.sh returned non-zero."
    echo "  Re-run manually: bash $HARNESS_DIR/scripts/headroom-setup.sh"
  fi

  # --- Self-register harness in projects.txt (idempotent) ---
  # Harness-specific runners (skill-curator, harness-health, macro-eval) guard
  # themselves with a docs/scheduled-tasks check — they only run in the harness
  # repo. Without this entry they exit 0 immediately in every non-harness project.
  touch "$HARNESS_DIR/projects.txt"
  if ! grep -qF "$HARNESS_DIR" "$HARNESS_DIR/projects.txt" 2>/dev/null; then
    { echo "$HARNESS_DIR"; cat "$HARNESS_DIR/projects.txt"; } > "$HARNESS_DIR/projects.txt.tmp" \
      && mv "$HARNESS_DIR/projects.txt.tmp" "$HARNESS_DIR/projects.txt"
    echo "  Harness self-registered in projects.txt (first entry)."
  fi

  # --- Auto-register daily orchestrator (idempotent, OS-aware) ---
  if [ "${SDD_SKIP_ROUTINE:-0}" != "1" ]; then
    case "$SDD_OS" in
      wsl|gitbash)
        if command -v schtasks.exe >/dev/null 2>&1; then
          bash "$HARNESS_DIR/scripts/setup-global-orchestrator.sh" || \
            echo "  WARNING: scheduled-task bootstrap returned non-zero; daily orchestrator may not be registered."
        fi
        ;;
      macos)
        bash "$HARNESS_DIR/scripts/setup-mac-orchestrator.sh" || \
          echo "  WARNING: launchd registration returned non-zero; daily orchestrator may not be registered."
        ;;
      linux)
        bash "$HARNESS_DIR/scripts/setup-linux-orchestrator.sh" || \
          echo "  WARNING: crontab registration returned non-zero; daily orchestrator may not be registered."
        ;;
    esac
  fi
}

# ===========================================================================
# print_maintenance_reminder — printed once at the end of any install run.
# ===========================================================================
print_maintenance_reminder() {
  if [ "${SDD_SKIP_ROUTINE:-0}" != "1" ]; then
    echo ""
    echo "  ┌─ Local Daily Maintenance ──────────────────────────────────────────────┐"
    echo "  │ Each repo's daily runner is installed at:                              │"
    echo "  │   .claude/scripts/daily-runner.sh                                      │"
    echo "  │                                                                        │"
    echo "  │ It runs the daily-maintenance + session-quality + keep-rate pipeline.  │"
    echo "  │                                                                        │"
    echo "  │ Trigger paths (both automatic):                                        │"
    echo "  │   1. OS scheduler — fires daily at 18:00 local across ALL repos:       │"
    echo "  │        macOS   : launchd LaunchAgent (~/Library/LaunchAgents/)         │"
    echo "  │        WSL     : Windows Task Scheduler (schtasks.exe)                 │"
    echo "  │        Linux   : crontab (crontab -l)                                  │"
    echo "  │      Registered automatically on first install per platform.           │"
    echo "  │   2. SessionStart hook — if >24h since last run, fires the runner in   │"
    echo "  │      the background when you open Claude in this repo.                 │"
    echo "  │                                                                        │"
    echo "  │ Disable per-repo: rm .claude/scripts/daily-runner.sh                   │"
    echo "  │ Disable globally (macOS): launchctl unload -w                          │"
    echo "  │   ~/Library/LaunchAgents/com.sdd.daily-orchestrator.plist              │"
    echo "  │ Disable globally (WSL): schtasks.exe /Delete /TN \"SDD Daily\"          │"
    echo "  │ Disable globally (Linux): crontab -e  # remove sdd-daily-orchestrator  │"
    echo "  └────────────────────────────────────────────────────────────────────────┘"
  fi
}

# ===========================================================================
# Main
# ===========================================================================
if [ "$ALL" = true ]; then
  PROJECTS_FILE="$HARNESS_DIR/projects.txt"
  if [ ! -f "$PROJECTS_FILE" ]; then
    echo "ERROR: $PROJECTS_FILE not found — nothing to install into."
    exit 1
  fi

  echo "Batch install from $PROJECTS_FILE"
  echo ""

  installed=0 skipped=0 failed=0
  while IFS= read -r line || [ -n "$line" ]; do
    # skip blank lines and comments
    [ -z "${line// }" ] && continue
    case "$line" in \#*) continue ;; esac

    if [ ! -d "$line" ]; then
      echo "  SKIP (missing): $line"
      failed=$((failed + 1))
      continue
    fi

    # Skip already-installed projects unless --force
    if [ "$FORCE" != true ] && [ -d "$line/.claude/kiro" ]; then
      echo "  SKIP (installed): $line"
      # Per-project flags only take effect when the project is actually installed.
      # Warn loudly so --with-gitnexus is never silently dropped on a skipped repo.
      if [ "$WITH_GITNEXUS" = true ]; then
        echo "    NOTE: --with-gitnexus has NO effect here (project skipped)."
        echo "          Re-run with --force to (re)configure GitNexus on installed repos."
      fi
      skipped=$((skipped + 1))
      continue
    fi

    if install_project "$line"; then
      installed=$((installed + 1))
    else
      echo "  FAILED: $line — continuing"
      failed=$((failed + 1))
    fi
    echo ""
  done < "$PROJECTS_FILE"

  install_globals

  echo ""
  echo "Batch install complete: $installed installed, $skipped skipped, $failed failed."
  print_maintenance_reminder
else
  PROJECT_DIR="${POSITIONAL_ARGS[0]:-$(pwd)}"
  install_project "$PROJECT_DIR"
  install_globals
  print_maintenance_reminder
fi

echo ""
echo "SDD harness installed successfully."
echo ""
echo "Next steps:"
echo "  1. Add to .gitignore: .claude/ specs/ CLAUDE.md (keep .claude/settings.local.json)"
echo "  2. Customize CLAUDE.md with your project name and context"
echo "  3. Run /kiro:steering to bootstrap project memory"
if [ "$WITH_GITNEXUS" = false ]; then
  echo ""
  echo "Optional: Run with --with-gitnexus to add code intelligence integration."
  echo "  Or run /kiro:gitnexus-setup inside Claude Code later."
fi
# Check for raindrop CLI in common locations (subshell may not have full PATH)
if command -v raindrop >/dev/null 2>&1 || [ -x "$HOME/.raindrop/bin/raindrop" ]; then
  echo "  Raindrop Workshop CLI: installed."
else
  echo ""
  echo "Raindrop Workshop CLI not found. Install it once with:"
  echo "  bash ~/.claude/sdd-harness/bootstrap.sh --skip-rtk --skip-gitnexus --skip-impeccable --skip-uv --skip-opf"
  echo "  (or manually: curl -fsSL https://raindrop.sh/install | bash)"
fi
