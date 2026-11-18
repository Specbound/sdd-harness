#!/bin/bash
# purpose: Runs a hook command unchanged and logs each run to .claude/logs/hook-runs.jsonl.
# _run-hook.sh — runs one hook command and logs that it ran.
#
# Claude Code writes a hook run into the session transcript only when the hook
# prints something. A hook that exits 0 quietly — most guards, most of the time —
# leaves no trace, and neither does a block that reaches Claude as a tool error.
# So "no output" could not be told apart from "never ran".
#
# scripts/setup/wrap-hook-commands.py routes every simple hook command in a
# project's settings.json through this wrapper at install/update time:
#
#   bash "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/_run-hook.sh" <original command>
#
# and the wrapper appends one JSON line per run to
# <project>/.claude/logs/hook-runs.jsonl:
#
#   {"ts", "hook", "event", "tool", "target", "session", "exit", "ms"}
#
# `target` is what the tool call acted on (skill name, subagent type, file path,
# or the first 80 characters of a Bash command), so a run can be read without
# opening the transcript. Prompt text is never logged.
#
# Contract: the wrapped command gets the same stdin, cwd and environment, and its
# stdout, stderr and exit code reach Claude Code unchanged. The wrapper prints
# nothing of its own. Logging runs in the background with its output detached,
# and a failure to log never changes the hook's result.
#
# `ms` needs bash 5's EPOCHREALTIME; under older bash (macOS /bin/bash 3.2) it is
# null rather than a guess.
#
# Opt-out: SDD_HOOK_LOG=0 runs the command without logging.

[ "$#" -gt 0 ] || exit 0

# Capture stdin byte-for-byte: $(cat) strips trailing newlines, the sentinel keeps them.
payload="$(cat; printf x)"
payload="${payload%x}"

start="${EPOCHREALTIME:-}"
printf '%s' "$payload" | "$@"
rc=$?
end="${EPOCHREALTIME:-}"

if [ "${SDD_HOOK_LOG:-1}" != "0" ]; then
  # The project root is two levels above this file (<root>/.claude/hooks/), so the
  # log lands in the project the wrapper was installed into, whatever the cwd.
  root="$(cd -P "$(dirname "$0")/../.." 2>/dev/null && pwd)"
  if [ -n "$root" ]; then
    (
      mkdir -p "$root/.claude/logs" &&
      printf '%s' "$payload" | python3 -c '
import json, sys, time

log, rc, start, end, *cmd = sys.argv[1:]
try:
    p = json.loads(sys.stdin.read() or "{}")
except ValueError:
    p = {}
if not isinstance(p, dict):
    p = {}
scripts = [c for c in cmd if c.endswith((".sh", ".py", ".js", ".cjs", ".mjs", ".ts"))]
if scripts:
    hook = scripts[-1].rsplit("/", 1)[-1]
else:
    # A binary with subcommands (`tool hook observe`): keep them, or every hook
    # that tool registers is logged under one name.
    hook = " ".join([cmd[0].rsplit("/", 1)[-1], *cmd[1:]])[:80]
ti = p.get("tool_input") if isinstance(p.get("tool_input"), dict) else {}
target = next((str(ti[k]) for k in ("skill", "subagent_type", "file_path", "notebook_path",
                                    "path", "command", "url", "pattern") if ti.get(k)), None)
if target:
    target = " ".join(target.split())[:80]
try:
    ms = round((float(end) - float(start)) * 1000)
except ValueError:
    ms = None  # EPOCHREALTIME unavailable, or a locale with a comma decimal
rec = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "hook": hook,
    "event": p.get("hook_event_name"),
    "tool": p.get("tool_name"),
    "target": target,
    "session": p.get("session_id"),
    "exit": int(rc),
    "ms": ms,
}
with open(log, "a", encoding="utf-8") as f:
    f.write(json.dumps(rec) + "\n")
' "$root/.claude/logs/hook-runs.jsonl" "$rc" "$start" "$end" "$@"
    ) >/dev/null 2>&1 &
  fi
fi

exit "$rc"
