#!/usr/bin/env python3
"""declare-repo-deps.py — declare harness-injected packages in a target repo's manifest.

Why this exists
---------------
raindrop-setup.sh and headroom-setup.sh used to `pip install <pkg>` straight into a
target repo's virtualenv and write nothing to that repo's manifest. The package was
therefore present but undeclared, so the repo's own tooling had no idea it was
wanted: one `uv sync`, lockfile regen, or dependency prune deleted it. The harness
reinstalled it on the next update, the next prune deleted it again, forever.

Declaring the package in the repo's manifest breaks that loop — a prune now sees a
declared dependency instead of an orphan.

What it writes
--------------
pyproject.toml  ->  [dependency-groups] harness = [...]   (PEP 735)
requirements.txt ->  requirements-harness.txt + a `-r` line referencing it
neither          ->  skipped (not a Python repo)

Idempotent: re-running unions the package list, never duplicates it. If the edit
would produce invalid TOML the original file is restored and the script fails
loudly rather than leaving a broken manifest behind.

Usage:  declare-repo-deps.py <repo-path> <pkg-spec> [<pkg-spec> ...]
Exit:   0 = declared or already present or skipped, 1 = failed to write
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

GROUP_NAME = "harness"
HARNESS_REQ_FILE = "requirements-harness.txt"
MARKER = "# managed by sdd-harness (scripts/setup/declare-repo-deps.py) — do not hand-prune"


def _pkg_name(spec: str) -> str:
    """Bare distribution name from a pip spec ('raindrop-ai>=1.2' -> 'raindrop-ai')."""
    return re.split(r"[<>=!~\[; ]", spec, maxsplit=1)[0].strip()


def _validate_toml(text: str) -> bool:
    try:
        import tomllib
    except ImportError:
        return True  # Python <3.11: cannot verify, trust the edit
    try:
        tomllib.loads(text)
        return True
    except Exception:
        return False


def _existing_group(text: str) -> tuple[int, int, list[str]] | None:
    """Locate `harness = [...]` inside [dependency-groups].

    Returns (start_offset, end_offset, current_entries) or None when absent.
    """
    sec = re.search(r"^\[dependency-groups\]\s*$", text, re.M)
    if not sec:
        return None
    # Section body ends at the next top-level table header, or EOF.
    nxt = re.search(r"^\[", text[sec.end():], re.M)
    body_end = sec.end() + (nxt.start() if nxt else len(text) - sec.end())
    key = re.search(rf"^{GROUP_NAME}\s*=\s*\[", text[sec.end():body_end], re.M)
    if not key:
        return None
    start = sec.end() + key.start()
    close = text.find("]", sec.end() + key.end() - 1)
    if close == -1:
        raise ValueError("unterminated dependency-groups array in pyproject.toml")
    end = close + 1
    entries = re.findall(r"[\"']([^\"']+)[\"']", text[start:end])
    return start, end, entries


def declare_in_pyproject(path: Path, specs: list[str]) -> str:
    original = path.read_text(encoding="utf-8")
    found = _existing_group(original)
    current = found[2] if found else []

    have = {_pkg_name(s) for s in current}
    merged = list(current) + [s for s in specs if _pkg_name(s) not in have]
    if merged == current:
        return f"already declared in pyproject.toml [dependency-groups].{GROUP_NAME}"

    rendered = f"{GROUP_NAME} = [" + ", ".join(f'"{s}"' for s in merged) + "]"
    section = re.search(r"^\[dependency-groups\]\s*$", original, re.M)
    if found:
        # Key exists — replace the array in place, preserving everything around it.
        start, end, _ = found
        updated = original[:start] + rendered + original[end:]
    elif section:
        # Section exists but the key does not — insert right after the header.
        updated = original[: section.end()] + f"\n{MARKER}\n{rendered}" + original[section.end():]
    else:
        sep = "" if original.endswith("\n\n") else ("\n" if original.endswith("\n") else "\n\n")
        updated = f"{original}{sep}[dependency-groups]\n{MARKER}\n{rendered}\n"

    if not _validate_toml(updated):
        raise ValueError("edit would produce invalid TOML — pyproject.toml left untouched")
    path.write_text(updated, encoding="utf-8")
    return f"declared in pyproject.toml [dependency-groups].{GROUP_NAME}"


def declare_in_requirements(req: Path, specs: list[str]) -> str:
    harness_req = req.parent / HARNESS_REQ_FILE

    current: list[str] = []
    if harness_req.exists():
        current = [
            ln.strip()
            for ln in harness_req.read_text(encoding="utf-8").splitlines()
            if ln.strip() and not ln.lstrip().startswith("#")
        ]
    have = {_pkg_name(s) for s in current}
    merged = current + [s for s in specs if _pkg_name(s) not in have]

    actions = []
    if merged != current:
        harness_req.write_text(MARKER + "\n" + "\n".join(merged) + "\n", encoding="utf-8")
        actions.append(f"wrote {HARNESS_REQ_FILE}")

    body = req.read_text(encoding="utf-8")
    if HARNESS_REQ_FILE not in body:
        sep = "" if body.endswith("\n") or not body else "\n"
        req.write_text(f"{body}{sep}-r {HARNESS_REQ_FILE}\n", encoding="utf-8")
        actions.append(f"referenced from {req.name}")

    return ", ".join(actions) if actions else f"already declared in {HARNESS_REQ_FILE}"


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: declare-repo-deps.py <repo-path> <pkg-spec> [...]", file=sys.stderr)
        return 2

    repo = Path(argv[1])
    specs = argv[2:]
    if not repo.is_dir():
        print(f"  SKIP {repo}: not a directory")
        return 0

    pyproject = repo / "pyproject.toml"
    requirements = repo / "requirements.txt"
    try:
        if pyproject.is_file():
            print(f"  {repo.name}: {declare_in_pyproject(pyproject, specs)}")
        elif requirements.is_file():
            print(f"  {repo.name}: {declare_in_requirements(requirements, specs)}")
        else:
            print(f"  {repo.name}: no pyproject.toml or requirements.txt — nothing to declare")
    except (OSError, ValueError) as exc:
        print(f"  {repo.name}: FAILED to declare — {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
