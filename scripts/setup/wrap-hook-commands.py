#!/usr/bin/env python3
"""Route a project's hook commands through .claude/hooks/_run-hook.sh.

Claude Code records a hook run in the transcript only when the hook prints
something, so a hook that runs quietly leaves no trace. _run-hook.sh runs the
original command unchanged and appends one line per run to
.claude/logs/hook-runs.jsonl. This script rewrites each hook command in a
project's settings files to go through it:

    bash "/path/x.sh"   ->   bash "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/_run-hook.sh" bash "/path/x.sh"

It reads whatever the settings file registers — no hook names, interpreters or
paths are listed here — so hooks added later are wrapped on the next
install/update with no change to this script.

A command is wrapped only when the wrapper can run it as plain argv:
  * no shell operators (| & ; < > ( )), no `...` or $(...) substitution —
    the wrapper would apply them outside the hook, not inside it;
  * no leading VAR=value assignment — the wrapper would run it as a command.
Anything else is left exactly as it is and reported as skipped.

Usage:
    wrap-hook-commands.py <project_dir> [<project_dir> ...]
    wrap-hook-commands.py --unwrap <project_dir>     # restore the original commands
    wrap-hook-commands.py --dry-run <project_dir>

Reads <project_dir>/.claude/settings.json and settings.local.json. Wraps nothing
in a project whose .claude/hooks/_run-hook.sh is missing, since every wrapped
hook would then fail. Idempotent. Exits 1 if any settings file is not valid JSON.
"""
import json
import os
import shlex
import sys
import tempfile
from pathlib import Path

WRAPPER_NAME = "_run-hook.sh"
# CLAUDE_PROJECT_DIR is set by Claude Code for every hook; "." is the same
# fallback the harness's own hook commands use when it is not.
WRAPPER_CMD = f'bash "${{CLAUDE_PROJECT_DIR:-.}}/.claude/hooks/{WRAPPER_NAME}"'
SETTINGS_FILES = ("settings.json", "settings.local.json")
SHELL_OPERATOR_CHARS = set("();<>|&")


class SettingsError(Exception):
    """A settings file this script must not rewrite."""


def skip_reason(command):
    """Why a command cannot be wrapped as plain argv, or "" when it can."""
    if "`" in command or "$(" in command:
        return "command substitution"
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return "unbalanced quotes"
    if not tokens:
        return "empty command"
    if any(tok and set(tok) <= SHELL_OPERATOR_CHARS for tok in tokens):
        return "shell operator"
    name, eq, _ = tokens[0].partition("=")
    if eq and name and name.replace("_", "a").isalnum() and not name[0].isdigit():
        return "leading env assignment"
    return ""


def wrap(command):
    return f"{WRAPPER_CMD} {command}"


def unwrap(command):
    return command.removeprefix(f"{WRAPPER_CMD} ")


def rewrite(settings, mode):
    """Rewrite command hooks in place. Returns (changed, skipped[(command, reason)])."""
    changed, skipped = 0, []
    for groups in (settings.get("hooks") or {}).values():
        for group in groups or []:
            for hook in group.get("hooks") or []:
                command = hook.get("command")
                if hook.get("type", "command") != "command" or not isinstance(command, str):
                    continue
                if mode == "unwrap":
                    new = unwrap(command)
                elif WRAPPER_NAME in command:
                    continue
                else:
                    reason = skip_reason(command)
                    if reason:
                        skipped.append((command, reason))
                        continue
                    new = wrap(command)
                if new != command:
                    hook["command"] = new
                    changed += 1
    return changed, skipped


def write_atomic(path, settings):
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(json.dumps(settings, indent=2, ensure_ascii=False) + "\n")
    os.replace(tmp, path)


def process(project, mode, dry_run):
    """Rewrite one project's settings files. Returns a list of report lines."""
    claude_dir = project / ".claude"
    if mode == "wrap" and not (claude_dir / "hooks" / WRAPPER_NAME).is_file():
        return [f"SKIP {project}: {WRAPPER_NAME} not installed in .claude/hooks/"]
    report = []
    for name in SETTINGS_FILES:
        path = claude_dir / name
        if not path.is_file():
            continue
        try:
            settings = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise SettingsError(f"{path} is not valid JSON: {exc}") from exc
        if not isinstance(settings, dict):
            raise SettingsError(f"{path} is not a JSON object")
        changed, skipped = rewrite(settings, mode)
        verb = "unwrapped" if mode == "unwrap" else "wrapped"
        if changed and not dry_run:
            write_atomic(path, settings)
        status = "OK" if not changed else ("WOULD" if dry_run else "DONE")
        report.append(f"{status} {path}: {verb} {changed}, skipped {len(skipped)}")
        for command, reason in skipped:
            report.append(f"     skipped ({reason}): {command}")
    return report


def main(argv):
    mode = "unwrap" if "--unwrap" in argv else "wrap"
    dry_run = "--dry-run" in argv
    projects = [Path(a) for a in argv if not a.startswith("--")]
    if not projects:
        print("usage: wrap-hook-commands.py [--unwrap] [--dry-run] <project_dir> ...", file=sys.stderr)
        return 2
    failed = False
    for project in projects:
        try:
            for line in process(project, mode, dry_run):
                print(line)
        except SettingsError as exc:
            print(f"ERROR {exc}", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
