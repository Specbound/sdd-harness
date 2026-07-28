#!/usr/bin/env bash
# headroom-setup.sh — install headroom-ai and wire automatic context compression
#
# Run automatically by install.sh and update.sh. Safe to run manually anytime.
# Idempotent — running multiple times has no side effects.
#
# What this does:
#   1. Installs headroom-ai globally (uv tool, pipx, or pip --user — first that works)
#   2. Installs headroom-ai in each registered repo's detected virtualenv (for Python API use)
#   3. Wires Claude Code to route through the proxy (durable, all shells + GUI)
#   4. Installs headroom as a persistent service (launchd on macOS, systemd on Linux)
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

# ── 2. Retire the legacy wrap alias (routing is now durable — see section 4) ─
# Older installs added `alias claude='headroom wrap claude'` to ~/.bashrc. That is
# fragile (bash-only; macOS default shell is zsh, so it never loaded) and it fights
# the persistent service for the same port. Durable settings.json routing (wired in
# section 4, only after the proxy is confirmed healthy) replaces it on every shell.
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ] && grep -q "headroom wrap" "$RC" 2>/dev/null; then
        sed -i.bak -e "/headroom wrap (added by sdd-harness/d" -e "/alias claude=.*headroom wrap/d" "$RC" && rm -f "$RC.bak"
        echo "  Removed legacy headroom wrap alias from $(basename "$RC") (durable routing supersedes it)."
    fi
done

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
    else
        # `headroom install apply` auto-detects the supervisor:
        #   macOS -> launchd LaunchAgent, Linux -> systemd user service.
        # The first start loads the compression model and can miss the readiness
        # window, so retry once before giving up.
        case "$(uname -s)" in
            Darwin|Linux)
                echo "  Installing headroom persistent service ($(uname -s))..."
                if headroom install apply --preset persistent-service --memory \
                   || { echo "  First start missed readiness (model warm-up) — retrying..."; sleep 3; headroom install apply --preset persistent-service --memory; }; then
                    echo "  Headroom persistent service installed and started (auto-starts on login)."
                    # Route Claude Code through the proxy ONLY after it is confirmed
                    # healthy, so ANTHROPIC_BASE_URL never points at a dead proxy.
                    if curl -fsS -m 8 "http://127.0.0.1:${HEADROOM_PORT:-8787}/readyz" >/dev/null 2>&1; then
                        if headroom init --global --memory claude >/dev/null 2>&1; then
                            echo "  Claude Code routed through headroom (durable, all shells + GUI)."
                        else
                            echo "  WARNING: routing not wired. Run manually: headroom init --global --memory claude"
                        fi
                    else
                        echo "  WARNING: proxy not healthy yet — skipped routing to avoid breaking Claude API calls."
                        echo "    Once healthy, run: headroom init --global --memory claude"
                    fi
                else
                    echo "  WARNING: persistent service install failed after retry — routing NOT wired, cold starts ~10s."
                    echo "    Fix manually: headroom install apply --preset persistent-service --memory"
                fi ;;
            *)
                echo "  Skipping persistent service (unsupported OS: $(uname -s))." ;;
        esac
    fi
else
    echo "  Skipping persistent service (headroom not installed)."
fi

echo ""
echo "Headroom setup complete."
echo "  Reload shell or run: source ~/.bashrc"
echo "  Verify: headroom verify"
