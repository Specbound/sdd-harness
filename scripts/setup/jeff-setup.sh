#!/usr/bin/env bash
# jeff-setup.sh — clone and install the `jeff` local classifier
# (github.com/logan-markewich/jeff) for the model router's Requirement 2
# (local, non-generative classifier). jeff is not a resident service: it is
# started on demand with the router by scripts/router/router-ctl.sh.
#
# Safe to run manually. Idempotent — running it twice does not re-clone,
# re-download the model, or regenerate the API key.
#
# What this does:
#   1. Resolves `uv` via scripts/lib/tool-paths.sh (never assumed on PATH)
#   2. Clones jeff to ~/.sdd-router/jeff (skips if already cloned)
#   3. `uv sync --extra onnx` — NOT `--extra dev` (see note below)
#   4. `uv run hf download knowledgator/gliformer-large-v1 --local-dir models/gliformer-large-v1`
#   5. Generates a real JEFF_API_KEYS value into jeff's env file only
#      — never into router.toml, never into this repo
#   6. Starts jeff temporarily, preflights one real classification call (exit 1
#      on failure), and stops it again
#   7. Prints the (mixed) licence line
#
# --extra onnx, not --extra dev: jeff's pyproject.toml defines `dev` as
# [pytest, pytest-asyncio, ruff, ty] — no ONNX runtime at all — and a separate
# `onnx` extra = [onnx, onnxruntime]. Task 8.1's literal spec text says
# `--extra dev`, which is a spec error: it would leave JEFF_BACKEND=onnx unable
# to import onnxruntime. `--extra onnx` is what design.md's own text says and
# the only extra that actually provides the backend this task requires.
#
# Python pin: jeff's pyproject.toml already declares
# `requires-python = ">=3.12,<3.13"`. Plain `uv sync` (no --python flag) resolves
# this correctly on its own — uv reads requires-python from the project and will
# provision a matching managed interpreter if none is found — so this script
# does not duplicate the explicit `uv python find`/`install` dance that the
# router's own setup (task 9.1) uses for its unconstrained >=3.11 interpreter.
# That dance exists there because the router has no pin of its own to resolve
# against; jeff already has one, in its own pyproject.toml.
#
# Existing clone handling: a pre-existing ~/.sdd-router/jeff is left alone (no
# `git fetch`, no re-checkout) on every run after the first. Only a *fresh*
# clone is checked out to the verified-good commit (34b32f9). Re-pinning an
# existing clone on every run risks clobbering any local state (e.g. uv's own
# lockfile resolution) for a clone that already works, which is the same
# "never overwrite what's already there" rule this harness applies to
# router.toml. If jeff ships a breaking change upstream, re-pinning is a
# deliberate `rm -rf ~/.sdd-router/jeff` away, not a silent side effect of
# re-running setup.

set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# tool-paths.sh resolves `uv` without depending on the caller's PATH.
# Verifies: specs/model-router/requirements.md#10.2 (idempotent setup must not
# silently depend on an interactive-shell PATH it won't have under automation).
. "$__here/../lib/tool-paths.sh"
ensure_tool_bin_on_path

JEFF_DIR="$HOME/.sdd-router/jeff"
JEFF_REPO_URL="https://github.com/logan-markewich/jeff"
JEFF_PIN="34b32f9"
MODEL_SUBDIR="models/gliformer-large-v1"
HF_MODEL_ID="knowledgator/gliformer-large-v1"
SECRET_ENV_FILE="$JEFF_DIR/.jeff-service.env"

# Verified default; overridable by the caller's environment before invoking
# this script (e.g. JEFF_PORT=8001 ./jeff-setup.sh) without editing the file.
JEFF_PORT_DEFAULT="8000"
JEFF_PORT="${JEFF_PORT:-$JEFF_PORT_DEFAULT}"


die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "  $*"; }

# ── 0. Resolve uv (never assumed on PATH) ───────────────────────────────────
UV_BIN="$(find_tool uv || true)"
[ -n "$UV_BIN" ] || die "uv not found (not installed, not on PATH, not in any known tool dir). Install: https://docs.astral.sh/uv/getting-started/installation/"
note "uv resolved at $UV_BIN"

# ── 1. Clone jeff (idempotent — leaves an existing clone alone) ────────────
if [ -d "$JEFF_DIR/.git" ]; then
  note "jeff already cloned at $JEFF_DIR (left as-is; see header note on re-pinning)."
else
  note "Cloning jeff into $JEFF_DIR..."
  mkdir -p "$(dirname "$JEFF_DIR")"
  git clone -q "$JEFF_REPO_URL" "$JEFF_DIR" || die "git clone of $JEFF_REPO_URL failed"
  ( cd "$JEFF_DIR" && git checkout -q "$JEFF_PIN" ) || die "checkout of verified commit $JEFF_PIN failed"
  note "Cloned and pinned to verified commit $JEFF_PIN."
fi
[ -f "$JEFF_DIR/pyproject.toml" ] || die "$JEFF_DIR does not look like a jeff checkout (no pyproject.toml)"

# ── 2. uv sync --extra onnx (see header note: --extra dev is a spec error) ─
note "Running 'uv sync --extra onnx' in $JEFF_DIR (plain sync — pyproject.toml already pins Python 3.12 exact)..."
( cd "$JEFF_DIR" && "$UV_BIN" sync --extra onnx ) || die "'uv sync --extra onnx' failed in $JEFF_DIR"

# ── 3. Fetch model weights (idempotent — skipped once the dir is non-empty) ─
MODEL_PATH="$JEFF_DIR/$MODEL_SUBDIR"
if [ -d "$MODEL_PATH" ] && [ -n "$(ls -A "$MODEL_PATH" 2>/dev/null)" ]; then
  note "Model weights already present at $MODEL_PATH — skipping download."
else
  note "Downloading $HF_MODEL_ID into $MODEL_SUBDIR (relative to $JEFF_DIR, matching JEFF_MODEL's default)..."
  ( cd "$JEFF_DIR" && "$UV_BIN" run hf download "$HF_MODEL_ID" --local-dir "$MODEL_SUBDIR" ) \
    || die "model download failed ($HF_MODEL_ID -> $MODEL_SUBDIR)"
fi

# ── 4. Generate JEFF_API_KEYS into the service environment ONLY ────────────
# Verifies: specs/model-router/requirements.md#9.1 (no paid/metered dependency —
# this is a local secret, not a credential for any third-party service) and the
# task's own explicit instruction: never into router.toml, never into this repo.
# Reused across runs (not regenerated) so existing bearer-token holders are not
# silently invalidated by re-running setup.
if [ -f "$SECRET_ENV_FILE" ] && grep -q '^JEFF_API_KEYS=' "$SECRET_ENV_FILE" 2>/dev/null; then
  JEFF_API_KEYS="$(grep '^JEFF_API_KEYS=' "$SECRET_ENV_FILE" | head -1 | cut -d= -f2-)"
  note "Reusing existing JEFF_API_KEYS from $SECRET_ENV_FILE."
else
  if command -v openssl >/dev/null 2>&1; then
    JEFF_API_KEYS="$(openssl rand -hex 32)"
  else
    JEFF_API_KEYS="$(cd "$JEFF_DIR" && "$UV_BIN" run python -c 'import secrets; print(secrets.token_hex(32))')"
  fi
  [ -n "$JEFF_API_KEYS" ] || die "could not generate a JEFF_API_KEYS value (no openssl, and uv run python fallback failed)"
  {
    echo "JEFF_HOST=127.0.0.1"
    echo "JEFF_PORT=$JEFF_PORT"
    echo "JEFF_BACKEND=onnx"
    echo "JEFF_QUANT=int8"
    echo "JEFF_API_KEYS=$JEFF_API_KEYS"
    [ -n "${JEFF_THREADS:-}" ] && echo "JEFF_THREADS=$JEFF_THREADS"
  } > "$SECRET_ENV_FILE"
  chmod 600 "$SECRET_ENV_FILE"
  note "Generated JEFF_API_KEYS and wrote service environment to $SECRET_ENV_FILE (chmod 600)."
fi

# ── 5. No resident service — start jeff only for the preflight ─────────────
# router-ctl.sh starts jeff alongside the sentinel and worker when a wired
# harness session starts, and stops it after the last one ends. Earlier
# versions installed a launchd/systemd unit here; router-setup.sh removes it.
JEFF_PREFLIGHT_PID=""
stop_preflight_jeff() {
  [ -n "$JEFF_PREFLIGHT_PID" ] || return 0
  # `uv run`'s model-serving python is a child of the recorded pid.
  pkill -TERM -P "$JEFF_PREFLIGHT_PID" 2>/dev/null || true
  kill "$JEFF_PREFLIGHT_PID" 2>/dev/null || true
}
trap stop_preflight_jeff EXIT

if (exec 3<>"/dev/tcp/127.0.0.1/$JEFF_PORT") 2>/dev/null; then
  note "jeff already listening on 127.0.0.1:$JEFF_PORT — preflighting the running instance."
else
  mkdir -p "$JEFF_DIR/.logs"
  ( cd "$JEFF_DIR" && set -a && . "$SECRET_ENV_FILE" && set +a && exec "$UV_BIN" run jeff ) \
    >>"$JEFF_DIR/.logs/jeff.preflight.log" 2>&1 &
  JEFF_PREFLIGHT_PID=$!
  note "Started jeff temporarily (pid $JEFF_PREFLIGHT_PID) for the preflight — model load takes a while."
fi

# ── 6. Preflight — one real classification, exit 1 on failure ──────────────
# Verifies: specs/model-router/requirements.md#10.3 (setup must verify by
# executing, not by assuming) and #2.1 (loopback-only — note 127.0.0.1, never
# 0.0.0.0, in both the request below and jeff's env file above).
{
  note "Preflighting jeff with one real classification..."
  PAYLOAD='{"state": "test", "model": "jev-latest", "questions": {"check": {"type": "noul", "instructions": "test"}}}'
  CODE=""
  for _ in $(seq 1 90); do
    CODE="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 -m 5 \
      -X POST "http://127.0.0.1:${JEFF_PORT}/v1/systemone" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${JEFF_API_KEYS}" \
      -d "$PAYLOAD" 2>/dev/null || true)"
    [ "$CODE" = "200" ] && break
    sleep 1
  done
  if [ "$CODE" = "200" ]; then
    note "Preflight passed — real classification returned HTTP 200."
  else
    die "preflight failed — jeff at 127.0.0.1:${JEFF_PORT}/v1/systemone did not return 200 (got: ${CODE:-no response})"
  fi
}

# ── 7. Licence line (R9.3) — mixed, NOT "MIT" alone ─────────────────────────
echo ""
echo "jeff: MIT; gliformer-large-v1 weights: Apache-2.0"
echo ""
echo "jeff-setup complete."
