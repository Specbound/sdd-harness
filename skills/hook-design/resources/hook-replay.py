#!/usr/bin/env python3
"""hook-replay.py — replay recorded tool calls through two versions of a PreToolUse hook.

Hand-written `*.test.sh` cases only cover the calls someone thought of. This
replays the calls the agent actually made (from `~/.claude/projects/*/*.jsonl`)
through the current hook and the changed one, and reports every call whose
verdict flipped. The old hook is the baseline: the new version has to justify
each call it now blocks or now allows.

Adapted from Dream-RSI's replay idea (score a candidate policy against recorded
history before deploying it, keeping the incumbent as one of the candidates).
Same limit applies: it can only test calls the history contains.

Output is counts by default. Transcripts can hold secrets, so call contents are
printed only with --samples N, and then truncated.

Usage:
    git show HEAD:hooks/claude/my-hook.sh > /tmp/old-hook.sh
    python3 hook-replay.py --old /tmp/old-hook.sh --new hooks/claude/my-hook.sh --tool Bash
    python3 hook-replay.py --old OLD --new NEW --tool Edit,Write --days 14 --samples 5
    python3 hook-replay.py --old OLD --new NEW --tool Bash --fail-on-change   # for *.test.sh

Verdicts: exit 2, or JSON stdout with `"decision": "block"` or
`hookSpecificOutput.permissionDecision` of `deny`, is BLOCK; any other non-zero
exit is ERROR; everything else is ALLOW.

Side effects: each run gets a throwaway HOME, so hooks that log under `~` write
there. A hook that writes elsewhere (the repo, /tmp) is not isolated — read it
before replaying thousands of calls through it.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

CLAUDE_PROJECTS = Path.home() / ".claude" / "projects"
BLOCK, ALLOW, ERROR = "BLOCK", "ALLOW", "ERROR"


def parse_ts(value):
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def recorded_calls(tools: set[str], days: int, project: str | None, limit: int):
    """Unique (tool, input) pairs from transcripts, newest files first."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days) if days else None
    files = [p for p in CLAUDE_PROJECTS.glob("*/*.jsonl")
             if not project or project in p.parent.name]
    files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    seen, calls = set(), []
    for path in files:
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for line in lines:
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            ts = parse_ts(obj.get("timestamp"))
            if cutoff and ts and ts < cutoff:
                continue
            content = (obj.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for blk in content:
                if not (isinstance(blk, dict) and blk.get("type") == "tool_use"
                        and blk.get("name") in tools):
                    continue
                key = json.dumps([blk["name"], blk.get("input")], sort_keys=True)
                if key in seen:
                    continue
                seen.add(key)
                calls.append({"tool_name": blk["name"], "tool_input": blk.get("input") or {},
                              "cwd": obj.get("cwd") or os.getcwd()})
                if limit and len(calls) >= limit:
                    return calls
    return calls


def verdict(hook: Path, call: dict, home: str, timeout: float) -> str:
    event = {"hook_event_name": "PreToolUse", "session_id": "hook-replay", **call}
    env = dict(os.environ, HOME=home)
    try:
        proc = subprocess.run(["bash", str(hook)], input=json.dumps(event), text=True,
                              capture_output=True, env=env, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        return ERROR
    if proc.returncode == 2:
        return BLOCK
    if proc.returncode != 0:
        return ERROR
    out = proc.stdout.strip()
    if out.startswith("{"):
        try:
            data = json.loads(out)
        except ValueError:
            return ALLOW
        specific = data.get("hookSpecificOutput") or {}
        if data.get("decision") == "block" or specific.get("permissionDecision") == "deny":
            return BLOCK
    return ALLOW


def summarize(call: dict, width: int = 80) -> str:
    inp = call["tool_input"]
    text = inp.get("command") or inp.get("file_path") or json.dumps(inp)
    text = " ".join(str(text).split())
    return f"{call['tool_name']}: {text[:width]}{'…' if len(text) > width else ''}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--old", required=True, type=Path, help="baseline hook script")
    ap.add_argument("--new", required=True, type=Path, help="changed hook script")
    ap.add_argument("--tool", required=True, help="tool name(s) the hook matches, comma-separated")
    ap.add_argument("--days", type=int, default=30, help="lookback window (default 30, 0 = all)")
    ap.add_argument("--project", help="only transcripts whose project dir contains this")
    ap.add_argument("--limit", type=int, default=2000, help="max unique calls (default 2000)")
    ap.add_argument("--timeout", type=float, default=10.0, help="per-run timeout seconds")
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--samples", type=int, default=0,
                    help="print up to N truncated calls per flip class (off by default: transcripts hold secrets)")
    ap.add_argument("--fail-on-change", action="store_true", help="exit 1 if any verdict flipped")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    for hook in (args.old, args.new):
        if not hook.is_file():
            print(f"hook-replay: no such hook script: {hook}", file=sys.stderr)
            return 2
    if not CLAUDE_PROJECTS.is_dir():
        print(f"hook-replay: no transcripts at {CLAUDE_PROJECTS}", file=sys.stderr)
        return 2

    tools = {t.strip() for t in args.tool.split(",") if t.strip()}
    calls = recorded_calls(tools, args.days, args.project, args.limit)
    if not calls:
        print(f"hook-replay: no recorded {', '.join(sorted(tools))} calls in the window — "
              f"nothing tested, which is not a pass", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory() as home_old, tempfile.TemporaryDirectory() as home_new, \
            ThreadPoolExecutor(max_workers=args.jobs) as pool:
        old = list(pool.map(lambda c: verdict(args.old, c, home_old, args.timeout), calls))
        new = list(pool.map(lambda c: verdict(args.new, c, home_new, args.timeout), calls))

    flips: dict[str, list[dict]] = {"newly_blocked": [], "newly_allowed": [], "new_errors": []}
    for call, a, b in zip(calls, old, new):
        if a == b:
            continue
        if b == BLOCK:
            flips["newly_blocked"].append(call)
        elif a == BLOCK and b == ALLOW:
            flips["newly_allowed"].append(call)
        elif b == ERROR:
            flips["new_errors"].append(call)
    changed = sum(len(v) for v in flips.values())

    if args.json:
        print(json.dumps({
            "calls": len(calls),
            "old": dict(Counter(old)),
            "new": dict(Counter(new)),
            **{k: len(v) for k, v in flips.items()},
        }, indent=2))
    else:
        print(f"## Hook replay — {len(calls)} unique recorded {'/'.join(sorted(tools))} calls")
        print(f"old: {dict(Counter(old))}   new: {dict(Counter(new))}")
        for name, items in flips.items():
            print(f"{name}: {len(items)}")
            for call in items[:args.samples]:
                print(f"  - {summarize(call)}")
        print("Coverage: only calls present in the transcripts were tested; a verdict change")
        print("on a command nobody has run yet is invisible here.")
    return 1 if args.fail_on_change and changed else 0


if __name__ == "__main__":
    sys.exit(main())
