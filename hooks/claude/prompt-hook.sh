#!/usr/bin/env bash
# purpose: Injects hot-memory (current priorities) on the first prompt of a session and every Nth prompt after.
# Context Priming Hook — injects hot-memory on UserPromptSubmit
#
# Not every prompt: hot-memory is ~2k tokens and each injection stays in the
# transcript, so injecting on every prompt re-sends one more copy on every
# later API call. It is injected on the 1st prompt of a session, then every
# SDD_HOT_MEMORY_EVERY prompts (default 10), and on the first prompt after a
# compaction (the summary may have dropped it).
#
# Counter lives in .claude/memory/.prompt-hook/<session_id>.json. Any failure to
# read the event or the counter injects — a missed injection is invisible, an
# extra one costs 2k tokens.
# Must be fast (<1s) since it fires on every prompt
#
# Size budget: Claude Code keeps hook output inline only up to ~10KB. Above that
# it stores the output in a side file and the model sees a 2KB preview — measured
# 2026-11-18 across 123 persisted outputs (largest inline 9,825 bytes, smallest
# persisted 10.2KB). hot-memory's cap was counted in lines, so it reached 11KB in
# 43 long lines and every injection was cut to its first 2KB: three of nine
# priorities, and none of Active Specs, Key Decisions or System Notes. So the
# output is capped at SDD_HOT_MEMORY_MAX_BYTES (default 9000, bytes because
# multi-byte text makes bytes >= characters), cut at a line boundary, and ends
# with a line saying what was left out and where to read it.

HOT_MEMORY=".claude/memory/hot-memory.md"
STATE_DIR=".claude/memory/.prompt-hook"

EVENT_FILE="$(mktemp)"
cat > "$EVENT_FILE"
trap 'rm -f "$EVENT_FILE"' EXIT

[ -s "$HOT_MEMORY" ] || exit 0

DECISION="$(EVENT_FILE="$EVENT_FILE" STATE_DIR="$STATE_DIR" python3 - <<'PY'
import json, os, sys, time
from pathlib import Path

def inject(why):
    if why:
        print(f"[prompt-hook] {why} — injecting hot-memory", file=sys.stderr)
    print("inject")
    sys.exit(0)

try:
    every = int(os.environ.get("SDD_HOT_MEMORY_EVERY", "10"))
except ValueError:
    inject("SDD_HOT_MEMORY_EVERY is not an integer")
if every < 1:
    inject("SDD_HOT_MEMORY_EVERY < 1")

try:
    event = json.loads(Path(os.environ["EVENT_FILE"]).read_text())
except (OSError, ValueError) as exc:
    inject(f"unreadable hook event ({exc})")
sid = event.get("session_id") or ""
if not sid or "/" in sid:
    inject("no usable session_id")

# Compaction count from the transcript; a change resets the cadence.
compacts = 0
transcript = event.get("transcript_path") or ""
if transcript:
    try:
        compacts = Path(transcript).read_bytes().count(b'"compact_boundary"')
    except OSError:
        pass

state_dir = Path(os.environ["STATE_DIR"])
state_file = state_dir / f"{sid}.json"
fresh = {"n": 0, "compacts": compacts}
state = fresh
if state_file.is_file():
    try:
        state = json.loads(state_file.read_text())
    except ValueError:
        state = None
    if not isinstance(state, dict):
        # Restart the cadence (n=1 injects) rather than inject forever.
        print(f"[prompt-hook] corrupt counter {state_file} — reset", file=sys.stderr)
        state = fresh
if state.get("compacts") != compacts:
    state = {"n": 0, "compacts": compacts}

n = int(state.get("n", 0)) + 1
try:
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file.write_text(json.dumps({"n": n, "compacts": compacts}))
    if n == 1:
        # New session: drop counters untouched for a week.
        cutoff = time.time() - 7 * 86400
        for old in state_dir.glob("*.json"):
            if old.stat().st_mtime < cutoff:
                old.unlink()
except OSError as exc:
    inject(f"cannot write counter ({exc})")

print("inject" if (n - 1) % every == 0 else "skip")
PY
)"

[ "$DECISION" = "skip" ] && exit 0

HOT_MEMORY="$HOT_MEMORY" python3 - <<'PY'
import os, sys

path = os.environ["HOT_MEMORY"]
try:
    budget = int(os.environ.get("SDD_HOT_MEMORY_MAX_BYTES", "9000"))
except ValueError:
    budget = 9000
head = "--- Active Context (hot-memory) ---\n"
foot = "--- End Active Context ---\n"
with open(path, "rb") as f:
    body = f.read()
if body and not body.endswith(b"\n"):
    body += b"\n"

room = budget - len(head.encode()) - len(foot.encode())
if len(body) <= room:
    shown, note = body, ""
else:
    note_room = 260  # reserved for the truncation line
    kept, used = [], 0
    for line in body.splitlines(keepends=True):
        if used + len(line) > room - note_room:
            break
        kept.append(line)
        used += len(line)
    shown = b"".join(kept)
    note = (f"[hot-memory truncated: showing {len(shown)} of {len(body)} bytes to stay under "
            f"the {budget}-byte inline limit. Read {path} for the rest, and run "
            f"/kiro:housekeeping to bring it under its size cap.]\n")
    print(f"[prompt-hook] hot-memory is {len(body)} bytes, over the {budget}-byte budget — truncated",
          file=sys.stderr)

out = sys.stdout.buffer
out.write(head.encode())
out.write(shown)
out.write(note.encode())
out.write(foot.encode())
PY
