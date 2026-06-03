#!/bin/bash
# bootstrap.sh — First-time machine setup for the SDD harness.
#
# Usage:
#   bootstrap.sh                          # check/install global tools only
#   bootstrap.sh /path/to/project         # also install harness into a project
#   bootstrap.sh /path/to/project --yes   # non-interactive (install everything)
#   bootstrap.sh --skip-rtk --skip-opf   # skip specific tools
#
# Flags:
#   --yes / -y        Non-interactive: answer "yes" to every install prompt
#   --with-gitnexus   Index the project repo with GitNexus during install
#   --skip-rtk        Skip RTK token-compression setup
#   --skip-gitnexus   Skip GitNexus install
#   --skip-impeccable Skip impeccable install
#   --skip-uv         Skip uv install
#   --skip-opf        Skip opf install
#   --skip-power-tools  Skip ripgrep/fd/jq install
set -e

# Self-locate the harness root via the shared resolver — symlink/junction-safe,
# resolves to the real physical path, works on any machine/OS/clone location.
# Single source of truth: scripts/lib/resolve-harness-dir.sh. No hardcoded paths.
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/scripts/lib/resolve-harness-dir.sh"

# ── Parse arguments ──────────────────────────────────────────────────────────
PROJECT_DIR=""
YES=false
WITH_GITNEXUS=false
SKIP_RTK=false
SKIP_GITNEXUS=false
SKIP_WORKSHOP=false
SKIP_IMPECCABLE=false
SKIP_UV=false
SKIP_OPF=false
SKIP_POWER_TOOLS=false

for arg in "$@"; do
  case "$arg" in
    --yes|-y)              YES=true ;;
    --with-gitnexus)       WITH_GITNEXUS=true ;;
    --skip-rtk)            SKIP_RTK=true ;;
    --skip-gitnexus)       SKIP_GITNEXUS=true ;;
    --skip-workshop)       SKIP_WORKSHOP=true ;;
    --skip-impeccable)     SKIP_IMPECCABLE=true ;;
    --skip-uv)             SKIP_UV=true ;;
    --skip-opf)            SKIP_OPF=true ;;
    --skip-power-tools)    SKIP_POWER_TOOLS=true ;;
    --*)               echo "Unknown flag: $arg" >&2; exit 1 ;;
    *)                 PROJECT_DIR="$arg" ;;
  esac
done

# ── OS detection ─────────────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s 2>/dev/null)" in
    Darwin)  echo "macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi ;;
    MINGW*|MSYS*|CYGWIN*) echo "gitbash" ;;
    *) echo "unknown" ;;
  esac
}
OS="$(detect_os)"

# Detect CPU architecture (for Zig/tool downloads)
ARCH="$(uname -m 2>/dev/null || echo x86_64)"
case "$ARCH" in
  arm64|aarch64) ARCH="aarch64" ;;
  *)             ARCH="x86_64"  ;;
esac

# ── Colour helpers ────────────────────────────────────────────────────────────
if [ -t 1 ]; then   # only use colour when stdout is a terminal
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
  CYAN='\033[0;36m';  BOLD='\033[1m';      NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; CYAN=''; BOLD=''; NC=''
fi

ok()      { echo -e "${GREEN}  ✓  $*${NC}"; }
info()    { echo -e "${CYAN}  ▸  $*${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠  $*${NC}"; }
err()     { echo -e "${RED}  ✗  $*${NC}"; }
section() { echo; echo -e "${BOLD}${CYAN}── $* ──────────────────────────────────────${NC}"; }

confirm() {
  # Returns 0 (proceed) or 1 (skip).
  [ "$YES" = true ] && return 0
  local resp
  printf "%s [y/N] " "$1"
  read -r resp </dev/tty
  case "$resp" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ── Header ────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}╔════════════════════════════════════════════════════╗"
echo -e "║        SDD Harness — First-Time Bootstrap          ║"
echo -e "╚════════════════════════════════════════════════════╝${NC}"
echo "  OS: $OS ($ARCH)"
[ -n "$PROJECT_DIR" ] && echo "  Project: $PROJECT_DIR"
[ "$YES" = true ]     && echo "  Mode: non-interactive (--yes)"
echo

# ── Step 0: Prerequisites ─────────────────────────────────────────────────────
section "Step 0: Prerequisites"

PREREQ_FAIL=false
for tool in claude node git; do
  if command -v "$tool" >/dev/null 2>&1; then
    ver="$($tool --version 2>&1 | head -1)"
    ok "$tool  ($ver)"
  else
    err "$tool not found"
    PREREQ_FAIL=true
  fi
done

if [ "$PREREQ_FAIL" = true ]; then
  echo
  warn "One or more prerequisites are missing. Install them and re-run."
  warn "  claude : npm install -g @anthropic-ai/claude-code  (or download the installer)"
  warn "  node   : https://nodejs.org"
  warn "  git    : https://git-scm.com"
  exit 1
fi

# ── Step 0b: Power tools (ripgrep, fd, jq) ───────────────────────────────────
section "Step 0b: Power Tools (ripgrep · fd · jq)"
# These tools dramatically improve Claude's file search speed and JSON parsing.
# When present, Claude uses them automatically instead of slower find/grep/cat.

if [ "$SKIP_POWER_TOOLS" = true ]; then
  warn "Skipping power tools  (--skip-power-tools)"
else
  POWER_MISSING=()
  for tool in rg fd jq; do
    if command -v "$tool" >/dev/null 2>&1; then
      ver="$($tool --version 2>&1 | head -1)"
      ok "$tool  ($ver)"
    else
      warn "$tool not found"
      POWER_MISSING+=("$tool")
    fi
  done

  if [ "${#POWER_MISSING[@]}" -gt 0 ]; then
    case "$OS" in
      macos)
        install_map=( ["rg"]="ripgrep" ["fd"]="fd" ["jq"]="jq" )
        brew_pkgs=()
        for t in "${POWER_MISSING[@]}"; do
          brew_pkgs+=("${install_map[$t]:-$t}")
        done
        if confirm "Install missing power tools via Homebrew? (${brew_pkgs[*]})"; then
          brew install "${brew_pkgs[@]}"
          ok "Power tools installed"
        else
          warn "Skipped power tools"
        fi
        ;;
      linux|wsl)
        apt_map=( ["rg"]="ripgrep" ["fd"]="fd-find" ["jq"]="jq" )
        apt_pkgs=()
        for t in "${POWER_MISSING[@]}"; do
          apt_pkgs+=("${apt_map[$t]:-$t}")
        done
        if confirm "Install missing power tools via apt? (${apt_pkgs[*]})"; then
          sudo apt-get install -y "${apt_pkgs[@]}"
          # fd-find installs as 'fdfind' on Ubuntu; create alias if needed
          if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
            ok "fd symlinked from fdfind"
          fi
          ok "Power tools installed"
        else
          warn "Skipped power tools"
        fi
        ;;
      *)
        warn "Unknown OS — install manually: ripgrep, fd, jq"
        ;;
    esac
  fi
fi

# ── Step 1: RTK ───────────────────────────────────────────────────────────────
section "Step 1: RTK (Bash output token compression)"

if [ "$SKIP_RTK" = true ]; then
  warn "Skipping RTK  (--skip-rtk)"
elif command -v rtk >/dev/null 2>&1; then
  ok "RTK already installed  ($(rtk --version 2>&1 | head -1))"
  info "Re-wiring global hook to ensure it's active..."
  rtk init -g --auto-patch 2>/dev/null && ok "Global hook active" || warn "rtk init -g failed — run it manually"
else
  case "$OS" in
    macos|linux|wsl)
      if confirm "Install RTK via Homebrew?"; then
        brew install rtk
        rtk init -g --auto-patch
        ok "RTK installed and global hook wired"
      else
        warn "Skipped RTK"
      fi
      ;;

    gitbash)
      warn "RTK on Windows native: install via winget or use WSL2."
      warn "Skipping RTK on Git Bash."
      ;;

    *)
      warn "Unknown OS — skipping RTK. Install manually per FIRST-TIME-SETUP.md."
      ;;
  esac
fi

# ── Step 2: GitNexus ──────────────────────────────────────────────────────────
section "Step 2: GitNexus (code intelligence)"

if [ "$SKIP_GITNEXUS" = true ]; then
  warn "Skipping GitNexus  (--skip-gitnexus)"
elif command -v gitnexus >/dev/null 2>&1; then
  ok "GitNexus already installed  ($(gitnexus --version 2>&1 | head -1))"
elif npx gitnexus --version >/dev/null 2>&1; then
  ok "GitNexus available via npx"
else
  if confirm "Install GitNexus globally?  (npm install -g gitnexus)"; then
    npm install -g gitnexus
    ok "GitNexus installed"
  else
    warn "Skipped GitNexus"
  fi
fi

# ── Step 2b: Raindrop Workshop (local dev instrumentation) ───────────────────
section "Step 2b: Raindrop Workshop"

if [ "$SKIP_WORKSHOP" = true ]; then
  warn "Skipping Raindrop Workshop  (--skip-workshop)"
elif command -v raindrop >/dev/null 2>&1; then
  ok "Raindrop Workshop already installed"
else
  case "$OS" in
    gitbash)
      warn "Raindrop Workshop install requires bash with curl. Run from WSL2 or macOS."
      ;;
    *)
      if confirm "Install Raindrop Workshop?"; then
        # Download first, then run — piping curl directly into bash fails for this
        # script because it uses set -euo pipefail and reads a manifest mid-stream.
        local _tmp
        _tmp="$(mktemp /tmp/raindrop-install-XXXXXX.sh)"
        curl -fsSL https://raindrop.sh/install -o "$_tmp"
        bash "$_tmp"
        rm -f "$_tmp"

        # Ensure ~/.raindrop/bin is on PATH for this session and future ones
        export PATH="$HOME/.raindrop/bin:$PATH"
        for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
          if [ -f "$rc" ] && ! grep -qF '.raindrop/bin' "$rc"; then
            echo 'export PATH="$HOME/.raindrop/bin:$PATH"' >> "$rc"
            info "Added ~/.raindrop/bin to PATH in $rc"
          fi
        done

        command -v raindrop >/dev/null 2>&1 \
          && ok "Raindrop Workshop installed  ($(raindrop --version 2>&1))" \
          || warn "raindrop binary not found after install — check ~/.raindrop/bin"
      else
        warn "Skipped Raindrop Workshop"
      fi
      ;;
  esac
fi

# ── Step 3: impeccable ────────────────────────────────────────────────────────
section "Step 3: impeccable (frontend design QA hook)"

if [ "$SKIP_IMPECCABLE" = true ]; then
  warn "Skipping impeccable  (--skip-impeccable)"
elif command -v impeccable >/dev/null 2>&1; then
  ok "impeccable already installed"
else
  if confirm "Install impeccable globally?  (npm install -g impeccable)"; then
    npm install -g impeccable
    ok "impeccable installed"
  else
    warn "Skipped impeccable"
  fi
fi

# ── Step 4: uv ───────────────────────────────────────────────────────────────
section "Step 4: uv (Python package manager)"

if [ "$SKIP_UV" = true ]; then
  warn "Skipping uv  (--skip-uv)"
elif command -v uv >/dev/null 2>&1; then
  ok "uv already installed  ($(uv --version 2>&1))"
else
  if confirm "Install uv?"; then
    case "$OS" in
      macos|linux|wsl)
        curl -LsSf https://astral.sh/uv/install.sh | sh
        # Source the env file uv's installer drops, so uv is immediately usable
        for env_file in "$HOME/.cargo/env" "$HOME/.local/bin/env"; do
          [ -f "$env_file" ] && source "$env_file" && break
        done
        export PATH="$HOME/.local/bin:$PATH"
        ok "uv installed"
        ;;
      gitbash)
        warn "Run this from PowerShell to install uv on Windows:"
        warn "  powershell -ExecutionPolicy BypassPolicy -c \"irm https://astral.sh/uv/install.ps1 | iex\""
        ;;
    esac
  else
    warn "Skipped uv"
  fi
fi

# ── Step 5: opf (PII / secrets scanning) ─────────────────────────────────────
section "Step 5: opf (PII scanning)"

if [ "$SKIP_OPF" = true ]; then
  warn "Skipping opf  (--skip-opf)"
elif command -v opf >/dev/null 2>&1; then
  ok "opf already installed"
else
  if confirm "Install opf?  (downloads ~600MB model weights on first use)"; then
    if command -v uv >/dev/null 2>&1; then
      uv pip install opf && ok "opf installed via uv"
    elif command -v pip >/dev/null 2>&1; then
      pip install opf   && ok "opf installed via pip"
    else
      err "Neither uv nor pip found — install uv first, then: uv pip install opf"
    fi
  else
    warn "Skipped opf"
  fi
fi

# ── Step 6: Per-project harness install ───────────────────────────────────────
# bootstrap.sh lives only in the harness — it is NOT copied to individual repos.
# When a project path is passed, install into that one repo only.
# When none is passed, install into every project registered in projects.txt.
section "Step 6: Per-project harness install"

PROJECTS_FILE="$HARNESS_DIR/projects.txt"

run_install() {
  local proj="$1"
  if [ ! -d "$proj" ]; then
    warn "Directory not found: $proj  (skipping)"
    return
  fi
  # Always index GitNexus during bootstrap (the dashboard needs it per-repo)
  bash "$HARNESS_DIR/install.sh" "$proj" --with-gitnexus
}

index_gitnexus() {
  # Index any registered repo that doesn't have a .gitnexus/ directory yet.
  # Called after the install loop so repos installed in this run are also covered.
  [ -s "$PROJECTS_FILE" ] || return
  local indexed=0 skipped=0
  while IFS= read -r proj || [ -n "$proj" ]; do
    [ -n "$proj" ] || continue
    if [ ! -d "$proj" ]; then
      warn "Directory not found: $proj  (skipping GitNexus index)"
      continue
    fi
    if [ -d "$proj/.gitnexus" ]; then
      ok "$(basename "$proj")  already indexed"
      skipped=$((skipped+1))
    else
      info "Indexing $(basename "$proj")..."
      (cd "$proj" && npx gitnexus analyze) \
        && ok "$(basename "$proj")  indexed" \
        || warn "$(basename "$proj")  index failed — run /kiro:gitnexus-setup inside Claude Code"
      indexed=$((indexed+1))
    fi
  done < "$PROJECTS_FILE"
  echo "  $indexed repo(s) indexed, $skipped already had an index."
}

if [ -n "$PROJECT_DIR" ]; then
  # Explicit path — install into that one project only
  PROJECT_DIR="$(realpath "$PROJECT_DIR")"
  info "Target: $PROJECT_DIR"
  if confirm "Install SDD harness into $PROJECT_DIR?"; then
    run_install "$PROJECT_DIR"
  else
    warn "Skipped"
    warn "Run later:  $HARNESS_DIR/install.sh $PROJECT_DIR"
  fi

elif [ -s "$PROJECTS_FILE" ]; then
  # No path given — install into every project in projects.txt
  COUNT=0
  while IFS= read -r p || [ -n "$p" ]; do [ -n "$p" ] && COUNT=$((COUNT+1)); done < "$PROJECTS_FILE"
  info "Found $COUNT registered project(s) in $PROJECTS_FILE:"
  while IFS= read -r p || [ -n "$p" ]; do
    [ -n "$p" ] && echo "    • $p"
  done < "$PROJECTS_FILE"
  echo
  if confirm "Install/update harness on all $COUNT projects?"; then
    while IFS= read -r proj || [ -n "$proj" ]; do
      [ -n "$proj" ] || continue
      echo
      info "── $proj"
      run_install "$proj"
    done < "$PROJECTS_FILE"
  else
    warn "Skipped"
  fi

else
  warn "No project path given and projects.txt is empty."
  warn "Run:  $HARNESS_DIR/install.sh /path/to/your/project"
  warn "      (registers the project in projects.txt automatically)"
fi

# ── GitNexus per-repo indexing ────────────────────────────────────────────────
# Runs after the install loop so every project (including pre-existing ones)
# gets indexed. Skipped if gitnexus is not available.
if [ "$SKIP_GITNEXUS" = false ] && { command -v gitnexus >/dev/null 2>&1 || npx gitnexus --version >/dev/null 2>&1; }; then
  section "Step 6b: GitNexus per-repo indexing"
  if confirm "Index any un-indexed repos with GitNexus?"; then
    index_gitnexus
  else
    warn "Skipped — run /kiro:gitnexus-setup inside Claude Code for each repo"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════╗"
echo -e "║  Bootstrap complete!                               ║"
echo -e "╚════════════════════════════════════════════════════╝${NC}"
echo
echo "  Next steps inside Claude Code (per project):"
echo "    /kiro:steering       — scan codebase, generate steering docs"
echo
echo "  Daily maintenance runs automatically via the local OS scheduler"
echo "  (registered by install.sh / update.sh). No per-project setup required."
echo
