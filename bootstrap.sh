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

# ── Cross-platform package installation ────────────────────────────────────────
# Installing tools is the ONE thing that cannot be OS-agnostic — brew/apt/winget
# are different programs. pkg_install declares a tool ONCE and dispatches to the
# right native manager so every OS reaches parity (no "do it manually" stubs).
#
#   pkg_install <name> <brew_formula> <apt_pkg> <winget_id>
#
# Pass "-" for any slot a manager genuinely can't satisfy. Returns non-zero on
# failure so callers can warn without aborting the whole bootstrap.
pkg_install() {
  local name="$1" brew_pkg="$2" apt_pkg="$3" winget_id="$4"
  case "$OS" in
    macos)
      [ "$brew_pkg" = "-" ] && { warn "$name: no Homebrew formula — install manually"; return 1; }
      command -v brew >/dev/null 2>&1 || { err "Homebrew required: https://brew.sh"; return 1; }
      brew install "$brew_pkg" ;;
    linux|wsl)
      [ "$apt_pkg" = "-" ] && { warn "$name: no apt package — install manually"; return 1; }
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y "$apt_pkg"
      else
        warn "$name: apt-get not found — install '$apt_pkg' with your distro's package manager"; return 1
      fi ;;
    gitbash)
      [ "$winget_id" = "-" ] && { warn "$name: no winget package — install manually"; return 1; }
      command -v winget >/dev/null 2>&1 || { err "winget required (App Installer from the Microsoft Store)"; return 1; }
      winget install -e --id "$winget_id" --accept-source-agreements --accept-package-agreements --disable-interactivity ;;
    *)
      warn "$name: unknown OS — install manually"; return 1 ;;
  esac
}

# ── Make freshly-installed tools visible to THIS run ───────────────────────────
# A package manager updates the persistent PATH, but an already-running shell does
# not see it — especially on Windows (winget). Prepend the known install dirs so
# subsequent steps (npm -g, gitnexus, raindrop) work in a single bootstrap run.
refresh_tool_path() {
  case "$OS" in
    gitbash)
      local links npmbin
      links="$(cygpath -u "${LOCALAPPDATA:-}" 2>/dev/null)/Microsoft/WinGet/Links"
      npmbin="$(cygpath -u "${APPDATA:-}" 2>/dev/null)/npm"
      export PATH="/c/Program Files/nodejs:$npmbin:$links:$HOME/.raindrop/bin:$PATH"
      ;;
    macos|linux|wsl)
      export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.raindrop/bin:$PATH"
      ;;
  esac
  hash -r 2>/dev/null || true
}

# ── Windows: let MSYS2/Git Bash see Windows-PATH tools ─────────────────────────
# MSYS2 does NOT inherit the Windows PATH by default, so winget/npm-installed tools
# (node, gitnexus, rg, fd, jq, uv) are invisible to the shell. Persist
# MSYS2_PATH_TYPE=inherit so every future MSYS2/Git Bash session sees them. No-op
# off Windows.
ensure_windows_path_inherit() {
  [ "$OS" = "gitbash" ] || return 0
  export MSYS2_PATH_TYPE=inherit
  if command -v setx.exe >/dev/null 2>&1 && [ "${MSYS2_PATH_TYPE_PERSISTED:-}" != "1" ]; then
    setx.exe MSYS2_PATH_TYPE inherit >/dev/null 2>&1 \
      && info "Set MSYS2_PATH_TYPE=inherit (Windows tools now visible in MSYS2 shells)" \
      || warn "Could not persist MSYS2_PATH_TYPE — set it manually if MSYS2 can't see Windows tools"
    export MSYS2_PATH_TYPE_PERSISTED=1
  fi
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

# On Windows, make sure MSYS2/Git Bash will see Windows-PATH tools (idempotent).
ensure_windows_path_inherit

# Node is auto-installable on every OS; claude + git are true prerequisites.
if ! command -v node >/dev/null 2>&1; then
  warn "node not found"
  if confirm "Install Node.js (required for GitNexus / impeccable)?"; then
    pkg_install "Node.js" node nodejs OpenJS.NodeJS.LTS || true
    refresh_tool_path
  fi
fi

# Hard requirements for bootstrap's OWN operations (npm needs node; git is used
# throughout). Missing either aborts.
PREREQ_FAIL=false
for tool in node git; do
  if command -v "$tool" >/dev/null 2>&1; then
    ver="$($tool --version 2>&1 | head -1)"
    ok "$tool  ($ver)"
  else
    err "$tool not found"
    PREREQ_FAIL=true
  fi
done

# claude (Claude Code CLI) is a RUNTIME dependency for automated maintenance, not
# for bootstrapping. It is often installed as a desktop app or on a PATH this
# shell doesn't see — so warn, don't abort.
if command -v claude >/dev/null 2>&1; then
  ok "claude  ($(claude --version 2>&1 | head -1))"
else
  warn "claude (Claude Code) not on this shell's PATH — fine for setup, but expose it"
  warn "  so the automated daily maintenance runner can call it."
fi

if [ "$PREREQ_FAIL" = true ]; then
  echo
  warn "Missing hard prerequisite(s). Install and re-run:"
  warn "  node : https://nodejs.org   (auto-install was attempted above — a new shell may be needed)"
  warn "  git  : https://git-scm.com"
  exit 1
fi

# ── Step 0b: Power tools (ripgrep, fd, jq) ───────────────────────────────────
section "Step 0b: Power Tools (ripgrep · fd · jq)"
# These tools dramatically improve Claude's file search speed and JSON parsing.
# When present, Claude uses them automatically instead of slower find/grep/cat.

if [ "$SKIP_POWER_TOOLS" = true ]; then
  warn "Skipping power tools  (--skip-power-tools)"
else
  # Per-tool package specs:        name  brew      apt        winget
  #   rg / fd / jq resolve to the right package on every OS via pkg_install.
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
    if confirm "Install missing power tools (${POWER_MISSING[*]})?"; then
      for t in "${POWER_MISSING[@]}"; do
        case "$t" in
          rg) pkg_install "ripgrep" ripgrep ripgrep BurntSushi.ripgrep.MSVC || true ;;
          fd) pkg_install "fd"      fd      fd-find  sharkdp.fd            || true ;;
          jq) pkg_install "jq"      jq      jq       jqlang.jq             || true ;;
        esac
      done
      # fd-find installs as 'fdfind' on Ubuntu; expose it as 'fd'
      if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
        ok "fd symlinked from fdfind"
      fi
      refresh_tool_path
      ok "Power tools step complete"
    else
      warn "Skipped power tools"
    fi
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
      # RTK ships no native Windows binary — it's a Rust PreToolUse proxy that
      # needs a Linux runtime. This is a real upstream limitation, not a stub.
      # RTK is OPTIONAL (Bash-output token compression); the harness works without it.
      warn "RTK has no native Windows build — install it inside WSL2 if you want it."
      warn "Skipping RTK (optional; the harness functions normally without it)."
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
    refresh_tool_path
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
  # Raindrop's installer runs anywhere with bash + curl + python3 (including
  # MSYS2/Git Bash) — the old "WSL2/macOS only" restriction was incorrect.
  if confirm "Install Raindrop Workshop?"; then
    # The installer requires python3 — ensure it per-OS first.
    if ! command -v python3 >/dev/null 2>&1; then
      info "Raindrop needs python3 — installing..."
      case "$OS" in
        macos)     command -v brew >/dev/null 2>&1 && brew install python ;;
        linux|wsl) command -v apt-get >/dev/null 2>&1 && sudo apt-get install -y python3 ;;
        gitbash)   if command -v pacman >/dev/null 2>&1; then
                     pacman -S --needed --noconfirm python
                   else
                     warn "No pacman (not MSYS2). Install python3 and re-run, or use MSYS2."
                   fi ;;
      esac
      refresh_tool_path
    fi

    if ! command -v python3 >/dev/null 2>&1; then
      warn "python3 unavailable — skipping Raindrop (install python3, then re-run)"
    else
      # Download then run (piping into bash fails: the installer reads a manifest mid-stream).
      _tmp="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/raindrop-install.sh")"
      curl -fsSL https://raindrop.sh/install -o "$_tmp"
      bash "$_tmp"
      rm -f "$_tmp"

      # Put ~/.raindrop/bin on PATH for this session and future shells.
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
    fi
  else
    warn "Skipped Raindrop Workshop"
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
    refresh_tool_path
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
        pkg_install "uv" - - astral-sh.uv || true
        refresh_tool_path
        command -v uv >/dev/null 2>&1 && ok "uv installed" \
          || warn "uv installed but not yet on PATH — open a new shell"
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
      # Pass a NATIVE path via cygpath so GitNexus (a Node/Windows tool) does not
      # misread an MSYS-style cwd as "Not a git repository" on Git Bash/MSYS2.
      local gnpath="$proj"
      command -v cygpath >/dev/null 2>&1 && gnpath="$(cygpath -w "$proj")"
      (cd "$proj" && npx gitnexus analyze "$gnpath") \
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
