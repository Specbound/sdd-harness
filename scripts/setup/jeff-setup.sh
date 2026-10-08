#!/usr/bin/env bash
# jeff-setup.sh — clone, install, and run the `jeff` local classifier
# (github.com/logan-markewich/jeff) as a resident loopback service for the
# model router's Requirement 2 (local, non-generative classifier).
#
# Safe to run manually, and run automatically by the router's own setup.
# Idempotent — running it twice does not re-clone, re-download the model,
# regenerate the API key, or duplicate the service registration.
#
# What this does:
#   1. Resolves `uv` via scripts/lib/tool-paths.sh (never assumed on PATH)
#   2. Clones jeff to ~/.sdd-router/jeff (skips if already cloned)
#   3. `uv sync --extra onnx` — NOT `--extra dev` (see note below)
#   4. `uv run hf download knowledgator/gliformer-large-v1 --local-dir models/gliformer-large-v1`
#   5. Generates a real JEFF_API_KEYS value into the service environment only
#      — never into router.toml, never into this repo
#   6. Installs a launchd (Darwin) / systemd (Linux, incl. systemd-enabled WSL)
#      user service; skips cleanly on Git Bash / unknown OS
#   7. Preflights by sending one real classification call and exits 1 on failure
#   8. Prints the (mixed) licence line
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

LAUNCHD_LABEL="com.sdd.jeff-classifier"
SYSTEMD_UNIT="sdd-jeff-classifier.service"

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "  $*"; }

# ── OS detection — same four cases + unknown fallback as install.sh's
#    canonical detect_os(), kept local here since task 8.1's blast radius is
#    this one file. Verifies: specs/model-router/requirements.md#10.4.
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

# ── 5. Install as a persistent user service, branching detect_os() ─────────
# Verifies: specs/model-router/requirements.md#10.4 (all four detect_os() cases)
# and #2.6 (CPU-only backend is what JEFF_BACKEND=onnx/JEFF_QUANT=int8 select).
SDD_OS="$(detect_os)"
SERVICE_INSTALLED=0
SERVICE_ALREADY_RUNNING=0

install_service_macos() {
  local plist_dir="$HOME/Library/LaunchAgents"
  local plist_path="$plist_dir/$LAUNCHD_LABEL.plist"
  local log_dir="$JEFF_DIR/.logs"
  mkdir -p "$plist_dir" "$log_dir"

  if launchctl list "$LAUNCHD_LABEL" >/dev/null 2>&1; then
    note "LaunchAgent '$LAUNCHD_LABEL' already loaded — skipping registration."
    SERVICE_ALREADY_RUNNING=1
    return 0
  fi

  local threads_xml=""
  if [ -n "${JEFF_THREADS:-}" ]; then
    threads_xml="    <key>JEFF_THREADS</key><string>${JEFF_THREADS}</string>"
  fi

  # ExecStart equivalent: absolute uv path, never a bare `uv`/`jeff` — same
  # discipline task 9.1 names explicitly for its own interpreter.
  cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>${LAUNCHD_LABEL}</string>
    <key>WorkingDirectory</key><string>${JEFF_DIR}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${UV_BIN}</string>
        <string>run</string>
        <string>jeff</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>JEFF_HOST</key><string>127.0.0.1</string>
        <key>JEFF_PORT</key><string>${JEFF_PORT}</string>
        <key>JEFF_BACKEND</key><string>onnx</string>
        <key>JEFF_QUANT</key><string>int8</string>
        <key>JEFF_API_KEYS</key><string>${JEFF_API_KEYS}</string>
${threads_xml}
    </dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>${log_dir}/jeff.stdout.log</string>
    <key>StandardErrorPath</key><string>${log_dir}/jeff.stderr.log</string>
</dict>
</plist>
PLIST

  if launchctl load -w "$plist_path"; then
    note "LaunchAgent '$LAUNCHD_LABEL' registered and started."
    SERVICE_INSTALLED=1
  else
    die "launchctl load failed for $plist_path"
  fi
}

install_service_linux() {
  local unit_dir="$HOME/.config/systemd/user"
  local unit_path="$unit_dir/$SYSTEMD_UNIT"
  mkdir -p "$unit_dir"

  if systemctl --user is-active --quiet "$SYSTEMD_UNIT" 2>/dev/null; then
    note "systemd user service '$SYSTEMD_UNIT' already active — skipping registration."
    SERVICE_ALREADY_RUNNING=1
    return 0
  fi

  cat > "$unit_path" <<UNIT
[Unit]
Description=sdd-harness jeff classifier (model-router local classifier)
After=network.target

[Service]
WorkingDirectory=${JEFF_DIR}
EnvironmentFile=${SECRET_ENV_FILE}
ExecStart=${UV_BIN} run jeff
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
UNIT

  systemctl --user daemon-reload || die "systemctl --user daemon-reload failed"
  if systemctl --user enable --now "$SYSTEMD_UNIT"; then
    note "systemd user service '$SYSTEMD_UNIT' installed and started."
    SERVICE_INSTALLED=1
  else
    die "systemctl --user enable --now failed for $SYSTEMD_UNIT"
  fi
}

case "$SDD_OS" in
  macos)
    install_service_macos
    ;;
  linux)
    install_service_linux
    ;;
  wsl)
    # Modern WSL2 can run systemd when enabled (`[boot] systemd=true` in
    # /etc/wsl.conf); plenty of installs still don't. Use it when present,
    # skip cleanly (per task 8.1 bullet 8) rather than guess otherwise.
    if [ -d /run/systemd/system ] && systemctl --user show-environment >/dev/null 2>&1; then
      install_service_linux
    else
      note "Skipping persistent service: WSL without systemd enabled."
      note "  Enable it (add '[boot]\\nsystemd=true' to /etc/wsl.conf, then 'wsl --shutdown')"
      note "  or run jeff manually: cd $JEFF_DIR && JEFF_HOST=127.0.0.1 JEFF_PORT=$JEFF_PORT JEFF_BACKEND=onnx JEFF_QUANT=int8 JEFF_API_KEYS=*** $UV_BIN run jeff"
    fi
    ;;
  gitbash)
    note "Skipping persistent service: Git Bash has no launchd/systemd equivalent for a resident process."
    note "  Run jeff manually: cd $JEFF_DIR && JEFF_HOST=127.0.0.1 JEFF_PORT=$JEFF_PORT JEFF_BACKEND=onnx JEFF_QUANT=int8 JEFF_API_KEYS=*** $UV_BIN run jeff"
    ;;
  *)
    note "Skipping persistent service: unrecognized OS ($(uname -s 2>/dev/null))."
    ;;
esac

# ── 6. Preflight — one real classification, exit 1 on failure ──────────────
# Verifies: specs/model-router/requirements.md#10.3 (setup must verify by
# executing, not by assuming) and #2.1 (loopback-only — note 127.0.0.1, never
# 0.0.0.0, in both the request below and the service env above).
if [ "$SERVICE_INSTALLED" -eq 1 ] || [ "$SERVICE_ALREADY_RUNNING" -eq 1 ]; then
  note "Preflighting jeff with one real classification..."
  PAYLOAD='{"state": "test", "model": "jev-latest", "questions": {"check": {"type": "noul", "instructions": "test"}}}'
  CODE=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
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
else
  note "No service installed/running on this OS — skipping preflight (see skip message above)."
fi

# ── 7. Licence line (R9.3) — mixed, NOT "MIT" alone ─────────────────────────
echo ""
echo "jeff: MIT; gliformer-large-v1 weights: Apache-2.0"
echo ""
echo "jeff-setup complete."
