#!/bin/bash
# startup-payload-audit.sh — measure the fixed per-session "startup payload" token tax.
#
# RTK/lean-ctx/Headroom all reduce *runtime* token cost (shell output, file reads, API
# context). None measure the *startup* cost: the layered CLAUDE.md + @imports + .claude/rules
# + auto-loaded MEMORY.md that load before you do anything. This audit quantifies and guards
# that growth — directly enforcing CLAUDE.md's own "read on demand, not upfront" rule.
#
# Deterministic (no LLM call). Writes .claude/reports/context/startup-payload.json, which the
# dashboard's Context Health tab reads. Self-paces to daily via a state-file guard so calling
# it from the orchestrator every day is a cheap no-op between runs.
#
# Usage:
#   startup-payload-audit.sh            — run for the current repo (cwd), respecting cadence
#   startup-payload-audit.sh --force    — ignore the cadence guard and run now
#
# Env:
#   SDD_SKIP_STARTUP_AUDIT=1            — opt out entirely
#   SDD_STARTUP_PAYLOAD_BUDGET=<tokens> — over-budget threshold (default 8000)
#   SDD_STARTUP_STALE_DAYS=<days>       — flag files unchanged longer than this (default 45)

set -u

[ "${SDD_SKIP_STARTUP_AUDIT:-0}" = "1" ] && exit 0

REPO="$(pwd)"
FORCE=false
[ "${1:-}" = "--force" ] && FORCE=true

MIN_GAP_DAYS=1
STATE_FILE="$REPO/.claude/memory/.last-startup-payload-audit"
TODAY="$(date +%Y-%m-%d)"

if [ "$FORCE" = false ] && [ -f "$STATE_FILE" ]; then
  last="$(cut -dT -f1 "$STATE_FILE" 2>/dev/null | head -1)"
  if [ "$last" = "$TODAY" ]; then
    exit 0   # already ran today — cheap no-op
  fi
fi

# Only meaningful inside an installed repo
[ -d "$REPO/.claude" ] || exit 0

BUDGET="${SDD_STARTUP_PAYLOAD_BUDGET:-8000}"
STALE_DAYS="${SDD_STARTUP_STALE_DAYS:-45}"

python3 - "$REPO" "$BUDGET" "$STALE_DAYS" <<'PYEOF'
import json, os, re, sys, time
from pathlib import Path
from datetime import datetime, timezone

repo = Path(sys.argv[1])
budget = int(sys.argv[2])
stale_days = int(sys.argv[3])
now = time.time()

def est_tokens(text: str) -> int:
    # Rough but stable estimate: ~4 chars/token.
    return max(0, round(len(text) / 4))

def age_days(p: Path) -> float:
    try:
        return round((now - p.stat().st_mtime) / 86400.0, 1)
    except OSError:
        return 0.0

# ── Resolve the auto-memory MEMORY.md path (repo path with / → -) ──────────────
def auto_memory_file(repo: Path) -> Path:
    escaped = str(repo).replace("/", "-")
    return Path.home() / ".claude" / "projects" / escaped / "memory" / "MEMORY.md"

# ── Collect the startup file set ──────────────────────────────────────────────
candidates = []
seen = set()

def add(p: Path, label: str):
    rp = p.resolve()
    if rp in seen:
        return
    seen.add(rp)
    candidates.append((label, p))

# Project instruction files that load at session start
add(repo / "CLAUDE.md", "CLAUDE.md")
add(repo / "AGENTS.md", "AGENTS.md")
for rule in sorted((repo / ".claude" / "rules").glob("*.md")) if (repo / ".claude" / "rules").is_dir() else []:
    add(rule, f".claude/rules/{rule.name}")
add(repo / ".claude" / "memory" / "hot-memory.md", ".claude/memory/hot-memory.md")
mem = auto_memory_file(repo)
add(mem, "auto-memory/MEMORY.md")

# ── Resolve one level of @imports inside CLAUDE.md and collect ghost refs ──────
ghosts = []
import_re = re.compile(r'(?m)^\s*@([^\s]+)')
claude_md = repo / "CLAUDE.md"
if claude_md.is_file():
    try:
        text = claude_md.read_text(errors="replace")
    except OSError:
        text = ""
    for m in import_re.finditer(text):
        ref = m.group(1)
        target = Path(os.path.expanduser(ref))
        if not target.is_absolute():
            target = (repo / ref)
        if target.is_file():
            add(target, f"@{ref}")
        else:
            ghosts.append(f"@{ref}")

# ── Measure ───────────────────────────────────────────────────────────────────
files = []
total = 0
stale_count = 0
for label, p in candidates:
    if not p.is_file():
        continue
    try:
        content = p.read_text(errors="replace")
    except OSError:
        continue
    tok = est_tokens(content)
    a = age_days(p)
    is_stale = a > stale_days
    if is_stale:
        stale_count += 1
    total += tok
    files.append({
        "path": label,
        "tokens": tok,
        "age_days": a,
        "stale": is_stale,
    })

files.sort(key=lambda f: f["tokens"], reverse=True)

out = {
    "generated": datetime.now(timezone.utc).isoformat(),
    "repo": str(repo),
    "total_tokens": total,
    "budget": budget,
    "over_budget": total > budget,
    "file_count": len(files),
    "stale_count": stale_count,
    "stale_days": stale_days,
    "ghosts": ghosts,
    "files": files,
}

report_dir = repo / ".claude" / "reports" / "context"
report_dir.mkdir(parents=True, exist_ok=True)
(report_dir / "startup-payload.json").write_text(json.dumps(out, indent=2))
print(f"startup-payload: {total} tok across {len(files)} files "
      f"(budget {budget}, {'OVER' if total > budget else 'ok'}), "
      f"{stale_count} stale, {len(ghosts)} ghost refs")
PYEOF

# Record run date for the cadence guard
date -Iseconds > "$STATE_FILE"
