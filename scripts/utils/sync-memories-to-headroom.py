#!/usr/bin/env python3
"""Bidirectional sync: harness markdown memories ↔ headroom SQLite DB.

Run with headroom's Python:
    ~/.local/share/uv/tools/headroom-ai/bin/python scripts/sync-memories-to-headroom.py

Import direction:  ~/.claude/projects/<harness>/memory/*.md  →  headroom SQLite
Export direction:  headroom SQLite new memories  →  MEMORY.md (Headroom section)

Uses headroom's built-in fingerprint no-op — cheap on repeated calls.
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

import re

from headroom import paths as headroom_paths
from headroom.memory.backends.local import LocalBackend, LocalBackendConfig
from headroom.memory.sync import sync
from headroom.memory.sync_adapters.claude_code import ClaudeCodeAdapter

HARNESS_PATH = Path.home() / ".claude" / "sdd-harness"
DB_PATH = headroom_paths.memory_db_path()  # ~/.headroom/memory.db


def _claude_project_dir(project_path: Path) -> str:
    """Encode path as Claude Code does: replace / \\ and . all with -."""
    return re.sub(r"[/\\.]", "-", str(project_path))


MEMORY_DIR = Path.home() / ".claude" / "projects" / _claude_project_dir(HARNESS_PATH) / "memory"
USER_ID = "dalesser"


async def main() -> int:
    if not MEMORY_DIR.exists():
        print(f"[headroom-sync] memory dir missing: {MEMORY_DIR}", file=sys.stderr)
        return 1

    config = LocalBackendConfig(db_path=str(DB_PATH))
    backend = LocalBackend(config)
    adapter = ClaudeCodeAdapter(memory_dir=MEMORY_DIR)

    result = await sync(backend, adapter, user_id=USER_ID)

    if result.imported or result.exported:
        print(
            f"[headroom-sync] imported={result.imported} exported={result.exported} "
            f"skipped={result.skipped_unchanged} ({result.duration_ms:.0f}ms)",
            flush=True,
        )
    # else: quiet no-op — fingerprints matched, nothing changed

    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
