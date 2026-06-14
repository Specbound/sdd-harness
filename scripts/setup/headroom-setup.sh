#!/usr/bin/env bash
# headroom-setup.sh — install headroom-ai and wire automatic context compression
#
# Run automatically by install.sh and update.sh. Safe to run manually anytime.
# Idempotent — running multiple times has no side effects.
#
# What this does:
#   1. Installs headroom-ai globally (uv tool, pipx, or pip --user — first that works)
#   2. Installs headroom-ai in each registered repo's detected virtualenv (for Python API use)
#   3. Adds `alias claude='headroom wrap claude --memory'` to ~/.bashrc
#   4. Installs headroom as a persistent systemd service (eliminates cold-start lag)
#
# Why: headroom compresses prompts/messages at the process level (60-95% savings).
# Complementary to RTK (shell output compression) — operates on a different layer.
# Persistent service keeps the proxy warm so `claude` opens in ~1s instead of 10s+.

set -e

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/../lib/resolve-harness-dir.sh"
PROJECTS_FILE="$HARNESS_DIR/projects.txt"
BASHRC="$HOME/.bashrc"
HEADROOM_PKG="headroom-ai"
MARKER="# headroom wrap (added by sdd-harness headroom-setup.sh)"

# ── 1. Install headroom globally so `headroom` is on PATH ──────────────────
echo "  Installing headroom-ai globally..."
INSTALLED_GLOBALLY=0

if command -v uv >/dev/null 2>&1; then
    EXTRAS_FILE="$__here/headroom-extras.txt"
    # headroom-ai is a Rust extension (maturin). No pre-built wheel for Python 3.14+,
    # so try 3.12 first where binary wheels exist, then fall back to default.
    if uv tool install "$HEADROOM_PKG" --python 3.12 \
          --with-requirements "$EXTRAS_FILE" -q 2>/dev/null \
       || uv tool install "$HEADROOM_PKG" \
          --with-requirements "$EXTRAS_FILE" -q 2>/dev/null; then
        echo "    Installed via uv tool."
        INSTALLED_GLOBALLY=1
    fi
fi

if [ "$INSTALLED_GLOBALLY" -eq 0 ] && command -v pipx >/dev/null 2>&1; then
    if pipx install "$HEADROOM_PKG" -q 2>/dev/null || pipx upgrade "$HEADROOM_PKG" -q 2>/dev/null; then
        echo "    Installed via pipx."
        INSTALLED_GLOBALLY=1
    fi
fi

if [ "$INSTALLED_GLOBALLY" -eq 0 ]; then
    if pip install --user "$HEADROOM_PKG" -q 2>/dev/null; then
        echo "    Installed via pip --user."
        INSTALLED_GLOBALLY=1
    fi
fi

if [ "$INSTALLED_GLOBALLY" -eq 0 ]; then
    echo "  WARNING: could not install headroom-ai globally. Install manually:"
    echo "    uv tool install headroom-ai   OR   pip install --user headroom-ai"
fi

# ── 2. Add alias to ~/.bashrc ───────────────────────────────────────────────
# Alias includes --memory (persistent cross-session memory).
# Do NOT add --memory-storage here — that is a headroom proxy flag, not a wrap flag,
# and passing it to 'headroom wrap claude' causes it to be forwarded to claude itself,
# which fails with "unknown option".
DESIRED_ALIAS="alias claude='headroom wrap claude --memory'"
if [ -f "$BASHRC" ]; then
    if grep -qF "$DESIRED_ALIAS" "$BASHRC" 2>/dev/null; then
        echo "  headroom wrap alias already correct in ~/.bashrc"
    elif grep -q "headroom wrap" "$BASHRC" 2>/dev/null; then
        # Exists but outdated (missing --memory or has wrong flags) — update in place
        # -i.bak then remove: portable across GNU (Linux) and BSD (macOS) sed
        sed -i.bak "s|alias claude='headroom wrap claude'.*|$DESIRED_ALIAS|" "$BASHRC" && rm -f "$BASHRC.bak"
        echo "  Updated headroom wrap alias to include --memory in ~/.bashrc"
    else
        printf "\n%s\n# --memory: persistent cross-session memory via headroom SQLite\nalias claude='headroom wrap claude --memory'\n" "$MARKER" >> "$BASHRC"
        echo "  Added alias claude='headroom wrap claude --memory' to ~/.bashrc"
    fi
else
    echo "  WARNING: ~/.bashrc not found — skipping alias injection"
fi

# ── 3. Install headroom-ai in each registered repo's virtualenv ─────────────
install_headroom_in_repo() {
    local repo="$1"

    if [ ! -d "$repo" ]; then
        echo "  SKIP: $repo (directory not found)"
        return
    fi

    # Strategy A: uv + pyproject.toml
    if [ -f "$repo/pyproject.toml" ] && command -v uv >/dev/null 2>&1; then
        if (cd "$repo" && uv pip install "$HEADROOM_PKG" -q 2>/dev/null); then
            echo "  $(basename "$repo"): installed via uv."
            return
        fi
    fi

    # Strategy B: venv in subdirs
    for subdir in "" "/backend" "/app" "/src"; do
        local subpath="$repo$subdir"
        if [ -f "$subpath/requirements.txt" ]; then
            for venv_candidate in \
                "$subpath/.venv" "$subpath/venv" \
                "$repo/.venv"   "$repo/venv"; do
                if [ -f "$venv_candidate/bin/pip" ]; then
                    if "$venv_candidate/bin/pip" install "$HEADROOM_PKG" -q 2>/dev/null; then
                        echo "  $(basename "$repo"): installed via venv $venv_candidate."
                        return
                    fi
                fi
            done
        fi
    done

    # Strategy C: repo root venv regardless of requirements
    for venv_candidate in "$repo/.venv" "$repo/venv"; do
        if [ -f "$venv_candidate/bin/pip" ]; then
            if "$venv_candidate/bin/pip" install "$HEADROOM_PKG" -q 2>/dev/null; then
                echo "  $(basename "$repo"): installed via venv $venv_candidate."
                return
            fi
        fi
    done

    echo "  $(basename "$repo"): no virtualenv detected — skipping repo venv install"
}

if [ ! -s "$PROJECTS_FILE" ]; then
    echo "  No registered projects found — skipping venv installs."
else
    echo "  Installing headroom-ai in registered repo virtualenvs..."
    while IFS= read -r project || [ -n "$project" ]; do
        [ -n "$project" ] && install_headroom_in_repo "$project"
    done < "$PROJECTS_FILE"
fi

# ── 4. Install headroom as a persistent service ─────────────────────────────
# Keeps the proxy warm between sessions — eliminates cold-start delay (~10s → ~1s).
# Only runs when headroom is installed and a service supervisor is available.
# Idempotent: skips if service already installed and healthy.
if command -v headroom >/dev/null 2>&1; then
    if headroom install status >/dev/null 2>&1; then
        echo "  Headroom persistent service already installed."
    elif command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
        echo "  Installing headroom persistent service (systemd user service)..."
        if headroom install apply --memory 2>/dev/null; then
            echo "  Headroom persistent service installed and started."
            echo "  Proxy will auto-start on login — claude opens in ~1s."
        else
            echo "  WARNING: persistent service install failed — cold starts will be ~10s."
            echo "    Fix manually: headroom install apply --memory"
        fi
    else
        echo "  Skipping persistent service (no supported supervisor found)."
        echo "    For fast startup, run manually when supervisor is available:"
        echo "    headroom install apply --memory"
    fi
else
    echo "  Skipping persistent service (headroom not installed)."
fi

echo ""
echo "Headroom setup complete."
echo "  Reload shell or run: source ~/.bashrc"
echo "  Verify: headroom verify"
