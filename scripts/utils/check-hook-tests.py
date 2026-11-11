#!/usr/bin/env python3
"""Require a sibling `*.test.sh` for every Claude hook that can block a tool call.

A guardrail you have not tested is a guardrail you do not have. A blocking hook
that silently stops firing looks exactly like one that has nothing to block, so
the only proof it works is a test that feeds it the dangerous input and asserts
the deny. At the time this guard was written, 4 of the 11 blocking hooks in
`hooks/claude/` had no test, and memory already recorded gates that broke
without anyone noticing (risk-zone-preamble-shadows-rows).

"Can block" means the hook emits one of the three hard-stop signals Claude Code
honours: `exit 2`, a `permissionDecision` of `deny`/`ask`, or a `"decision":
"block"` JSON object. Hooks that only print advice to stdout are soft gates and
out of scope — they cannot fail closed, so a broken one costs a missing hint,
not a missing block.

Same ratchet as check-no-regex.py: existing offenders live in
`hook-test-debt.txt` and are reported as DEBT. Two things fail the run:

  * a blocking hook with no test that is NOT on the ledger
  * a ledger entry that now has a test or no longer blocks (stale — remove it)

No regex. Detection is literal-token membership on comment-stripped lines.

Usage:
    check-hook-tests.py           # scan hooks/claude and hooks/global
    check-hook-tests.py --list    # print blocking hooks with their test status
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

LEDGER = Path(__file__).resolve().parent / "hook-test-debt.txt"

HOOK_DIRS = ("hooks/claude", "hooks/global")

# Literal hard-stop signals. Spacing variants are listed rather than normalised:
# JSON written by hand in heredocs uses both.
BLOCK_TOKENS = (
    "exit 2",
    '"permissionDecision": "deny"',
    '"permissionDecision":"deny"',
    '"permissionDecision": "ask"',
    '"permissionDecision":"ask"',
    '"decision": "block"',
    '"decision":"block"',
)


def is_hook(path: Path) -> bool:
    return path.name.endswith(".sh") and not path.name.endswith(".test.sh")


def test_path(hook: Path) -> Path:
    return hook.with_name(hook.name[: -len(".sh")] + ".test.sh")


def block_signals(path: Path) -> list[str]:
    """Return the hard-stop tokens found on non-comment lines.

    `exit 2` must not be followed by another digit — `exit 20` is not a block.
    """
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        raise SystemExit(f"hook-tests: cannot read {path}: {exc}") from exc

    found: list[str] = []
    for line in lines:
        if line.lstrip().startswith("#"):
            continue
        for token in BLOCK_TOKENS:
            if token in found:
                continue
            idx = line.find(token)
            if idx == -1:
                continue
            end = idx + len(token)
            if token == "exit 2" and end < len(line) and line[end].isdigit():
                continue
            found.append(token)
    return found


def repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=False,
    )
    if out.returncode == 0 and out.stdout.strip():
        return Path(out.stdout.strip())
    return Path.cwd()


def load_ledger() -> set[str]:
    if not LEDGER.is_file():
        return set()
    entries = set()
    for line in LEDGER.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            entries.add(line)
    return entries


def main(argv: list[str]) -> int:
    root = repo_root()
    hooks = sorted(
        p for d in HOOK_DIRS if (root / d).is_dir()
        for p in (root / d).iterdir() if is_hook(p)
    )

    blocking = {h: block_signals(h) for h in hooks}
    blocking = {h: sig for h, sig in blocking.items() if sig}
    untested = {str(h.relative_to(root)) for h in blocking if not test_path(h).is_file()}

    if "--list" in argv:
        for h, sig in blocking.items():
            status = "untested" if str(h.relative_to(root)) in untested else "tested"
            print(f"{status:9} {h.relative_to(root)}  [{', '.join(sig)}]")
        return 0

    ledger = load_ledger()
    new = sorted(untested - ledger)
    stale = sorted(ledger - untested)

    if not new and not stale:
        print(f"hook-tests: ok — {len(blocking)} blocking hook(s), "
              f"{len(untested)} known untested on the ledger, 0 new.")
        return 0

    print("=" * 74)
    print("  HOOK-TEST GUARD — every blocking hook needs a sibling *.test.sh")
    print("=" * 74)
    if new:
        print("\nBlocking hooks with NO test (not on the debt ledger):\n")
        for rel in new:
            print(f"  {rel}  ->  add {Path(rel).name[:-3]}.test.sh")
        print("\n  The test must feed the hook the input it exists to stop and assert")
        print("  the block fires. See hooks/claude/git-destructive-guard-hook.test.sh.")
    if stale:
        print("\nSTALE ledger entries (now tested, or no longer blocking — remove the line):\n")
        for rel in stale:
            print(f"  {rel}")
        print(f"\n  Edit {LEDGER.name}. The ledger only shrinks.")
    print()
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
