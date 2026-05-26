#!/bin/bash
# bootstrap.sh — First-time machine setup for the SDD harness.
#
# Usage:
#   bootstrap.sh                          # check/install global tools only
#   bootstrap.sh /path/to/project         # also install harness into a project
#   bootstrap.sh /path/to/project --yes   # non-interactive (install everything)
#   bootstrap.sh --skip-ztk --skip-opf   # skip specific tools
#
# Flags:
#   --yes / -y        Non-interactive: answer "yes" to every install prompt
#   --with-gitnexus   Index the project repo with GitNexus during install
#   --skip-ztk        Skip ztk token-compression setup
#   --skip-gitnexus   Skip GitNexus install
#   --skip-impeccable Skip impeccable install
#   --skip-uv         Skip uv install
#   --skip-opf        Skip opf install
set -e

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Parse arguments ──────────────────────────────────────────────────────────
PROJECT_DIR=""
YES=false
WITH_GITNEXUS=false
SKIP_ZTK=false
SKIP_GITNEXUS=false
SKIP_IMPECCABLE=false
SKIP_UV=false
SKIP_OPF=false

for arg in "$@"; do
  case "$arg" in
    --yes|-y)          YES=true ;;
    --with-gitnexus)   WITH_GITNEXUS=true ;;
    --skip-ztk)        SKIP_ZTK=true ;;
    --skip-gitnexus)   SKIP_GITNEXUS=true ;;
    --skip-impeccable) SKIP_IMPECCABLE=true ;;
    --skip-uv)         SKIP_UV=true ;;
    --skip-opf)        SKIP_OPF=true ;;
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

# ── Step 1: ztk ───────────────────────────────────────────────────────────────
section "Step 1: ztk (Bash output token compression)"

if [ "$SKIP_ZTK" = true ]; then
  warn "Skipping ztk  (--skip-ztk)"
elif command -v ztk >/dev/null 2>&1; then
  ok "ztk already installed  ($(ztk --version 2>&1 | head -1))"
  info "Re-wiring global hook to ensure it's active..."
  ztk init -g 2>/dev/null && ok "Global hook active" || warn "ztk init -g failed — run it manually"
else
  case "$OS" in
    macos)
      if confirm "Install ztk via Homebrew?"; then
        brew install codejunkie99/ztk/ztk
        ztk init -g
        ok "ztk installed and global hook wired"
      else
        warn "Skipped ztk"
      fi
      ;;

    linux|wsl)
      warn "Linux/WSL: ztk must be built from source (no prebuilt binary)."
      warn "This downloads ~50MB Zig toolchain and takes ~5 minutes."
      if confirm "Build and install ztk from source?"; then
        ZIG_VER="0.16.0"
        ZIG_ARCHIVE="zig-${ARCH}-linux-${ZIG_VER}"
        ZIG_DIR="/tmp/${ZIG_ARCHIVE}"
        ZTK_SRC="/tmp/ztk-src-$$"

        # 1. Zig toolchain
        if [ ! -x "${ZIG_DIR}/zig" ]; then
          info "Downloading Zig ${ZIG_VER} (${ARCH})..."
          curl -fL "https://ziglang.org/download/${ZIG_VER}/${ZIG_ARCHIVE}.tar.xz" \
               -o /tmp/zig.tar.xz
          tar -xf /tmp/zig.tar.xz -C /tmp/
        else
          info "Zig toolchain already cached at ${ZIG_DIR}"
        fi

        # 2. Clone source
        info "Cloning ztk source..."
        git clone https://github.com/codejunkie99/ztk "${ZTK_SRC}"
        pushd "${ZTK_SRC}" >/dev/null

        # 3. Apply required patches (without these: blocked commands + permission dialogs)
        info "Applying patches..."
        perl -pi -e \
          's/permissions\.checkCommand\(cmd_str, &\.\{\}, allocator\);//g' \
          src/proxy.zig
        perl -pi -e \
          's/permissionDecision: "ask"/permissionDecision: "allow"/g' \
          src/hooks/claude_rewrite.zig

        # 4. Build
        info "Building ztk (ReleaseSmall)..."
        "${ZIG_DIR}/zig" build -Doptimize=ReleaseSmall

        # 5. Install to ~/.local/bin
        mkdir -p "$HOME/.local/bin"
        cp zig-out/bin/ztk "$HOME/.local/bin/ztk"
        chmod +x "$HOME/.local/bin/ztk"
        popd >/dev/null
        rm -rf "${ZTK_SRC}"

        # 6. Ensure ~/.local/bin is in PATH
        if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
          warn "~/.local/bin not in PATH — adding to ~/.bashrc"
          echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
          export PATH="$HOME/.local/bin:$PATH"
        fi

        # 7. Wire global hook
        ztk init -g
        ok "ztk built, installed to ~/.local/bin, and global hook wired"
      else
        warn "Skipped ztk"
      fi
      ;;

    gitbash)
      warn "ztk has no Windows binary. Install WSL2 to get token compression."
      warn "Skipping ztk on Git Bash."
      ;;

    *)
      warn "Unknown OS — skipping ztk. Install manually per FIRST-TIME-SETUP.md."
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
  INSTALL_FLAGS=""
  [ "$WITH_GITNEXUS" = true ] && INSTALL_FLAGS="--with-gitnexus"
  bash "$HARNESS_DIR/install.sh" "$proj" $INSTALL_FLAGS
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

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════╗"
echo -e "║  Bootstrap complete!                               ║"
echo -e "╚════════════════════════════════════════════════════╝${NC}"
echo
echo "  Next steps inside Claude Code (per project):"
echo "    /kiro:steering       — scan codebase, generate steering docs"
echo "    /kiro:setup-routine  — register nightly maintenance run"
echo
