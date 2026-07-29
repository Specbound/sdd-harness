# ERRORS Log

Approaches that took 2+ attempts — what failed, what worked, and why.

---

## 2026-07-28 — post-commit hook self-triggered a 9-commit "docs: auto-sync" recursion loop

**Symptom:** `hooks/git/post-commit` spammed 9 near-identical `docs: auto-sync (...)` commits in ~90 minutes with no human action between them.

**Root cause (two layered bugs, found in two separate fix commits 6 minutes apart):**
1. `HARNESS_CHANGED` detection matched `.md` files under `skills/` and `hooks/`. The hook's own doc-sync step commits its `.md` edits as `docs: auto-sync (...)`, which itself touches `.md` files under those watched dirs — so each auto-sync commit re-fired the same doc-sync agent, forever. No guard existed to recognize "the commit that just landed was one of ours."
2. Once the recursion guard (below) went in, a second bug surfaced: two commits landing in quick succession each spawned their own detached doc-sync run, and the two runs raced on the git index, dropping commits.

**Fix:**
1. (fc50068) Added a self-commit recursion guard at the top of `hooks/git/post-commit`: bail immediately (`exit 0`) when `git log -1 --format=%s` is `docs: auto-sync*`. Also excluded `.claude/` from the doc-sync `find` so it stops editing the untracked install mirror.
2. (1b0e617) Added an atomic `mkdir`-based lock around the commit/push section (portable — no `flock` on macOS) so a second concurrent run skips instead of racing; a lock left stale >30 min is stolen.

**Lesson:** Any git hook that both *watches* a set of paths and *writes back into those same paths* needs an explicit self-commit recursion guard from day one — "only .md changed" is not a sufficient stop condition if the hook's own output is .md. Test hooks like this by committing twice in rapid succession, not just once, to catch concurrent-run races.

**Process note:** This incident met the project's own "2+ attempts" ERRORS.md logging rule (two separate fix commits) but was not logged until this reflect pass, one day later. See the `git-hook-self-trigger-guard` pattern promoted in `.claude/memory/meta/patterns.md` for the reusable rule; `[memory-gap]` entry in `.claude/memory/observations.md` for the logging-lag itself.

## 2026-07-12 — launchd daily-orchestrator never ran (stale plist path + macOS TCC)

**Symptom:** Dashboard Automation tab: Drift Review / Skill-Curator "never" ran; Daily Maintenance last real run ~May 27 (46 days). `launchctl list com.sdd.daily-orchestrator` showed `LastExitStatus = 32512` (exit 127); `orchestrator.stderr.log` was a wall of "No such file or directory".

**Root cause (two layered bugs):**
1. Plist pointed at `~/.claude/sdd-harness/scripts/daily-orchestrator.sh`, but the script moved to `scripts/orchestration/` during the scripts reorg. `setup-mac-orchestrator.sh` was updated, but never re-run → the installed LaunchAgent kept the dead path. Exit 127 daily since ~May 26.
2. After regenerating the plist (`setup-mac-orchestrator.sh --force`), launchd still failed with exit 126 "Operation not permitted": **macOS TCC blocks launchd-spawned processes from `~/Documents`**. Verified with a minimal probe (`launchctl submit -- /bin/ls ~/Documents` → EPERM). Since `~/.claude/sdd-harness` is a symlink into `~/Documents/sdd-harness`, the scheduled job has NEVER worked — TCC blocked it from day one; only manual runs and session-start catch-ups ever executed.

**Fix:** (1) `bash scripts/orchestration/setup-mac-orchestrator.sh --force` after any script move. (2) Grant Full Disk Access to `/bin/bash` (System Settings → Privacy & Security → Full Disk Access → + → Cmd+Shift+G → `/bin/bash`), then `launchctl start com.sdd.daily-orchestrator` to verify.

**Lesson:** "43s ago" on the dashboard was a decoy — `daily-runner.sh` stamps `.last-routine-run` at START, and the session-start catch-up had just fired; absence of artifacts (`daily/` had no briefs) was the honest signal. On macOS, any launchd/cron job touching `~/Documents`/`~/Desktop` needs an FDA grant for the interpreter — a symlink from an unprotected path does NOT bypass TCC (it keys on the real path).

## 2026-06-14 — headroom proxy fails on terminal `claude` launch (missing deps)

**Symptom:** `claude` from terminal shows "Proxy exited with code 1: FastAPI required" or "h2 package not installed".

**Root cause:** `headroom-setup.sh` uv tool install was missing two deps:
1. `uvicorn` — FastAPI needs this to serve (was never in `--with` list)
2. `httpx[http2]` — headroom proxy uses `http2=True`; bare `httpx` doesn't include `h2`

**Fix:** Re-install with all deps:
```bash
uv tool install headroom-ai --python 3.12 \
  --with numpy --with sqlite-vec --with sentence-transformers \
  --with fastapi --with uvicorn --with "httpx[http2]"
```
Then patched `scripts/setup/headroom-setup.sh` to include `--with uvicorn --with "httpx[http2]"` on both uv install lines so it won't regress.

**Lesson:** When headroom proxy errors, check the uv tool env for missing packages first:
`ls ~/.local/share/uv/tools/headroom-ai/lib/python3.12/site-packages/ | grep -iE "fastapi|uvicorn|httpx|h2"`

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
