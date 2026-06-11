#!/usr/bin/env bash
# headroom-setup.sh — install headroom-ai and wire automatic context compression
#
# Run automatically by install.sh and update.sh. Safe to run manually anytime.
# Idempotent — running multiple times has no side effects.
#
# What this does:
#   1. Installs headroom-ai globally (uv tool, pipx, or pip --user — first that works)
#   2. Installs headroom-ai in each registered repo's detected virtualenv (for Python API use)
#   3. Adds `alias claude='headroom wrap claude'` to ~/.bashrc
#
# Why: headroom compresses prompts/messages at the process level (60-95% savings).
# Complementary to RTK (shell output compression) — operates on a different layer.

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
    # headroom-ai is a Rust extension (maturin). No pre-built wheel for Python 3.14+,
    # so try 3.12 first where binary wheels exist, then fall back to default.
    if uv tool install "$HEADROOM_PKG" --python 3.12 \
          --with numpy --with sqlite-vec --with sentence-transformers -q 2>/dev/null \
       || uv tool install "$HEADROOM_PKG" \
          --with numpy --with sqlite-vec --with sentence-transformers -q 2>/dev/null; then
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
if [ -f "$BASHRC" ]; then
    if grep -q "headroom wrap" "$BASHRC" 2>/dev/null; then
        echo "  headroom wrap alias already in ~/.bashrc"
    else
        printf "\n%s\nalias claude='headroom wrap claude'\n" "$MARKER" >> "$BASHRC"
        echo "  Added alias claude='headroom wrap claude' to ~/.bashrc"
    fi
else
    echo "  WARNING: ~/.bashrc not found — skipping alias injection"
fi

# ── 3. Install headroom-ai in each registered repo's virtualenv ─────────────
if [ ! -s "$PROJECTS_FILE" ]; then
    echo "  No registered projects found — skipping venv installs."
    exit 0
fi

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

echo "  Installing headroom-ai in registered repo virtualenvs..."
while IFS= read -r project || [ -n "$project" ]; do
    [ -n "$project" ] && install_headroom_in_repo "$project"
done < "$PROJECTS_FILE"

echo ""
echo "Headroom setup complete."
echo "  Reload shell or run: source ~/.bashrc"
echo "  Verify: headroom verify"
