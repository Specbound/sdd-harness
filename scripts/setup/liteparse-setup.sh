#!/usr/bin/env bash
# liteparse-setup.sh — own liteparse in a dedicated, version-pinned harness venv
#
# Run automatically by install.sh and update.sh. Safe to run manually anytime.
# Idempotent — running multiple times has no side effects.
#
# Why a venv (not `pip install --user`):
#   liteparse needs Python >=3.10 with a binary wheel, but the ambient `python3`
#   is often Apple's 3.9 (too old) or a PEP-668 'externally-managed' Homebrew/
#   Debian interpreter that refuses `--user`. A self-owned venv sidesteps both:
#   a locked >=3.10 interpreter, no --break-system-packages, no "which python3"
#   roulette. The document-parsing skill points at this venv's python / lit.
#
# Location: <harness root>/.venv-tools  (gitignored; pruned by ship-safety-scan).
#   Resolvable from any repo as ${SDD_HARNESS_HOME:-$HOME/.claude/sdd-harness}/.venv-tools
#   because ~/.claude/sdd-harness symlinks to the harness root.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/../lib/resolve-harness-dir.sh"

VENV_DIR="$HARNESS_DIR/.venv-tools"

# Resolve the venv's python across OSes (POSIX: bin/python, Windows: Scripts/python.exe).
venv_py() {
  if [ -x "$VENV_DIR/bin/python" ]; then
    echo "$VENV_DIR/bin/python"
  elif [ -x "$VENV_DIR/Scripts/python.exe" ]; then
    echo "$VENV_DIR/Scripts/python.exe"
  else
    echo ""
  fi
}

# --- Fast path: venv already has an importable liteparse ---
VPY="$(venv_py)"
if [ -n "$VPY" ] && "$VPY" -c 'import liteparse' >/dev/null 2>&1; then
  echo "  liteparse already installed (.venv-tools: $("$VPY" --version 2>&1))."
  exit 0
fi

# --- Health check: if venv exists but Python is broken (uv standalone with missing stdlib),
#     remove it so we rebuild with a working interpreter.
if [ -n "$VPY" ] && ! "$VPY" -c 'import sys' >/dev/null 2>&1; then
  echo "  .venv-tools has a broken Python (likely a uv standalone) — removing and rebuilding."
  rm -rf "$VENV_DIR"
  VPY=""
fi

# --- Create the venv if missing ---
# Strategy: uv-managed Pythons (e.g. ~/.local/bin/python3.12) have their stdlib
# rooted at a standalone prefix that doesn't exist at runtime outside uv, so
# `python -m venv` fails with "ModuleNotFoundError: No module named 'encodings'".
# Fix: try `uv venv` first (uv resolves a working interpreter), then system
# paths (/usr/bin/python3.*), then bare names as a last resort.
if [ -z "$VPY" ]; then
  VENV_CREATED=0

  # 1. uv venv --seed — picks a properly-linked interpreter automatically and
  #    seeds pip so `python -m pip` works inside the venv without ensurepip.
  if command -v uv >/dev/null 2>&1; then
    if uv venv --python '>=3.10' --seed "$VENV_DIR" >/dev/null 2>&1; then
      VENV_CREATED=1
    fi
  fi

  # 2. System Python paths — skip uv-shim paths under ~/.local/bin
  if [ "$VENV_CREATED" -eq 0 ]; then
    for cand in /usr/bin/python3.13 /usr/bin/python3.12 /usr/bin/python3.11 /usr/bin/python3.10 /usr/bin/python3 python3.13 python3.12 python3.11 python3.10 python3; do
      command -v "$cand" >/dev/null 2>&1 || continue
      # Skip uv-managed standalones — they embed a broken base_prefix at venv time
      case "$("$cand" -c 'import sys; print(sys.base_prefix)' 2>/dev/null)" in
        /home/*/.local/share/uv/*|/root/.local/share/uv/*) continue ;;
      esac
      if "$cand" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,10) else 1)' 2>/dev/null; then
        if "$cand" -m venv "$VENV_DIR" 2>/dev/null; then
          VENV_CREATED=1
          break
        fi
      fi
    done
  fi

  if [ "$VENV_CREATED" -eq 0 ]; then
    echo "  liteparse skipped — could not create venv (no working Python >=3.10; try: uv python install 3.12)."
    exit 1
  fi
  VPY="$(venv_py)"
fi

if [ -z "$VPY" ]; then
  echo "  liteparse skipped — venv created but no python found under $VENV_DIR."
  exit 1
fi

# --- Install liteparse inside the venv (no --user / --break-system-packages needed) ---
"$VPY" -m pip install -q --upgrade pip >/dev/null 2>&1 || true
if "$VPY" -m pip install -q --upgrade liteparse >/dev/null 2>&1 \
   && "$VPY" -c 'import liteparse' >/dev/null 2>&1; then
  echo "  liteparse installed (.venv-tools: $("$VPY" --version 2>&1))."
  exit 0
fi

echo "  liteparse skipped — install into .venv-tools failed (build a wheel-compatible Python >=3.10)."
exit 1
