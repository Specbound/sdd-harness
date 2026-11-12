#!/usr/bin/env bash
# router-ctl.sh — on-demand lifecycle for the model router's three processes:
# sentinel (:8799, the address ANTHROPIC_BASE_URL points at), worker (:8798),
# and the jeff classifier (:8000). Nothing here is a resident OS service: the
# processes exist only while at least one harness-active Claude Code session
# does. hooks/claude/router-session-hook.sh calls `up` on SessionStart and
# `down` on SessionEnd.
#
# Usage:
#   router-ctl.sh up <session-id>     # register the session; start whatever is not running
#   router-ctl.sh down <session-id>   # unregister; stop everything once no live session remains
#   router-ctl.sh wired <project-dir> # exit 0 iff that project routes through the sentinel
#   router-ctl.sh status              # print what is running and which sessions hold it
#   router-ctl.sh stop                # stop everything regardless of sessions
#
# Refcount: one marker file per session under $RUN_DIR/sessions/, holding the
# PID of the owning `claude` process. `down` prunes markers whose PID is gone,
# so a session that crashed without firing SessionEnd cannot pin the router
# up forever.
#
# Ordering on `up`: the sentinel is the only process a session cannot work
# without (ANTHROPIC_BASE_URL points at it), so `up` blocks until it accepts
# connections and exits 1 if it never does. The sentinel fails open to the
# upstream when the worker is down, and the worker's classifier circuit breaker
# re-closes on a timer, so the worker and jeff are started without waiting —
# jeff takes several seconds to load its model and must not delay the session.
#
# jeff's bearer key lives in jeff's own env file (written by jeff-setup.sh).
# It is exported into the worker's environment under router.toml's
# [classifier].api_key_env name (JEFF_API_KEY by default) at spawn time — no
# second copy of the secret is written anywhere.
set -u

__here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$__here/../lib/resolve-harness-dir.sh"
. "$__here/../lib/tool-paths.sh"
ensure_tool_bin_on_path

ROUTER_DIR="${SDD_ROUTER_DIR:-$HOME/.sdd-router}"
ROUTER_TOML="$ROUTER_DIR/router.toml"
RUN_DIR="$ROUTER_DIR/run"
SESSIONS_DIR="$RUN_DIR/sessions"
LOG_DIR="$ROUTER_DIR/.logs"
JEFF_DIR="$ROUTER_DIR/jeff"
JEFF_ENV_FILE="$JEFF_DIR/.jeff-service.env"
JEFF_MODEL_DIR="$JEFF_DIR/models/gliformer-large-v1"

SENTINEL_SCRIPT="$HARNESS_DIR/scripts/router/sentinel.py"
WORKER_SCRIPT="$HARNESS_DIR/scripts/router/server.py"

SENTINEL_PORT_DEFAULT=8799
WORKER_PORT=8798
JEFF_PORT_DEFAULT=8000
SENTINEL_WAIT_TRIES=30   # x 0.1s

die() { echo "router-ctl: ERROR: $*" >&2; exit 1; }

port_open() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

pid_alive() {
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

read_pidfile() {
  cat "$RUN_DIR/$1.pid" 2>/dev/null || true
}

resolve_python() {
  local uv py
  uv="$(find_tool uv || true)"
  [ -n "$uv" ] || die "uv not found — cannot resolve a Python >=3.11 interpreter"
  py="$("$uv" python find '>=3.11' 2>/dev/null || true)"
  [ -n "$py" ] && [ -x "$py" ] || die "no Python >=3.11 found via uv (run scripts/setup/router-setup.sh)"
  echo "$py"
}

# toml_field <table> <key> <default> — read-only tomllib lookup.
toml_field() {
  ROUTER_TOML_PATH="$ROUTER_TOML" TABLE="$1" KEY="$2" DEFAULT="$3" "$PYBIN" - <<'PY'
import os
import tomllib

with open(os.environ["ROUTER_TOML_PATH"], "rb") as f:
    data = tomllib.load(f)
table = data.get(os.environ["TABLE"])
if not isinstance(table, dict):
    table = {}
value = table.get(os.environ["KEY"])
print(os.environ["DEFAULT"] if value in (None, "") else value, end="")
PY
}

# env_file_value <file> <key> — first KEY=value line, value verbatim.
env_file_value() {
  local line
  while IFS= read -r line; do
    case "$line" in
      "$2="*) echo "${line#*=}"; return 0 ;;
    esac
  done < "$1"
  return 1
}

# owning_claude_pid — nearest ancestor whose executable is named `claude`.
# Empty when none is found; such a marker is kept until `down` names it.
owning_claude_pid() {
  local pid="$$" ppid comm i
  for i in 1 2 3 4 5 6 7 8; do
    ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [ -n "$ppid" ] && [ "$ppid" != "1" ] && [ "$ppid" != "0" ] || return 0
    comm="$(ps -o comm= -p "$ppid" 2>/dev/null)"
    if [ "$(basename "$comm")" = "claude" ]; then
      echo "$ppid"
      return 0
    fi
    pid="$ppid"
  done
}

prune_dead_sessions() {
  local marker pid
  for marker in "$SESSIONS_DIR"/*; do
    [ -f "$marker" ] || continue
    pid="$(cat "$marker" 2>/dev/null || true)"
    if [ -n "$pid" ] && ! pid_alive "$pid"; then
      rm -f "$marker"
    fi
  done
}

live_session_count() {
  local n=0 marker
  for marker in "$SESSIONS_DIR"/*; do
    [ -f "$marker" ] && n=$((n+1))
  done
  echo "$n"
}

# spawn <name> <workdir> <cmd...> — detached, pidfile. A live pidfile means a
# previous `up` already started it and it is still loading (jeff takes seconds
# to open its port) — spawning again would orphan the first instance.
spawn() {
  local name="$1" workdir="$2"
  shift 2
  pid_alive "$(read_pidfile "$name")" && return 0
  # `cd` stays its own statement: `cd && nohup ... &` backgrounds the whole
  # list as a subshell, so $! named that subshell and `kill` orphaned the server.
  ( cd "$workdir" || exit 1
    nohup "$@" >>"$LOG_DIR/$name.stdout.log" 2>>"$LOG_DIR/$name.stderr.log" </dev/null &
    echo $! > "$RUN_DIR/$name.pid" )
}

start_sentinel() {
  local port="$1"
  if port_open "$port"; then
    return 0
  fi
  spawn sentinel "$ROUTER_DIR" "$PYBIN" "$SENTINEL_SCRIPT" --router-toml "$ROUTER_TOML"
  local i
  for i in $(seq 1 "$SENTINEL_WAIT_TRIES"); do
    port_open "$port" && return 0
    sleep 0.1
  done
  die "sentinel did not start listening on 127.0.0.1:$port — see $LOG_DIR/sentinel.stderr.log. Sessions routed through it cannot reach the API until this is fixed (or run scripts/setup/router-setup.sh uninstall)."
}

start_worker() {
  port_open "$WORKER_PORT" && return 0
  local key_env key=""
  key_env="$(toml_field classifier api_key_env JEFF_API_KEY)"
  if [ -f "$JEFF_ENV_FILE" ]; then
    key="$(env_file_value "$JEFF_ENV_FILE" JEFF_API_KEYS || true)"
  fi
  if [ -n "$key" ]; then
    spawn worker "$ROUTER_DIR" env "$key_env=$key" "$PYBIN" "$WORKER_SCRIPT" --router-toml "$ROUTER_TOML"
  else
    spawn worker "$ROUTER_DIR" "$PYBIN" "$WORKER_SCRIPT" --router-toml "$ROUTER_TOML"
  fi
}

# jeff is optional: absent install => the worker fails open to pass-through.
start_jeff() {
  [ -f "$JEFF_ENV_FILE" ] && [ -d "$JEFF_MODEL_DIR" ] || return 0
  local port
  port="$(env_file_value "$JEFF_ENV_FILE" JEFF_PORT || echo "$JEFF_PORT_DEFAULT")"
  port_open "$port" && return 0
  local uv
  uv="$(find_tool uv || true)"
  [ -n "$uv" ] || return 0
  # set -a exports every KEY=value the env file assigns, for jeff only.
  spawn jeff "$JEFF_DIR" bash -c 'set -a; . "$1"; set +a; exec "$2" run jeff' _ "$JEFF_ENV_FILE" "$uv"
}

stop_one() {
  local name="$1" pid
  pid="$(read_pidfile "$name")"
  if pid_alive "$pid"; then
    # jeff's pid is `uv run`, whose model-serving python is a child.
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$RUN_DIR/$name.pid"
}

stop_all() {
  stop_one sentinel
  stop_one worker
  stop_one jeff
}

cmd_up() {
  local session="${1:-}"
  [ -n "$session" ] || die "usage: router-ctl.sh up <session-id>"
  [ -f "$ROUTER_TOML" ] || die "$ROUTER_TOML not found — run scripts/setup/router-setup.sh"
  mkdir -p "$SESSIONS_DIR" "$LOG_DIR"
  PYBIN="$(resolve_python)"

  local upstream port
  upstream="$(toml_field router upstream "")"
  [ -n "$upstream" ] || die "[router].upstream is empty in $ROUTER_TOML — run scripts/setup/router-setup.sh"
  port="$(toml_field router port "$SENTINEL_PORT_DEFAULT")"

  owning_claude_pid > "$SESSIONS_DIR/$session"
  start_jeff
  start_worker
  start_sentinel "$port"
}

cmd_down() {
  local session="${1:-}"
  [ -n "$session" ] || die "usage: router-ctl.sh down <session-id>"
  rm -f "$SESSIONS_DIR/$session"
  prune_dead_sessions
  if [ "$(live_session_count)" -eq 0 ]; then
    stop_all
  fi
}

# cmd_wired <project-dir> — exit 0 iff that project's settings.local.json
# routes through this router's sentinel (router-setup.sh writes it there).
cmd_wired() {
  local project="${1:-}" local_json current port
  [ -n "$project" ] || die "usage: router-ctl.sh wired <project-dir>"
  [ -f "$ROUTER_TOML" ] || return 1
  local_json="$project/.claude/settings.local.json"
  [ -f "$local_json" ] || return 1
  PYBIN="$(resolve_python)"
  port="$(toml_field router port "$SENTINEL_PORT_DEFAULT")"
  current="$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$local_json" 2>/dev/null || true)"
  [ "$current" = "http://127.0.0.1:$port" ]
}

cmd_status() {
  local name pid
  for name in sentinel worker jeff; do
    pid="$(read_pidfile "$name")"
    if pid_alive "$pid"; then
      echo "$name: running (pid $pid)"
    else
      echo "$name: stopped"
    fi
  done
  prune_dead_sessions
  echo "sessions: $(live_session_count)"
}

main() {
  case "${1:-}" in
    up)     cmd_up "${2:-}" ;;
    down)   cmd_down "${2:-}" ;;
    wired)  cmd_wired "${2:-}" ;;
    status) mkdir -p "$SESSIONS_DIR"; cmd_status ;;
    stop)   stop_all ;;
    *) die "unknown command '${1:-}' (expected up|down|status|stop)" ;;
  esac
}

main "$@"
