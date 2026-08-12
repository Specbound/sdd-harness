# ERRORS Log

Approaches that took 2+ attempts — what failed, what worked, and why.

---

## 2026-08-12 — every new project got an unparseable settings.json (comments in JSON)

**Symptom:** Opening a freshly installed project shows "Settings file failed to parse: `<project>/.claude/settings.json` — Invalid or malformed JSON. Permission rules and other settings from this file are not in effect." No other error; hooks and permissions just silently do nothing.

**Root cause:** `templates/settings.json.template` closed its root object at line 269, then carried 19 `//` comment lines documenting the optional ktx MCP server. JSON permits neither comments nor trailing content. `install.sh` copied that template verbatim into every new project, so every install produced a dead settings file. Ironically `install.sh` already stripped `//` comments before merging `~/.claude/settings.json` — the project-copy path skipped that step. `update.sh` never touches project settings, so bad files never self-healed.

**Fix:** Comments removed from the template; notes moved to `templates/settings.notes.md.template`, copied to `.claude/settings.notes.md` on install/update. `scripts/setup/check-settings-json.sh` validates templates before `install.sh` copies and after `update.sh` regenerates; `scripts/setup/repair-settings-json.py` peels a trailing comment block into the sidecar and runs idempotently on every install/update. Backfilled `whisper-pipeline` (JSON body byte-identical to the original lines 1-269).

**Lesson:** Claude Code fails *quiet* on malformed settings — the file parses to nothing and the session looks normal. Never annotate a `.json` file, even with content after the final brace; use a `.notes.md` sidecar. Any template copied verbatim by the installer needs a parse check in the copy path.

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
