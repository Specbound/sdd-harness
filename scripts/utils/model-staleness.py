#!/usr/bin/env python3
"""model-staleness.py — flag Claude model mentions the live lineup has superseded.

Skills, agents, commands, hooks and scripts name models ("claude-sonnet-4-6",
"Opus 4.8"). Those names go stale silently when a new generation ships:
~/.claude/skill-library/model-tiers/SKILL.md told every subagent spawn that Opus cost 3x Sonnet for weeks
after the ratio became 2x, because nothing compared it with the live lineup.

This compares every mention in the harness's active tree against the current
lineup published at LIVE_URL (public markdown, no API key — the harness has
none; see harness-llm-calls-use-subscription). A mention is:
  - stale:  older than the current model of the same family
  - newer:  newer than anything live — usually a typo or a fabricated ID
Families absent from the live table (e.g. a model only offered through a
verification program) are not judged.

Intentional mentions (history, benchmarks quoted from a source, test fixtures)
go in scripts/utils/model-mention-allow.txt instead of being "fixed". Known
stale mentions not yet paid down go in scripts/utils/model-mention-debt.txt —
same pattern as no-regex-debt.txt: they are counted, not reported as new, so a
model release shows up as fresh findings instead of drowning in old ones.

No `re` import — banned repo-wide (see ruff.toml). Matching is token-based.

Usage: model-staleness.py <repo_dir> [--json] [--live-file PATH]
Exit:  0 clean, 1 findings, 2 the live lineup could not be read (never "clean")
"""
import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

LIVE_URL = "https://platform.claude.com/docs/en/models/overview.md"
LIVE_ROW = "Claude API ID"
FAMILIES = {"haiku", "sonnet", "opus", "fable", "mythos"}
SCAN_DIRS = ("skills", "agents", "commands", "hooks", "scripts", "templates", "rules", "kiro")
SCAN_ROOT_FILES = ("CLAUDE.md", "AGENTS.md")
SCAN_SUFFIXES = {".md", ".sh", ".py", ".json", ".toml", ".template", ".txt", ".yaml", ".yml", ".js", ".ts"}
ALLOW_FILE = "scripts/utils/model-mention-allow.txt"
DEBT_FILE = "scripts/utils/model-mention-debt.txt"
TOKEN_CHARS = set("abcdefghijklmnopqrstuvwxyz0123456789-.")


class LiveLineupError(Exception):
    """The live lineup could not be fetched or no longer has the expected table row."""


def parse_model_id(token: str):
    """'claude-opus-4-8' -> ('opus', (4, 8)); 'claude-3-5-sonnet-20241022' -> ('sonnet', (3, 5)).

    Returns None when the token is not a model ID (claude-code, claude-md, ...).
    """
    start = token.find("claude-")
    if start == -1 or (start > 0 and token[start - 1] != "."):
        return None
    parts = token[start + len("claude-"):].strip(".-").split("-")
    family = next((p for p in parts if p in FAMILIES), None)
    # Version parts are short integers; an 8-digit part is a snapshot date.
    version = tuple(int(p) for p in parts if p.isdigit() and len(p) <= 2)
    if family is None or not version:
        return None
    return family, version


def parse_prose_version(word: str):
    """'4.8' -> (4, 8); '5' -> (5,); anything else -> None."""
    word = word.strip(".")
    pieces = word.split(".")
    if not word or not all(p.isdigit() and len(p) <= 2 for p in pieces):
        return None
    version = tuple(int(p) for p in pieces)
    # "opus 0.98" is a score, not a model — Claude major versions start at 1.
    return version if version[0] >= 1 else None


def tokenize(line: str):
    lowered = line.lower()
    return "".join(ch if ch in TOKEN_CHARS else " " for ch in lowered).split()


def find_mentions(line: str):
    """Yield (mention_text, family, version) for each model mention on the line."""
    tokens = tokenize(line)
    for i, tok in enumerate(tokens):
        parsed = parse_model_id(tok)
        if parsed:
            yield tok.strip(".-"), parsed[0], parsed[1]
            continue
        if tok in FAMILIES and i + 1 < len(tokens):
            version = parse_prose_version(tokens[i + 1])
            if version:
                yield f"{tok} {'.'.join(str(v) for v in version)}", tok, version


def parse_live_lineup(markdown: str):
    """Read the 'Claude API ID' row of the overview table -> {family: (version, id)}."""
    for line in markdown.splitlines():
        cells = [c.strip().strip("`").strip() for c in line.strip().strip("|").split("|")]
        if not cells or cells[0] != LIVE_ROW:
            continue
        lineup = {}
        for model_id in cells[1:]:
            parsed = parse_model_id(model_id)
            if parsed:
                lineup[parsed[0]] = (parsed[1], model_id)
        if lineup:
            return lineup
    raise LiveLineupError(f"no '{LIVE_ROW}' row with model IDs in the live page — format changed?")


def fetch_live(live_file):
    if live_file:
        return Path(live_file).read_text()
    try:
        # The docs host 403s urllib's default User-Agent; curl's is accepted.
        req = urllib.request.Request(LIVE_URL, headers={"User-Agent": "curl/8.7.1"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise LiveLineupError(f"fetch {LIVE_URL} failed: {exc}") from exc


def load_ledger(repo: Path, rel_file: str):
    """Lines: '<repo-relative path> <mention>' or '<path> *' for the whole file."""
    allowed = set()
    path = repo / rel_file
    if not path.is_file():
        return allowed
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        rel, _, mention = line.partition(" ")
        allowed.add((rel, mention.strip().lower() or "*"))
    return allowed


def iter_scan_files(repo: Path):
    for name in SCAN_ROOT_FILES:
        if (repo / name).is_file():
            yield repo / name
    for d in SCAN_DIRS:
        base = repo / d
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if path.is_file() and path.suffix in SCAN_SUFFIXES:
                yield path


def scan(repo: Path, lineup, allowed, debt):
    """Return (stale, newer, debt_hits, debt_keys_seen)."""
    stale, newer, debt_hits, debt_seen = [], [], [], set()
    for path in iter_scan_files(repo):
        rel = str(path.relative_to(repo))
        if rel in (ALLOW_FILE, DEBT_FILE) or (rel, "*") in allowed:
            continue
        try:
            text = path.read_text(errors="replace")
        except OSError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            for mention, family, version in find_mentions(line):
                if family not in lineup or (rel, mention) in allowed:
                    continue
                current_version, current_id = lineup[family]
                if version == current_version:
                    continue
                row = {"file": rel, "line": lineno, "mention": mention, "current": current_id}
                debt_key = (rel, mention) if (rel, mention) in debt else (rel, "*")
                if debt_key in debt:
                    debt_seen.add(debt_key)
                    debt_hits.append(row)
                    continue
                (stale if version < current_version else newer).append(row)
    return stale, newer, debt_hits, debt_seen


def main():
    args = sys.argv[1:]
    if not args:
        print("Usage: model-staleness.py <repo_dir> [--json] [--live-file PATH]", file=sys.stderr)
        return 2
    repo = Path(args[0]).resolve()
    as_json = "--json" in args
    live_file = args[args.index("--live-file") + 1] if "--live-file" in args else None

    try:
        lineup = parse_live_lineup(fetch_live(live_file))
    except LiveLineupError as exc:
        print(f"model-staleness: {exc}", file=sys.stderr)
        return 2

    debt = load_ledger(repo, DEBT_FILE)
    stale, newer, debt_hits, debt_seen = scan(repo, lineup, load_ledger(repo, ALLOW_FILE), debt)
    out = {
        "checked_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source": live_file or LIVE_URL,
        "current": {family: model_id for family, (_, model_id) in sorted(lineup.items())},
        "stale": stale,
        "newer": newer,
        "total_findings": len(stale) + len(newer),
        "debt_count": len(debt_hits),
        # Ledger lines that matched nothing: paid down (or the file moved) — delete them.
        "debt_cleared": sorted(f"{rel} {mention}" for rel, mention in debt - debt_seen),
    }
    if as_json:
        print(json.dumps(out, indent=2))
    else:
        print(f"model-staleness: {out['total_findings']} finding(s) — stale={len(stale)} "
              f"newer={len(newer)} debt={len(debt_hits)} cleared-debt-lines={len(out['debt_cleared'])} "
              f"current={', '.join(out['current'].values())}")
        for kind, rows in (("stale", stale), ("newer", newer)):
            for r in rows:
                print(f"  [{kind}] {r['file']}:{r['line']} {r['mention']} (current: {r['current']})")
    return 1 if out["total_findings"] else 0


if __name__ == "__main__":
    sys.exit(main())
