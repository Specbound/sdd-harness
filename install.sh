#!/bin/bash
# SDD Harness — First-Time Install
# Single entry point for first-time machine setup: installs global tools,
# then syncs harness files into one project or all registered projects.
# For subsequent updates use update.sh.
#
# USAGE
#   First-time setup (one project):
#     ~/.claude/sdd-harness/install.sh /path/to/project
#     ~/.claude/sdd-harness/install.sh                      # cur dir
#
#   First-time setup (all registered projects):
#     ~/.claude/sdd-harness/install.sh --all
#     ~/.claude/sdd-harness/install.sh --all --force        # re-sync every project
#
#   Skip global tool installs (harness file sync only):
#     ~/.claude/sdd-harness/install.sh --skip-tools /path/to/project
#
#   Non-interactive (auto-yes all install prompts):
#     ~/.claude/sdd-harness/install.sh --yes /path/to/project
#
#   GitNexus code intelligence:
#     ~/.claude/sdd-harness/install.sh --with-gitnexus /path/to/project
#
# FLAGS
#   --yes / -y          Non-interactive: answer "yes" to every install prompt
#   --all               Install into every project in projects.txt
#   --force             With --all: re-sync even already-installed projects
#   --skip-tools        Skip ALL global tool installs (harness file sync only)
#   --skip-rtk          Skip RTK (bash output token compression) install
#   --skip-lean-ctx     Skip lean-ctx (file-read token compression) install
#   --skip-gitnexus     Skip GitNexus install
#   --skip-workshop     Skip Raindrop Workshop CLI install
#   --skip-impeccable   Skip impeccable (frontend QA) install
#   --skip-uv           Skip uv (Python package manager) install
#   --skip-opf          Skip opf (PII scanning) install
#   --skip-power-tools  Skip ripgrep/fd/jq install
#   --with-gitnexus     Configure GitNexus code intelligence per project
#   --with-embeddings   Opt-in to semantic search embeddings during GitNexus indexing
#   --skip-embeddings   No-op (kept for back-compat; embeddings are off by default)
#
# WINDOWS (PowerShell):
#   # run from inside the sdd-harness repo dir:
#   & "C:\Program Files\Git\bin\bash.exe" install.sh --all --with-gitnexus
#   # or with an explicit project (note /c/... style path for bash):
#   & "C:\Program Files\Git\bin\bash.exe" install.sh /c/dev/my-project
#   # one-off from anywhere (let bash expand ~ via -c):
#   & "C:\Program Files\Git\bin\bash.exe" -c "~/.claude/sdd-harness/install.sh --all"

# Self-locate the harness root via the shared resolver — symlink/junction-safe,
# resolves to the real physical path, works on any machine/OS/clone location.
__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/scripts/lib/resolve-harness-dir.sh"

# ── Flags ──────────────────────────────────────────────────────────────────────
YES=false
ALL=false
FORCE=false
SKIP_TOOLS=false
SKIP_RTK=false
SKIP_LEANCTX=false
SKIP_GITNEXUS=false
SKIP_WORKSHOP=false
SKIP_IMPECCABLE=false
SKIP_UV=false
SKIP_OPF=false
SKIP_POWER_TOOLS=false
WITH_GITNEXUS=false
SKIP_EMBEDDINGS=false
WITH_EMBEDDINGS=false

POSITIONAL_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --yes|-y)            YES=true ;;
    --all)               ALL=true ;;
    --force)             FORCE=true ;;
    --skip-tools)        SKIP_TOOLS=true ;;
    --skip-rtk)          SKIP_RTK=true ;;
    --skip-lean-ctx)     SKIP_LEANCTX=true ;;
    --skip-gitnexus)     SKIP_GITNEXUS=true ;;
    --skip-workshop)     SKIP_WORKSHOP=true ;;
    --skip-impeccable)   SKIP_IMPECCABLE=true ;;
    --skip-uv)           SKIP_UV=true ;;
    --skip-opf)          SKIP_OPF=true ;;
    --skip-power-tools)  SKIP_POWER_TOOLS=true ;;
    --with-gitnexus)     WITH_GITNEXUS=true ;;
    --skip-embeddings)   SKIP_EMBEDDINGS=true ;;   # no-op (kept for back-compat)
    --with-embeddings)   WITH_EMBEDDINGS=true ;;
    --*) echo "Unknown flag: $arg" >&2; exit 1 ;;
    *)   POSITIONAL_ARGS+=("$arg") ;;
  esac
done

# ── OS / arch detection ────────────────────────────────────────────────────────
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
    *) echo "unknown" ;;
  esac
}
SDD_OS="$(detect_os)"

ARCH="$(uname -m 2>/dev/null || echo x86_64)"
case "$ARCH" in
  arm64|aarch64) ARCH="aarch64" ;;
  *)             ARCH="x86_64"  ;;
esac

# ── Colour helpers (terminal only) ────────────────────────────────────────────
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
  CYAN='\033[0;36m';  BOLD='\033[1m';      NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; CYAN=''; BOLD=''; NC=''
fi

ok()      { echo -e "${GREEN}  ✓  $*${NC}"; }
info()    { echo -e "${CYAN}  ▸  $*${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠  $*${NC}"; }
err()     { echo -e "${RED}  ✗  $*${NC}"; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────${NC}"; }

# ── confirm <prompt> ───────────────────────────────────────────────────────────
# Returns 0 (proceed) or 1 (skip). Auto-yes when --yes flag is set.
confirm() {
  [ "$YES" = true ] && return 0
  local resp
  printf "%s [y/N] " "$1"
  read -r resp </dev/tty
  case "$resp" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ── sync_dir <src> <dst_parent> ────────────────────────────────────────────────
# Copies src as dst_parent/$(basename src), replacing any prior copy.
# rm-then-copy is idempotent and identical across macOS (BSD cp) / Linux / WSL.
sync_dir() {
  local src="${1%/}" dst_parent="$2"   # strip trailing slash: BSD cp dumps CONTENTS when src ends in /
  rm -rf "$dst_parent/$(basename "$src")"
  cp -r "$src" "$dst_parent/"
}

# ── ensure_gitignore <project_dir> ─────────────────────────────────────────────
# Append the harness-local entries to the project's .gitignore, idempotently.
# Harness files are local-only (see CLAUDE.md "Never commit SDD files"), so the
# whole .claude/ tree, specs/, and CLAUDE.md stay untracked. Each entry is added
# only if absent, so re-runs and pre-existing .gitignores are safe.
ensure_gitignore() {
  local project_dir="$1"
  local gitignore="$project_dir/.gitignore"
  local entry added=false
  touch "$gitignore"
  for entry in ".claude/" "specs/" "CLAUDE.md"; do
    # Match the exact line to avoid false positives (e.g. ".claude/" vs ".claudeignore").
    if ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
      if [ "$added" = false ]; then
        # Separate from prior content with a blank line + header, once.
        [ -s "$gitignore" ] && printf '\n' >> "$gitignore"
        echo "# SDD harness — local-only, never committed" >> "$gitignore"
        added=true
      fi
      echo "$entry" >> "$gitignore"
    fi
  done
  [ "$added" = true ] && echo "  Added harness entries to .gitignore (.claude/ specs/ CLAUDE.md)."
}

# ── pkg_install <name> <brew_formula> <apt_pkg> <winget_id> ──────────────────
# Pass "-" for any slot a manager genuinely can't satisfy.
pkg_install() {
  local name="$1" brew_pkg="$2" apt_pkg="$3" winget_id="$4"
  case "$SDD_OS" in
    macos)
      [ "$brew_pkg" = "-" ] && { warn "$name: no Homebrew formula — install manually"; return 1; }
      command -v brew >/dev/null 2>&1 || { err "Homebrew required: https://brew.sh"; return 1; }
      brew install "$brew_pkg" ;;
    linux|wsl)
      [ "$apt_pkg" = "-" ] && { warn "$name: no apt pkg — install manually"; return 1; }
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y "$apt_pkg"
      else
        warn "$name: apt-get not found — install '$apt_pkg' with your distro's pkg manager"; return 1
      fi ;;
    gitbash)
      [ "$winget_id" = "-" ] && { warn "$name: no winget pkg — install manually"; return 1; }
      command -v winget >/dev/null 2>&1 || { err "winget required (App Installer from the Microsoft Store)"; return 1; }
      winget install -e --id "$winget_id" --accept-source-agreements --accept-package-agreements --disable-interactivity ;;
    *) warn "$name: unknown OS — install manually"; return 1 ;;
  esac
}

# ── refresh_tool_path ──────────────────────────────────────────────────────────
# A pkg manager updates the persistent PATH but an already-running shell does
# not see it — especially on Windows (winget). Prepend known install dirs so
# subsequent steps work in a single install run.
refresh_tool_path() {
  case "$SDD_OS" in
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

# ── ensure_windows_path_inherit ───────────────────────────────────────────────
# MSYS2 does NOT inherit the Windows PATH by default, so winget/npm-installed
# tools are invisible to the shell. Persists MSYS2_PATH_TYPE=inherit so every
# future MSYS2/Git Bash session sees them. No-op on macOS/Linux.
ensure_windows_path_inherit() {
  [ "$SDD_OS" = "gitbash" ] || return 0
  export MSYS2_PATH_TYPE=inherit
  if command -v setx.exe >/dev/null 2>&1 && [ "${MSYS2_PATH_TYPE_PERSISTED:-}" != "1" ]; then
    setx.exe MSYS2_PATH_TYPE inherit >/dev/null 2>&1 \
      && info "Set MSYS2_PATH_TYPE=inherit (Windows tools now visible in MSYS2 shells)" \
      || warn "Could not persist MSYS2_PATH_TYPE — set it manually"
    export MSYS2_PATH_TYPE_PERSISTED=1
  fi
}

# ════════════════════════════════════════════════════════════════════════════════
# install_global_tools
# Install machine-wide tools needed by the harness. Interactive unless --yes.
# Skip entirely with --skip-tools.
# ════════════════════════════════════════════════════════════════════════════════
install_global_tools() {
  if [ "$SKIP_TOOLS" = true ]; then
    info "Skipping global tool installs (--skip-tools)"
    return 0
  fi

  section "Prerequisites"
  ensure_windows_path_inherit

  if ! command -v node >/dev/null 2>&1; then
    warn "node not found"
    if confirm "Install Node.js (required for GitNexus / impeccable)?"; then
      pkg_install "Node.js" node nodejs OpenJS.NodeJS.LTS || true
      refresh_tool_path
    fi
  fi

  PREREQ_FAIL=false
  for tool in node git; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "$tool  ($($tool --version 2>&1 | head -1))"
    else
      err "$tool not found"
      PREREQ_FAIL=true
    fi
  done

  # claude is a RUNTIME dep for automated maintenance — warn but don't abort.
  if command -v claude >/dev/null 2>&1; then
    ok "claude  ($(claude --version 2>&1 | head -1))"
  else
    warn "claude (Claude Code) not on this shell's PATH — needed by the daily maintenance runner"
  fi

  if [ "$PREREQ_FAIL" = true ]; then
    warn "Missing hard prerequisite(s). Install and re-run:"
    warn "  node : https://nodejs.org"
    warn "  git  : https://git-scm.com"
    exit 1
  fi

  # Power tools
  section "Power Tools (ripgrep · fd · jq)"
  if [ "$SKIP_POWER_TOOLS" = true ]; then
    warn "Skipping power tools  (--skip-power-tools)"
  else
    POWER_MISSING=()
    for tool in rg fd jq; do
      if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool  ($($tool --version 2>&1 | head -1))"
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
        # fd-find installs as 'fdfind' on Ubuntu; expose as 'fd'
        if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
          mkdir -p "$HOME/.local/bin"
          ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
          ok "fd symlinked from fdfind"
        fi
        refresh_tool_path
      else
        warn "Skipped power tools"
      fi
    fi
  fi

  # RTK
  section "RTK (bash output token compression)"
  if [ "$SKIP_RTK" = true ]; then
    warn "Skipping RTK  (--skip-rtk)"
  elif command -v rtk >/dev/null 2>&1; then
    ok "RTK already installed  ($(rtk --version 2>&1 | head -1))"
    info "Re-wiring global hook to ensure it's active..."
    rtk init -g --auto-patch 2>/dev/null && ok "Global hook active" || warn "rtk init -g failed — run it manually"
  else
    case "$SDD_OS" in
      macos|linux|wsl)
        if confirm "Install RTK via Homebrew?"; then
          brew install rtk
          rtk init -g --auto-patch
          ok "RTK installed and global hook wired"
        else
          warn "Skipped RTK"
        fi ;;
      gitbash)
        warn "RTK has no native Windows build — install inside WSL2 if you want it." ;;
      *) warn "Unknown OS — skipping RTK." ;;
    esac
  fi

  # lean-ctx (file-read token compression)
  # Installs the binary so the MCP wiring in patch_global_settings can activate.
  # Without this, that wiring is a silent no-op (it is gated on `which lean-ctx`).
  section "lean-ctx (file-read token compression)"
  if [ "$SKIP_LEANCTX" = true ]; then
    warn "Skipping lean-ctx  (--skip-lean-ctx)"
  elif command -v lean-ctx >/dev/null 2>&1; then
    ok "lean-ctx already installed  ($(lean-ctx --version 2>&1 | head -1))"
    lean-ctx init --agent claude >/dev/null 2>&1 && ok "lean-ctx Claude wiring refreshed" \
      || warn "lean-ctx init failed — run: lean-ctx init --agent claude"
  else
    case "$SDD_OS" in
      macos|linux|wsl)
        if confirm "Install lean-ctx?"; then
          if command -v brew >/dev/null 2>&1; then
            brew tap yvgude/lean-ctx 2>/dev/null || true
            brew trust yvgude/lean-ctx 2>/dev/null || true   # third-party tap trust (brew >= 4.x)
            brew install lean-ctx 2>/dev/null || curl -fsSL https://leanctx.com/install.sh | sh
          else
            curl -fsSL https://leanctx.com/install.sh | sh
          fi
          refresh_tool_path
          if command -v lean-ctx >/dev/null 2>&1; then
            lean-ctx init --agent claude >/dev/null 2>&1
            ok "lean-ctx installed and wired to Claude Code"
          else
            warn "lean-ctx install did not land — install manually: https://leanctx.com"
          fi
        else
          warn "Skipped lean-ctx"
        fi ;;
      gitbash)
        warn "lean-ctx: on Windows clone the repo and run ./install.ps1 (see leanctx.com)." ;;
      *) warn "Unknown OS — skipping lean-ctx." ;;
    esac
  fi

  # GitNexus
  section "GitNexus (code intelligence)"
  if [ "$SKIP_GITNEXUS" = true ]; then
    warn "Skipping GitNexus  (--skip-gitnexus)"
  elif command -v gitnexus >/dev/null 2>&1; then
    ok "GitNexus already installed  ($(gitnexus --version 2>&1 | head -1))"
  elif npx gitnexus --version >/dev/null 2>&1; then
    ok "GitNexus available via npx"
    if confirm "Install GitNexus globally?  (npm install -g gitnexus)"; then
      npm install -g gitnexus
      refresh_tool_path
      ok "GitNexus installed"
    else
      warn "Skipped GitNexus"
    fi
  else
    if confirm "Install GitNexus globally?  (npm install -g gitnexus)"; then
      npm install -g gitnexus
      refresh_tool_path
      ok "GitNexus installed"
    else
      warn "Skipped GitNexus"
    fi
  fi

  # Raindrop Workshop CLI
  section "Raindrop Workshop"
  if [ "$SKIP_WORKSHOP" = true ]; then
    warn "Skipping Raindrop Workshop  (--skip-workshop)"
  elif command -v raindrop >/dev/null 2>&1 || [ -x "$HOME/.raindrop/bin/raindrop" ]; then
    ok "Raindrop Workshop CLI already installed"
  else
    if confirm "Install Raindrop Workshop?"; then
      if ! command -v python3 >/dev/null 2>&1; then
        info "Raindrop needs python3 — installing..."
        case "$SDD_OS" in
          macos)     command -v brew >/dev/null 2>&1 && brew install python ;;
          linux|wsl) command -v apt-get >/dev/null 2>&1 && sudo apt-get install -y python3 ;;
          gitbash)
            if command -v pacman >/dev/null 2>&1; then
              pacman -S --needed --noconfirm python
            else
              warn "No pacman (not MSYS2). Install python3 and re-run, or use MSYS2."
            fi ;;
        esac
        refresh_tool_path
      fi
      if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 unavailable — skipping Raindrop. Install python3 and re-run."
      else
        # Download then run (piping into bash fails: the installer reads a manifest mid-stream).
        _tmp="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/raindrop-install.sh")"
        curl -fsSL https://raindrop.sh/install -o "$_tmp"
        bash "$_tmp"
        rm -f "$_tmp"
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

  # impeccable
  section "impeccable (frontend design QA)"
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

  # uv
  section "uv (Python package manager)"
  if [ "$SKIP_UV" = true ]; then
    warn "Skipping uv  (--skip-uv)"
  elif command -v uv >/dev/null 2>&1; then
    ok "uv already installed  ($(uv --version 2>&1))"
  else
    if confirm "Install uv?"; then
      case "$SDD_OS" in
        macos|linux|wsl)
          curl -LsSf https://astral.sh/uv/install.sh | sh
          for env_file in "$HOME/.cargo/env" "$HOME/.local/bin/env"; do
            [ -f "$env_file" ] && . "$env_file" && break
          done
          export PATH="$HOME/.local/bin:$PATH"
          ok "uv installed" ;;
        gitbash)
          pkg_install "uv" - - astral-sh.uv || true
          refresh_tool_path
          command -v uv >/dev/null 2>&1 && ok "uv installed" \
            || warn "uv installed but not yet on PATH — open a new shell" ;;
      esac
    else
      warn "Skipped uv"
    fi
  fi

  # opf
  section "opf (PII scanning)"
  if [ "$SKIP_OPF" = true ]; then
    warn "Skipping opf  (--skip-opf)"
  elif command -v opf >/dev/null 2>&1; then
    ok "opf already installed"
  else
    if confirm "Install opf?  (downloads ~2.8GB model weights on first use)"; then
      # opf is OpenAI's privacy-filter — NOT on PyPI. Install from the GitHub
      # source. Pin to 3.13: torch lacks wheels for the newest CPython, and the
      # system default here can be 3.9 (Apple) or 3.14 (Homebrew).
      OPF_GIT="git+https://github.com/openai/privacy-filter.git"
      if command -v uv >/dev/null 2>&1; then
        uv tool install --python 3.13 "$OPF_GIT" && ok "opf installed via uv tool" \
          || err "opf install failed — try manually: uv tool install --python 3.13 $OPF_GIT"
      elif command -v pipx >/dev/null 2>&1; then
        pipx install --python python3.13 "$OPF_GIT" && ok "opf installed via pipx" \
          || err "opf install failed — try manually: pipx install $OPF_GIT"
      elif command -v pip >/dev/null 2>&1; then
        pip install --user "$OPF_GIT" && ok "opf installed via pip" \
          || err "opf install failed — try manually: pip install $OPF_GIT"
      else
        err "Need uv, pipx, or pip — then: uv tool install $OPF_GIT"
      fi
    else
      warn "Skipped opf"
    fi
  fi
}

# ════════════════════════════════════════════════════════════════════════════════
# install_project <PROJECT_DIR>
# Per-project harness file sync. Returns non-zero on failure instead of
# exiting, so --all can continue to the next project.
# Machine-global steps (skills, global commands, harness settings regen,
# raindrop, OS orchestrator) live OUTSIDE this fn and run once — see
# install_globals.
# ════════════════════════════════════════════════════════════════════════════════
install_project() {
  local PROJECT_DIR
  PROJECT_DIR="$(realpath "$1")" || { echo "ERROR: cannot resolve path: $1"; return 1; }
  echo "Installing SDD harness into: $PROJECT_DIR  (OS: $SDD_OS)"

  # --- Validate ---
  if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "ERROR: $PROJECT_DIR is not a git repo."
    return 1
  fi

  # --- Create dir structure (only dirs not managed by cp below) ---
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
  sync_dir "$HARNESS_DIR/rules"         "$PROJECT_DIR/.claude"

  # glacier/ is empty in the harness src; create it explicitly after kiro sync
  mkdir -p "$PROJECT_DIR/.claude/kiro/settings/templates/memory/meta/glacier"

  # --- Sync ALL hooks from canonical src ($HARNESS_DIR/hooks/claude/) ---
  # Every .sh in hooks/claude/ is installed unconditionally — even hooks the user may not
  # wire up immediately. The harness is the src of truth; mandatory propagation.
  for hook in "$HARNESS_DIR/hooks/claude/"*.sh; do
    [ -f "$hook" ] || continue
    name="$(basename "$hook")"
    cp "$hook" "$PROJECT_DIR/.claude/hooks/$name"
    chmod +x "$PROJECT_DIR/.claude/hooks/$name"
  done

  # --- chmod runtime scripts that need to be executable ---
  local s
  for s in orchestration/daily-runner.sh routines/macro-eval-runner.sh routines/skill-curator-runner.sh routines/harness-health-runner.sh routines/tool-failure-review-runner.sh routines/startup-payload-audit.sh routines/code-review-learning-runner.sh session/write_handoff.py pr/detect_base_and_create.sh; do
    [ -f "$PROJECT_DIR/.claude/scripts/$s" ] && chmod +x "$PROJECT_DIR/.claude/scripts/$s"
  done
  [ -f "$PROJECT_DIR/.claude/scripts/utils/ollama_model_test.py" ] && chmod +x "$PROJECT_DIR/.claude/scripts/utils/ollama_model_test.py"
  [ -f "$PROJECT_DIR/.claude/scripts/integrations/blackhole/blackhole-cursor.py" ] && chmod +x "$PROJECT_DIR/.claude/scripts/integrations/blackhole/blackhole-cursor.py"

  # --- Set up git post-commit hook ---
  cp "$HARNESS_DIR/hooks/git/post-commit" "$PROJECT_DIR/.git/hooks/"
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
  # Fill the {{PROJECT_NAME}} placeholder with the project dir's basename so the
  # file is usable immediately. Nothing else fills this — no hook does it — so the
  # install is the single source of truth for it.
  if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
    local PROJECT_NAME
    PROJECT_NAME="$(basename "$PROJECT_DIR")"
    sed "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
      "$HARNESS_DIR/templates/CLAUDE.md.template" > "$PROJECT_DIR/CLAUDE.md"
    echo "  CLAUDE.md created from template (project name: $PROJECT_NAME) — refine context as needed."
  fi

  # --- settings.json for target project (skip if exists) ---
  # Validate the template before copying: Claude Code parses settings.json as
  # strict JSON and silently drops every rule and hook in a malformed file.
  # A bad template used to propagate that breakage into every new project.
  if [ ! -f "$PROJECT_DIR/.claude/settings.json" ]; then
    if bash "$HARNESS_DIR/scripts/setup/check-settings-json.sh" "$HARNESS_DIR/templates/settings.json.template"; then
      cp "$HARNESS_DIR/templates/settings.json.template" "$PROJECT_DIR/.claude/settings.json"
      echo "  .claude/settings.json created from template — review and customize."
    else
      err "templates/settings.json.template is not valid JSON — settings.json NOT created."
    fi
  fi

  # Sidecar for notes that cannot live inside settings.json (JSON has no comments).
  if [ ! -f "$PROJECT_DIR/.claude/settings.notes.md" ]; then
    cp "$HARNESS_DIR/templates/settings.notes.md.template" "$PROJECT_DIR/.claude/settings.notes.md"
  fi

  # Self-heal projects installed before the template was fixed.
  if command -v python3 >/dev/null 2>&1; then
    python3 "$HARNESS_DIR/scripts/setup/repair-settings-json.py" "$PROJECT_DIR" | grep -v '^OK ' || true
  fi

  # --- Generate project stack summary ---
  bash "$HARNESS_DIR/scripts/setup/generate-project-stack.sh" "$PROJECT_DIR" || \
    echo "  WARNING: scripts/setup/generate-project-stack.sh returned non-zero — stack file may be missing."

  # --- Ignore harness files in the project repo (local-only) ---
  ensure_gitignore "$PROJECT_DIR"

  # --- Queue steering bootstrap for the first Claude session ---
  # /kiro:steering is an interactive slash command (it interviews you about
  # product/tech/structure), so it can't run from this shell. Drop a sentinel;
  # session-start-hook.sh sees it on first open and injects [STEERING-BOOTSTRAP-DUE]
  # so steering runs inside a real Claude session. Skip if steering already exists.
  if ! ls "$PROJECT_DIR/.claude/steering/"*.md >/dev/null 2>&1; then
    : > "$PROJECT_DIR/.claude/memory/.steering-bootstrap-pending"
    echo "  Steering bootstrap queued — /kiro:steering will be prompted on first Claude session."
  fi

  # --- Record install timestamp ---
  date -Iseconds > "$PROJECT_DIR/.claude/.last-harness-check"

  # --- Register project ---
  if ! grep -qF "$PROJECT_DIR" "$HARNESS_DIR/projects.txt" 2>/dev/null; then
    echo "$PROJECT_DIR" >> "$HARNESS_DIR/projects.txt"
    echo "  Registered in $HARNESS_DIR/projects.txt"
  fi

  # --- opt: GitNexus integration (per-project) ---
  if [ "$WITH_GITNEXUS" = true ]; then
    echo ""
    echo "Setting up GitNexus code intelligence..."
    if command -v gitnexus >/dev/null 2>&1 || npx gitnexus --version >/dev/null 2>&1; then
      local ANALYZE_FLAGS=""
      [ "$WITH_EMBEDDINGS" = true ] && ANALYZE_FLAGS="--embeddings"

      # GitNexus is a native (Node/Windows) tool. Pass an explicit NATIVE path via
      # cygpath on Git Bash so it doesn't misread MSYS-style paths.
      local GN_PATH="$PROJECT_DIR"
      command -v cygpath >/dev/null 2>&1 && GN_PATH="$(cygpath -w "$PROJECT_DIR")"

      if [ ! -d "$PROJECT_DIR/.gitnexus" ]; then
        echo "  Indexing repo with GitNexus..."
        (cd "$PROJECT_DIR" && npx gitnexus analyze "$GN_PATH" $ANALYZE_FLAGS)
        echo "  repo indexed."
      else
        echo "  repo already indexed (.gitnexus/ exists)."
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
          echo "  Or run /kiro:gitnexus-setup inside Claude Code for automatic cfg."
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

# ════════════════════════════════════════════════════════════════════════════════
# patch_global_settings <python_snippet>
# Safely merges hook/MCP entries into ~/.claude/settings.json via Python stdlib.
# Idempotent: checks for existing entries before adding.
# ════════════════════════════════════════════════════════════════════════════════
patch_global_settings() {
  local global_settings="$HOME/.claude/settings.json"
  if [ ! -f "$global_settings" ]; then
    warn "~/.claude/settings.json not found — run Claude Code once to create it, then re-run install.sh"
    return 0
  fi
  python3 - "$global_settings" "$HOME" "$HARNESS_DIR" << 'PYEOF'
import json, sys, os

settings_path, home, harness_dir = sys.argv[1], sys.argv[2], sys.argv[3]
hooks_dir = os.path.join(home, '.claude', 'hooks')

with open(settings_path, 'r') as f:
  raw = f.read()

# Strip JSON5-style // comments (Claude Code settings allow them)
import re
clean = re.sub(r'//[^\n]*', '', raw)
try:
  s = json.loads(clean)
except json.JSONDecodeError:
  s = {}

changed = False
hooks = s.setdefault('hooks', {})

# ── Caveman — SessionStart ──────────────────────────────────────────────────
ss = hooks.setdefault('SessionStart', [])
caveman_ss_cmd = f'node "{hooks_dir}/caveman-activate.js"'
if not any(caveman_ss_cmd in str(h) for h in ss):
  ss.append({'hooks': [{'type': 'command', 'command': caveman_ss_cmd}]})
  print('  [caveman] Added SessionStart hook')
  changed = True

# ── Caveman — UserPromptSubmit ──────────────────────────────────────────────
ups = hooks.setdefault('UserPromptSubmit', [])
caveman_ups_cmd = f'node "{hooks_dir}/caveman-mode-tracker.js"'
if not any(caveman_ups_cmd in str(h) for h in ups):
  ups.append({'hooks': [{'type': 'command', 'command': caveman_ups_cmd}]})
  print('  [caveman] Added UserPromptSubmit hook')
  changed = True

# ── Caveman — statusLine (only set if not already configured) ───────────────
caveman_sl_cmd = f'bash "{hooks_dir}/caveman-statusline.sh"'
if 'statusLine' not in s:
  s['statusLine'] = {'type': 'command', 'command': caveman_sl_cmd}
  print('  [caveman] Added statusLine')
  changed = True

# ── lean-ctx — MCP server ───────────────────────────────────────────────────
import subprocess
has_lean_ctx = subprocess.run(['which', 'lean-ctx'], capture_output=True).returncode == 0
# `lean-ctx init --agent claude` (run by install_global_tools) is the source of truth
# for lean-ctx wiring. Only fall back to manual wiring if that did not register the MCP.
already_wired = 'lean-ctx' in s.get('mcpServers', {})
if has_lean_ctx and not already_wired:
  mcp = s.setdefault('mcpServers', {})
  if 'lean-ctx' not in mcp:
    mcp['lean-ctx'] = {'command': 'lean-ctx', 'args': ['--mcp'], 'env': {}}
    print('  [lean-ctx] Added MCP server')
    changed = True

  # lean-ctx permissions
  perms = s.setdefault('permissions', {}).setdefault('allow', [])
  lc_perms = [
    'Bash(lean-ctx *)',
    'mcp__lean-ctx__ctx_read',
    'mcp__lean-ctx__ctx_search',
    'mcp__lean-ctx__ctx_shell',
    'mcp__lean-ctx__ctx_tree',
    'mcp__lean-ctx__ctx_edit',
    'mcp__lean-ctx__ctx_overview',
    'mcp__lean-ctx__ctx_session',
    'mcp__lean-ctx__ctx_knowledge',
  ]
  for p in lc_perms:
    if p not in perms:
      perms.append(p)
      changed = True
  if changed:
    print('  [lean-ctx] Added permissions')

  # lean-ctx PreToolUse bash rewrite hook
  ptu = hooks.setdefault('PreToolUse', [])
  lc_rewrite_cmd = 'lean-ctx hook rewrite'
  if not any(lc_rewrite_cmd in str(h) for h in ptu):
    ptu.append({'matcher': 'Bash', 'hooks': [{'type': 'command', 'command': lc_rewrite_cmd}]})
    print('  [lean-ctx] Added PreToolUse Bash rewrite hook')
    changed = True

  lc_redirect_cmd = 'lean-ctx hook redirect'
  if not any(lc_redirect_cmd in str(h) for h in ptu):
    ptu.append({'matcher': 'Read', 'hooks': [{'type': 'command', 'command': lc_redirect_cmd}]})
    print('  [lean-ctx] Added PreToolUse Read redirect hook')
    changed = True

if changed:
  with open(settings_path, 'w') as f:
    json.dump(s, f, indent=2)
  print('  ~/.claude/settings.json updated.')
else:
  print('  ~/.claude/settings.json already up to date.')
PYEOF
}

# ════════════════════════════════════════════════════════════════════════════════
# install_globals
# Machine-wide setup that must run exactly once regardless of how many projects
# are installed: harness skills, global commands, the harness's own settings.json,
# Raindrop tracing wiring, headroom, liteparse, and the OS-level daily orchestrator.
# ════════════════════════════════════════════════════════════════════════════════
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

  # --- Install global hooks (caveman, lean-ctx) to ~/.claude/hooks/ ---
  if [ -d "$HARNESS_DIR/hooks/global" ]; then
    mkdir -p "$HOME/.claude/hooks"
    for hook_file in "$HARNESS_DIR/hooks/global"/*; do
      [ -f "$hook_file" ] || continue
      cp "$hook_file" "$HOME/.claude/hooks/"
      chmod +x "$HOME/.claude/hooks/$(basename "$hook_file")" 2>/dev/null || true
    done
    echo "  Global hooks (caveman, lean-ctx) installed to ~/.claude/hooks/"
  fi

  # --- Default caveman mode: lite (only if flag file is absent) ---
  local caveman_flag="$HOME/.claude/.caveman-active"
  if [ ! -f "$caveman_flag" ]; then
    printf 'lite' > "$caveman_flag"
    echo "  Caveman mode defaulted to: lite  (~/.claude/.caveman-active)"
  fi

  # --- Patch ~/.claude/settings.json: caveman wiring + lean-ctx MCP ---
  section "Global settings patch (caveman + lean-ctx)"
  if command -v python3 >/dev/null 2>&1; then
    patch_global_settings
  else
    warn "python3 not found — skipping global settings patch. Run install.sh again after installing python3."
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

  # --- Persist harness root so stop-hook.sh can locate it at runtime ---
  echo "$HARNESS_DIR" > "$HOME/.sdd-harness-root"

  # --- Regenerate harness's own settings.json with absolute paths ---
  # Always regenerate so hook paths reflect the actual harness location on this machine.
  sed "s|{{HARNESS_DIR}}|$HARNESS_DIR|g" "$HARNESS_DIR/templates/settings.harness.json.template" \
    > "$HARNESS_DIR/.claude/settings.json"
  echo "  Harness settings.json generated (paths resolved to $HARNESS_DIR)."

  # --- Raindrop Workshop wiring (env vars + venv installs) ---
  echo ""
  echo "Setting up Raindrop Workshop tracing..."
  bash "$HARNESS_DIR/scripts/setup/raindrop-setup.sh" || \
    echo "  WARNING: setup/raindrop-setup.sh returned non-zero — re-run manually if needed."

  # --- Headroom ctx compression ---
  echo ""
  echo "Setting up headroom ctx compression..."
  bash "$HARNESS_DIR/scripts/setup/headroom-setup.sh" || \
    echo "  WARNING: setup/headroom-setup.sh returned non-zero — re-run manually if needed."

  # --- LiteParse doc parser (owned in a dedicated >=3.10 venv) ---
  echo ""
  echo "Installing liteparse doc parser..."
  bash "$HARNESS_DIR/scripts/setup/liteparse-setup.sh" || \
    echo "  WARNING: liteparse setup returned non-zero — re-run manually: bash $HARNESS_DIR/scripts/setup/liteparse-setup.sh"

  # --- Self-register harness in projects.txt (idempotent) ---
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
          bash "$HARNESS_DIR/scripts/orchestration/setup-global-orchestrator.sh" || \
            echo "  WARNING: scheduled-task bootstrap returned non-zero; daily orchestrator may not be registered."
        fi ;;
      macos)
        bash "$HARNESS_DIR/scripts/orchestration/setup-mac-orchestrator.sh" || \
          echo "  WARNING: launchd registration returned non-zero; daily orchestrator may not be registered." ;;
      linux)
        bash "$HARNESS_DIR/scripts/orchestration/setup-linux-orchestrator.sh" || \
          echo "  WARNING: crontab registration returned non-zero; daily orchestrator may not be registered." ;;
    esac
  fi
}

# ════════════════════════════════════════════════════════════════════════════════
# print_maintenance_reminder
# ════════════════════════════════════════════════════════════════════════════════
print_maintenance_reminder() {
  if [ "${SDD_SKIP_ROUTINE:-0}" != "1" ]; then
    echo ""
    echo "  ┌────────────────────────────────────────────────────────────────────────┐"
    echo "  │ Daily maintenance                                                       │"
    echo "  │ Each repo's daily runner is installed at:                              │"
    echo "  │   .claude/scripts/orchestration/daily-runner.sh                        │"
    echo "  │ It runs the daily-maintenance + session-quality + keep-rate pipeline.  │"
    echo "  │ Trigger paths (both automatic):                                        │"
    echo "  │   1. OS scheduler — fires daily at 18:00 local across ALL repos:       │"
    echo "  │        macOS   : launchd LaunchAgent (~/Library/LaunchAgents/)         │"
    echo "  │        WSL     : Windows Task Scheduler (schtasks.exe)                 │"
    echo "  │        Linux   : crontab (crontab -l)                                  │"
    echo "  │      Registered automatically on first install per platform.           │"
    echo "  │   2. SessionStart hook — if >24h since last run, fires the runner in   │"
    echo "  │      the background when you open Claude in this repo.                 │"
    echo "  │ Disable per-repo: rm .claude/scripts/orchestration/daily-runner.sh     │"
    echo "  │ Disable globally (macOS): launchctl unload -w                          │"
    echo "  │   ~/Library/LaunchAgents/com.sdd.daily-orchestrator.plist              │"
    echo "  │ Disable globally (WSL): schtasks.exe /Delete /TN \"SDD Daily\"          │"
    echo "  │ Disable globally (Linux): crontab -e  # remove sdd-daily-orchestrator  │"
    echo "  └────────────────────────────────────────────────────────────────────────┘"
  fi
}

# ════════════════════════════════════════════════════════════════════════════════
# Main
# ════════════════════════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║        SDD Harness — Install                       ║"
echo "╚════════════════════════════════════════════════════╝"
echo "  OS: $SDD_OS ($ARCH)"
[ -n "${POSITIONAL_ARGS[0]:-}" ] && echo "  Project: ${POSITIONAL_ARGS[0]}"
[ "$YES" = true ]                 && echo "  Mode: non-interactive (--yes)"

# Step 1: Install global tools (rtk, gitnexus, raindrop CLI, uv, etc.)
install_global_tools

# Step 1.5: Pre-ship gate — scan harness source for leaked secrets / over-broad
# perms before any files are copied into a repo. Blocking finding aborts install
# so secrets never propagate. Opt out: SDD_SKIP_SHIP_SCAN=1. Strict: SDD_SHIP_STRICT=1.
if [ "${SDD_SKIP_SHIP_SCAN:-0}" != "1" ] && [ -f "$HARNESS_DIR/scripts/lib/ship-safety-scan.sh" ]; then
  echo ""
  __scan_args=("$HARNESS_DIR")
  [ "${SDD_SHIP_STRICT:-0}" = "1" ] && __scan_args+=(--strict)
  if ! bash "$HARNESS_DIR/scripts/lib/ship-safety-scan.sh" "${__scan_args[@]}"; then
    echo "Aborting install — ship-safety scan failed. (Override: SDD_SKIP_SHIP_SCAN=1)" >&2
    exit 1
  fi
fi

# Step 2: Per-project harness file sync
echo ""
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
echo "Done automatically:"
echo "  ✓ .gitignore updated (.claude/ specs/ CLAUDE.md — local-only)"
echo "  ✓ CLAUDE.md created with the project name filled in"
echo "  ✓ /kiro:steering queued — you'll be prompted to run it on your first Claude session"
echo ""
echo "Next steps:"
echo "  1. Refine CLAUDE.md with project-specific context (the basics are in place)"
echo "  2. Open Claude Code in the project and run /kiro:steering when prompted"
if [ "$WITH_GITNEXUS" = false ]; then
  echo ""
  echo "Optional: Run with --with-gitnexus to add code intelligence integration."
  echo "  Or run /kiro:gitnexus-setup inside Claude Code later."
fi

# Check for raindrop CLI (may have just been installed above)
if command -v raindrop >/dev/null 2>&1 || [ -x "$HOME/.raindrop/bin/raindrop" ]; then
  echo "  Raindrop Workshop CLI: installed."
else
  echo ""
  echo "Raindrop Workshop CLI not found. It was likely skipped above."
  echo "  To install manually: curl -fsSL https://raindrop.sh/install | bash"
fi
