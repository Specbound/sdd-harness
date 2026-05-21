#!/usr/bin/env bash
# raindrop-setup.sh — wire Raindrop Workshop into all registered repos
#
# Run automatically by install.sh and update.sh. Safe to run manually anytime.
# Idempotent — running multiple times has no side effects.
#
# What this does:
#   1. Adds RAINDROP_LOCAL_DEBUGGER to ~/.claude/settings.json (Claude env)
#   2. Adds RAINDROP_LOCAL_DEBUGGER export to ~/.bashrc (user shell processes)
#   3. Installs raindrop-ai in each registered repo's detected virtualenv
#
# Nothing in any repo's .env file is touched.

set -e

HARNESS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECTS_FILE="$HARNESS_DIR/projects.txt"
GLOBAL_SETTINGS="$HOME/.claude/settings.json"
RAINDROP_URL="http://localhost:5899/v1/"

# ── 1. Inject env var into ~/.claude/settings.json ─────────────────────────
if [ -f "$GLOBAL_SETTINGS" ]; then
    python3 - "$GLOBAL_SETTINGS" "$RAINDROP_URL" <<'PYEOF'
import json, sys
path, url = sys.argv[1], sys.argv[2]
with open(path) as f:
    d = json.load(f)
d.setdefault("env", {})
if d["env"].get("RAINDROP_LOCAL_DEBUGGER") == url:
    print("  RAINDROP_LOCAL_DEBUGGER already set in ~/.claude/settings.json")
else:
    d["env"]["RAINDROP_LOCAL_DEBUGGER"] = url
    with open(path, "w") as f:
        json.dump(d, f, indent=2)
    print("  Added RAINDROP_LOCAL_DEBUGGER to ~/.claude/settings.json")
PYEOF
else
    echo "  WARNING: ~/.claude/settings.json not found — skipping global env injection"
fi

# ── 2. Inject env var into ~/.bashrc (for user-run processes) ───────────────
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ]; then
    if grep -q "RAINDROP_LOCAL_DEBUGGER" "$BASHRC" 2>/dev/null; then
        echo "  RAINDROP_LOCAL_DEBUGGER already in ~/.bashrc"
    else
        printf '\n# Raindrop Workshop (added by sdd-harness raindrop-setup.sh)\nexport RAINDROP_LOCAL_DEBUGGER=%s\n' "$RAINDROP_URL" >> "$BASHRC"
        echo "  Added RAINDROP_LOCAL_DEBUGGER to ~/.bashrc"
    fi
fi

# ── 3. Install raindrop-ai in each registered repo's virtualenv ─────────────
if [ ! -s "$PROJECTS_FILE" ]; then
    echo "  No registered projects found — skipping venv installs."
    exit 0
fi

install_raindrop_in_repo() {
    local repo="$1"

    if [ ! -d "$repo" ]; then
        echo "  SKIP: $repo (directory not found)"
        return
    fi

    # Strategy A: uv + pyproject.toml
    if [ -f "$repo/pyproject.toml" ] && command -v uv >/dev/null 2>&1; then
        echo "  Installing raindrop-ai in $(basename "$repo") (uv)..."
        if (cd "$repo" && uv pip install raindrop-ai -q 2>/dev/null); then
            echo "    Done."
            return
        fi
    fi

    # Strategy B: subdirectory with requirements.txt (e.g. backend/)
    for subdir in "" "/backend" "/app" "/src"; do
        local subpath="$repo$subdir"
        if [ -f "$subpath/requirements.txt" ]; then
            # Find the venv — check subdir first, then repo root
            for venv_candidate in \
                "$subpath/.venv" "$subpath/venv" \
                "$repo/.venv"   "$repo/venv"; do
                if [ -f "$venv_candidate/bin/pip" ]; then
                    echo "  Installing raindrop-ai in $(basename "$repo")${subdir} (venv: $venv_candidate)..."
                    if "$venv_candidate/bin/pip" install raindrop-ai -q 2>/dev/null; then
                        echo "    Done."
                        return
                    fi
                fi
            done
        fi
    done

    # Strategy C: fallback — try repo root venv regardless of requirements file
    for venv_candidate in "$repo/.venv" "$repo/venv"; do
        if [ -f "$venv_candidate/bin/pip" ]; then
            echo "  Installing raindrop-ai in $(basename "$repo") (venv: $venv_candidate)..."
            if "$venv_candidate/bin/pip" install raindrop-ai -q 2>/dev/null; then
                echo "    Done."
                return
            fi
        fi
    done

    echo "  WARNING: Could not detect a virtualenv for $repo"
    echo "    Manually run: pip install raindrop-ai  (inside the project's active venv)"
}

echo "  Installing raindrop-ai in registered repos..."
while IFS= read -r project || [ -n "$project" ]; do
    [ -n "$project" ] && install_raindrop_in_repo "$project"
done < "$PROJECTS_FILE"

# ── 4. Auto-instrument repos that have the SDK but no raindrop.begin calls ───
maybe_auto_instrument() {
    local repo="$1"

    if [ ! -d "$repo" ]; then return; fi

    # Skip if already instrumented (timeout avoids slow WSL2/Windows filesystem greps)
    local grep_rc=0
    timeout 20 grep -rq "raindrop.begin" "$repo" --include="*.py" --include="*.ts" 2>/dev/null || grep_rc=$?
    if [ "$grep_rc" -eq 0 ]; then
        echo "  $(basename "$repo"): already instrumented — skipping auto-instrument"
        return
    fi
    if [ "$grep_rc" -eq 124 ]; then
        echo "  $(basename "$repo"): grep timed out — skipping auto-instrument"
        return
    fi

    # Only proceed if SDK is available in the repo's venv
    local has_sdk=0
    for venv_candidate in "$repo/.venv" "$repo/venv" "$repo/backend/.venv" "$repo/backend/venv"; do
        if [ -f "$venv_candidate/bin/python" ]; then
            if timeout 10 "$venv_candidate/bin/python" -c "import raindrop.analytics" 2>/dev/null; then
                has_sdk=1
                break
            fi
        fi
    done
    if [ "$has_sdk" -eq 0 ] && command -v uv >/dev/null 2>&1 && [ -f "$repo/pyproject.toml" ]; then
        if (cd "$repo" && timeout 10 uv run python -c "import raindrop.analytics" 2>/dev/null); then
            has_sdk=1
        fi
    fi

    if [ "$has_sdk" -eq 0 ]; then
        echo "  $(basename "$repo"): SDK not importable — skipping auto-instrument"
        return
    fi

    local log_file="/tmp/raindrop-instrument-$(basename "$repo").log"
    local prompt="Use the instrument-agent skill to instrument this repository for Raindrop Workshop.
Repository path: $repo
Rules:
- Use your best judgment to identify the main agent entry point (the function/route that triggers an LLM call)
- Do NOT ask clarifying questions — make a decision and instrument it
- Set event name equal to the repo basename: $(basename "$repo")
- Set RAINDROP_LOCAL_DEBUGGER=$RAINDROP_URL via env var (already injected; do not touch .env files)
- Add raindrop.begin() at the entry point and interaction.finish() at all exit paths
- Add set_properties() with any useful per-request metadata you find (user_id, session_id, etc.)
- If you cannot find a clear entry point after exploring the repo, write a single line to $log_file explaining why and exit cleanly"

    echo "  $(basename "$repo"): SDK found but not instrumented — spawning auto-instrument agent..."
    echo "    Log: $log_file"
    RAINDROP_LOCAL_DEBUGGER="$RAINDROP_URL" nohup claude --print --permission-mode bypassPermissions "$prompt" > "$log_file" 2>&1 &
    echo "    Agent PID $! running in background"
}

echo ""
echo "  Checking repos for auto-instrumentation..."
while IFS= read -r project || [ -n "$project" ]; do
    [ -n "$project" ] && maybe_auto_instrument "$project"
done < "$PROJECTS_FILE"

echo ""
echo "Raindrop setup complete."
echo "  Reload your shell or run: source ~/.bashrc"
echo "  Then install the CLI (one-time): curl -fsSL https://raindrop.sh/install | bash"
echo "  Auto-instrument logs: /tmp/raindrop-instrument-<repo>.log"
