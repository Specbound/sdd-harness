#!/usr/bin/env python3
"""Add harness hook registrations a project's .claude/settings.json is missing.

install.sh writes settings.json from templates/settings.json.template once and
never again, while update.sh re-copies every hook *file* on each run. So a hook
added to the template after a project was installed reached that project's
.claude/hooks/ but was never registered, and never fired. Measured 2026-11-18:
three projects were missing 19-20 of the template's 52 hooks, and one had no
settings.json at all.

On each run, for every (event, matcher, hook script) the template registers:
  * already registered in the project      -> left alone, recorded as offered
  * registered for the same event under a different matcher
                                           -> left alone: adding the template's
                                              matcher too would fire the hook twice
                                              for tools both match
  * never offered before                   -> added, template command copied verbatim
  * offered before, no longer registered   -> held: the project removed it, and a
                                              removal is a decision this must keep
  * script not in the project's .claude/hooks/ -> skipped and NOT recorded, so the
                                              next run adds it once the file lands
A project with no settings.json gets the template whole, as install.sh would.

What has been offered is recorded per project in .claude/.hook-offers.json. On a
project's first run there is no record, so every missing hook is added once; from
then on removals stick.

Nothing is ever removed or reordered, the project's own hooks are untouched, and
settings.local.json is not read or written. Run before wrap-hook-commands.py, which
routes the added commands through the run logger. Registrations are compared by
script name, so wrapped and unwrapped forms of one hook count as the same hook.

Usage:
    sync-hook-registrations.py <project_dir> [<project_dir> ...]
    sync-hook-registrations.py --dry-run <project_dir>
    sync-hook-registrations.py --template <path> <project_dir>   # tests

Exits 1 if a settings or offers file is unreadable; that project is left as it was.
"""
import argparse
import json
import os
import shlex
import sys
import tempfile
from pathlib import Path

HARNESS_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TEMPLATE = HARNESS_ROOT / "templates" / "settings.json.template"
OFFERS_NAME = ".hook-offers.json"
SCRIPT_SUFFIXES = (".sh", ".py", ".js", ".cjs", ".mjs", ".ts")


class SyncError(Exception):
    """A file this script must not guess its way past."""


def script_of(command):
    """Basename of the last script a hook command runs; "" for inline commands.

    "Last" so a command wrapped by _run-hook.sh resolves to the hook it runs.
    """
    try:
        tokens = shlex.split(command)
    except ValueError:
        tokens = command.split()
    scripts = [t for t in tokens if t.endswith(SCRIPT_SUFFIXES)]
    return Path(scripts[-1]).name if scripts else ""


def iter_hooks(settings):
    """(event, matcher, script, hook entry) for every script-backed registration."""
    for event, groups in (settings.get("hooks") or {}).items():
        for group in groups or []:
            matcher = group.get("matcher") or ""
            for hook in group.get("hooks") or []:
                script = script_of(hook.get("command") or "")
                if script:
                    yield event, matcher, script, hook


def add_registration(settings, event, matcher, hook):
    """Append to the group with this matcher, or create the group."""
    groups = settings.setdefault("hooks", {}).setdefault(event, [])
    for group in groups:
        if (group.get("matcher") or "") == matcher:
            group.setdefault("hooks", []).append(dict(hook))
            return
    groups.append({"matcher": matcher, "hooks": [dict(hook)]})


def load_json(path, what):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SyncError(f"{path} is not valid JSON ({what}): {exc}") from exc
    if not isinstance(data, dict):
        raise SyncError(f"{path} is not a JSON object ({what})")
    return data


def load_offers(path):
    """Offered (event, matcher, script) keys, or None when the project has no record yet."""
    if not path.is_file():
        return None
    data = load_json(path, "hook offers record")
    try:
        return {(e, m, s) for e, m, s in data["offered"]}
    except (KeyError, TypeError, ValueError) as exc:
        raise SyncError(f"{path} has no valid 'offered' list: {exc}") from exc


def write_atomic(path, data):
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    os.replace(tmp, path)


def sync(project, template, dry_run):
    """Sync one project. Returns report lines."""
    claude = project / ".claude"
    if not claude.is_dir():
        return [f"SKIP {project}: no .claude/ (run install.sh first)"]
    settings_path = claude / "settings.json"
    offers_path = claude / OFFERS_NAME
    hooks_dir = claude / "hooks"

    created = not settings_path.is_file()
    settings = json.loads(json.dumps(template)) if created else load_json(settings_path, "project settings")
    offers = load_offers(offers_path)
    first_run = offers is None
    offered = set(offers or ())
    present = {(e, m, s) for e, m, s, _ in iter_hooks(settings)}
    by_event = {}
    for e, m, s in present:
        by_event.setdefault((e, s), []).append(m)

    added, held, no_file, other_matcher = [], [], [], []
    for event, matcher, script, hook in iter_hooks(template):
        key = (event, matcher, script)
        if key in present:
            offered.add(key)
        elif (event, script) in by_event:
            offered.add(key)
            other_matcher.append((key, by_event[(event, script)]))
        elif not (hooks_dir / script).is_file():
            no_file.append(key)
        elif key in offered:
            held.append(key)
        else:
            add_registration(settings, event, matcher, hook)
            present.add(key)
            by_event.setdefault((event, script), []).append(matcher)
            offered.add(key)
            added.append(key)

    if not dry_run:
        if created or added:
            write_atomic(settings_path, settings)
        if offered != (offers or set()):
            write_atomic(offers_path, {"offered": sorted(list(k) for k in offered)})

    if created:
        status = "WOULD CREATE" if dry_run else "CREATED"
    elif added:
        status = "WOULD" if dry_run else "DONE"
    else:
        status = "OK"
    lines = [f"{status} {settings_path}: added {len(added)}, held {len(held)}"
             + (" (first sync: every missing template hook added once)" if first_run and added else "")]
    lines += [f"     added: {e} {m or '(all)'} {s}" for e, m, s in added]
    lines += [f"     held (removed in this project, not re-added): {e} {m or '(all)'} {s}" for e, m, s in held]
    lines += [f"     not added (no .claude/hooks/{s} yet): {e} {m or '(all)'}" for e, m, s in no_file]
    lines += [f"     kept project matcher {', '.join(pm or '(all)' for pm in pms)} for {e} {s}"
              f" (template: {m or '(all)'})" for (e, m, s), pms in other_matcher]
    return lines


def main(argv):
    ap = argparse.ArgumentParser(description="Add missing harness hook registrations to projects.")
    ap.add_argument("projects", nargs="+", type=Path)
    ap.add_argument("--dry-run", action="store_true", help="report without writing")
    ap.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE, help="settings template to sync from")
    args = ap.parse_args(argv)
    try:
        template = load_json(args.template, "template")
    except (SyncError, FileNotFoundError) as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 1
    failed = False
    for project in args.projects:
        try:
            for line in sync(project.resolve(), template, args.dry_run):
                print(line)
        except SyncError as exc:
            print(f"ERROR {exc}", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
