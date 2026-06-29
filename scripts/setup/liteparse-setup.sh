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

# --- Pick a wheel-friendly interpreter >=3.10 to build the venv ---
# Prefer explicit 3.13/3.12/3.11/3.10 over bare `python3` (which may be Apple's
# 3.9 or a too-new release lacking compiled wheels). Require >=3.10 explicitly.
PYBIN=""
for cand in python3.13 python3.12 python3.11 python3.10 python3; do
  command -v "$cand" >/dev/null 2>&1 || continue
  if "$cand" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,10) else 1)' 2>/dev/null; then
    PYBIN="$cand"; break
  fi
done

if [ -z "$PYBIN" ]; then
  echo "  liteparse skipped — no Python >=3.10 found (install python3.11+ to enable document-parsing)."
  exit 0
fi

# --- Create the venv if missing ---
if [ -z "$VPY" ]; then
  if ! "$PYBIN" -m venv "$VENV_DIR" 2>/dev/null; then
    echo "  liteparse skipped — could not create venv with $PYBIN ($("$PYBIN" --version 2>&1))."
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
