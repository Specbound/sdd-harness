# ERRORS Log

Approaches that took 2+ attempts — what failed, what worked, and why.

---

## 2026-05-31 — `update.sh` wiped global skills into spilled files (macOS BSD `cp`)

**Symptom:** After running `update.sh`, `~/.claude/skills/` lost every named skill dir (evaluation, macro-evals, …) and the root filled with loose files (`SKILL.md`, `analyze.py`, `resources/`, `scripts/`) — the *contents* of skills dumped at top level, each overwriting the last.

**Root cause (two bugs, found together):**
1. `update.sh`/`install.sh` sync skills via `for skill_dir in "$HARNESS_DIR/skills"/*/` — the `*/` glob yields paths **with a trailing slash**. Passing `evaluation/` to `cp -r "$src" "$dst/"` triggers the macOS BSD `cp` behavior: a trailing slash on the source copies its **contents** into the destination instead of creating `dst/evaluation/`. (GNU cp on Linux/WSL does not do this, so it was latent until run on macOS.) `sync_dir`'s own comment warned about exactly this, but the trailing slash defeated it.
2. `update.sh` `do_update` also aborted on the first entry when the harness repo itself was in `projects.txt`: `cp impeccable-detect-hook.sh` onto itself errors "are identical", and `set -e` killed the whole run before the real repos updated.

**Fix:**
- `sync_dir` now strips the trailing slash internally: `local src="${1%/}"`. Callers also pass `${skill_dir%/}` (belt + suspenders).
- `do_update` skips when `$proj` resolves to `$HARNESS_DIR` (harness source is self-managed by the tail block).
- Recovery: source `skills/` was intact (it's the truth); rebuilt `~/.claude/skills` by purging spillage (keeping symlinks + the scientific pack) and re-copying each source dir without a trailing slash.

**Lesson:** Any `cp -r` of a globbed `*/` path on macOS must strip the trailing slash, or it content-dumps. Test installer changes on macOS, not just Linux. The harness must never be a `do_update` target of its own `update.sh`.
