#!/bin/bash
# Usage: install.sh [/path/to/project] [--with-gitnexus] [--skip-embeddings]
# Installs the SDD harness into a project directory.
# Optional: --with-gitnexus to configure GitNexus code intelligence integration.
set -e

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
WITH_GITNEXUS=false
SKIP_EMBEDDINGS=false

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
    --with-gitnexus) WITH_GITNEXUS=true ;;
    --skip-embeddings) SKIP_EMBEDDINGS=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

PROJECT_DIR="${POSITIONAL_ARGS[0]:-$(pwd)}"
PROJECT_DIR="$(realpath "$PROJECT_DIR")"

echo "Installing SDD harness into: $PROJECT_DIR  (OS: $SDD_OS)"

# --- Validate ---
if [ ! -d "$PROJECT_DIR/.git" ]; then
  echo "ERROR: $PROJECT_DIR is not a git repository."
  exit 1
fi

# --- Create directory structure (only dirs not managed by cp below) ---
mkdir -p "$PROJECT_DIR/.claude/hooks"
mkdir -p "$PROJECT_DIR/.claude/memory/meta/glacier"
mkdir -p "$PROJECT_DIR/.claude/memory/sessions"
mkdir -p "$PROJECT_DIR/.claude/docs"
mkdir -p "$PROJECT_DIR/.claude/steering"
mkdir -p "$PROJECT_DIR/.claude/commands"
mkdir -p "$PROJECT_DIR/specs"

# --- Copy harness files ---
sync_dir "$HARNESS_DIR/commands/kiro" "$PROJECT_DIR/.claude/commands"
sync_dir "$HARNESS_DIR/agents"        "$PROJECT_DIR/.claude"
sync_dir "$HARNESS_DIR/kiro"          "$PROJECT_DIR/.claude"
sync_dir "$HARNESS_DIR/scripts"       "$PROJECT_DIR/.claude"
sync_dir "$HARNESS_DIR/docs"          "$PROJECT_DIR/.claude"

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
# glacier/ is empty in the harness source; create it explicitly after kiro sync
mkdir -p "$PROJECT_DIR/.claude/kiro/settings/templates/memory/meta/glacier"

# --- Sync ALL hooks from canonical source ($HARNESS_DIR/hooks/) ---
# Every .sh in hooks/ is installed unconditionally — even hooks the user may not
# wire up immediately. The harness is the source of truth; mandatory propagation.
for hook in "$HARNESS_DIR/hooks/"*.sh; do
  [ -f "$hook" ] || continue
  name="$(basename "$hook")"
  if [ "$name" = "stop-hook.sh" ]; then
    sed "s|{{HARNESS_DIR}}|$HARNESS_DIR|g" "$hook" > "$PROJECT_DIR/.claude/hooks/$name"
  else
    cp "$hook" "$PROJECT_DIR/.claude/hooks/$name"
  fi
  chmod +x "$PROJECT_DIR/.claude/hooks/$name"
done

# --- chmod runtime scripts that need to be executable ---
for s in daily-runner.sh macro-eval-runner.sh skill-curator-runner.sh harness-health-runner.sh; do
  [ -f "$PROJECT_DIR/.claude/scripts/$s" ] && chmod +x "$PROJECT_DIR/.claude/scripts/$s"
done

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

# --- settings.json for target project (skip if exists) ---
if [ ! -f "$PROJECT_DIR/.claude/settings.json" ]; then
  cp "$HARNESS_DIR/templates/settings.json.template" "$PROJECT_DIR/.claude/settings.json"
  echo "  .claude/settings.json created from template — review and customize."
fi

# --- Regenerate harness's own settings.json with absolute paths ---
# Always regenerate so hook paths reflect the actual harness location on this machine.
sed "s|{{HARNESS_DIR}}|$HARNESS_DIR|g" "$HARNESS_DIR/templates/settings.harness.json.template" \
  > "$HARNESS_DIR/.claude/settings.json"
echo "  Harness settings.json generated (paths resolved to $HARNESS_DIR)."

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

# --- Raindrop Workshop setup (idempotent) ---
echo ""
echo "Setting up Raindrop Workshop tracing..."
if bash "$HARNESS_DIR/scripts/raindrop-setup.sh"; then
  :
else
  echo "  WARNING: raindrop-setup.sh returned non-zero."
  echo "  Re-run manually: bash $HARNESS_DIR/scripts/raindrop-setup.sh"
fi

# --- Optional: GitNexus integration ---
if [ "$WITH_GITNEXUS" = true ]; then
  echo ""
  echo "Setting up GitNexus code intelligence..."

  # Check if gitnexus is available
  if command -v gitnexus >/dev/null 2>&1 || npx gitnexus --version >/dev/null 2>&1; then
    # Index the repository
    ANALYZE_FLAGS=""
    if [ "$SKIP_EMBEDDINGS" = true ]; then
      ANALYZE_FLAGS="--skip-embeddings"
    fi

    if [ ! -d "$PROJECT_DIR/.gitnexus" ]; then
      echo "  Indexing repository with GitNexus..."
      (cd "$PROJECT_DIR" && npx gitnexus analyze $ANALYZE_FLAGS)
      echo "  Repository indexed."
    else
      echo "  Repository already indexed (.gitnexus/ exists)."
    fi

    # Add .gitnexus/ to .gitignore
    if ! grep -qF '.gitnexus/' "$PROJECT_DIR/.gitignore" 2>/dev/null; then
      echo "" >> "$PROJECT_DIR/.gitignore"
      echo "# GitNexus index (local, regenerable)" >> "$PROJECT_DIR/.gitignore"
      echo ".gitnexus/" >> "$PROJECT_DIR/.gitignore"
      echo "  Added .gitnexus/ to .gitignore."
    fi

    # Add MCP server config to settings.json if not already present
    if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
      if ! grep -q '"gitnexus"' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null; then
        # Use python/node to merge JSON safely, or notify user
        echo "  NOTE: Add GitNexus MCP server to .claude/settings.json:"
        echo '    "mcpServers": { "gitnexus": { "command": "npx", "args": ["-y", "gitnexus", "mcp"] } }'
        echo "  Or run /kiro:gitnexus-setup inside Claude Code for automatic configuration."
      else
        echo "  GitNexus MCP already configured in settings.json."
      fi
    fi

    # Register editor integration
    (cd "$PROJECT_DIR" && npx gitnexus setup 2>/dev/null) || true
    echo "  GitNexus editor integration registered."
  else
    echo "  WARNING: gitnexus not found. Install with: npm install -g gitnexus"
    echo "  Skipping GitNexus setup. Run /kiro:gitnexus-setup later inside Claude Code."
  fi
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

# --- Remind user about local daily maintenance ---
PROJECT_NAME="$(basename "$PROJECT_DIR")"
if [ "${SDD_SKIP_ROUTINE:-0}" != "1" ]; then
  echo ""
  echo "  ┌─ Local Daily Maintenance ──────────────────────────────────────────────┐"
  echo "  │ This repo's daily runner is installed at:                              │"
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
