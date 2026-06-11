# First-Time Setup

> Use this when setting up the SDD harness on a new machine or for the first time.  
> Each section tells you what to check first — only run the install steps if the tool isn't already there.

---

## Platform Support

| Platform | Support level | Notes |
|---|---|---|
| **Linux** | Full | All tools supported natively |
| **macOS** | Full | RTK via Homebrew; rest identical to Linux |
| **Windows (WSL2)** | Full | Recommended for Windows — run all commands inside WSL2; identical to Linux |
| **Windows (native)** | Partial | npm/Node tools work natively; bash hooks require WSL2 or Git Bash |

**Windows recommendation**: Use WSL2. Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) (`wsl --install` in PowerShell as Administrator), then follow the Linux instructions throughout this guide from inside a WSL2 terminal.

---

## Step 0: Verify Prerequisites

These must already exist. Check them first:

**Linux / macOS / WSL2:**
```bash
claude --version    # Claude Code CLI
node --version      # Node.js (needed for npx and npm installs)
git --version       # git
```

**Windows (PowerShell — if not using WSL2):**
```powershell
claude --version
node --version
git --version
```

If any are missing, install them before continuing.

> On Windows without WSL2: install [Node.js](https://nodejs.org) and [Git for Windows](https://git-scm.com/download/win). Claude Code CLI installation is the same (`npm install -g @anthropic-ai/claude-code` or via the installer).

---

## Step 0b: Power Tools (ripgrep, fd, jq)

These optional CLI tools dramatically improve Claude's file search speed and JSON parsing. When present, Claude uses them automatically instead of slower `find`/`grep`/`cat`.

| Tool | Install check | What it does |
|---|---|---|
| `rg` (ripgrep) | `which rg` | Fast recursive search; replaces grep |
| `fd` | `which fd` | Fast file finder; replaces find |
| `jq` | `which jq` | JSON parsing and filtering |

**macOS (Homebrew):**
```bash
brew install ripgrep fd jq
```

**Linux / WSL2 (apt):**
```bash
sudo apt-get install -y ripgrep fd-find jq
# fd-find installs as 'fdfind'; create an alias:
mkdir -p ~/.local/bin
ln -sf "$(which fdfind)" ~/.local/bin/fd
```

Skip with: `bootstrap.sh --skip-power-tools`

---

## Step 1: RTK (Token Compression)

RTK is the most impactful global tool — it compresses all Bash output by 60–90% before it reaches Claude.

### Check if already installed

```bash
which rtk && rtk --version
```

**If found** — just wire the global hook (one command):
```bash
rtk init -g --auto-patch
```

**If not found** — install via Homebrew (macOS, Linux, WSL2):

```bash
brew install rtk
rtk init -g --auto-patch
```

**Linux without Homebrew:**
```bash
curl -fsSL https://rtk-ai.app/install.sh | sh
rtk init -g --auto-patch
```

**Windows (native — no WSL2)**: RTK has no native Windows binary. Skip this step; token compression will not be active. To get it, install WSL2 and run the Linux instructions above inside it.

`rtk init -g` writes a `PreToolUse` hook to `~/.claude/settings.json`. All projects inherit it automatically.

**Verify:**
```bash
rtk gain    # shows cumulative savings (starts at 0 on fresh install)
```

---

## Step 2: Raindrop Workshop (Agent Tracing)

Raindrop Workshop is the harness's built-in AI-agent debugger. It captures every LLM call, tool invocation, and latency trace and streams them to `localhost:5899`. The harness auto-instruments all registered repos and exposes Workshop as a tab in the dashboard — **no per-repo `.env` changes needed**.

### Check if already installed

```bash
which raindrop && raindrop --version
```

**If found** — nothing else needed. Run `raindrop workshop` to confirm it starts.

**If not found** — install the CLI (global binary):

```bash
curl -fsSL https://raindrop.sh/install | bash
```

### Python SDK

The harness wires this automatically via `raindrop-setup.sh` during `install.sh` / `update.sh`. It:

- Installs `raindrop-ai` in each registered repo's virtualenv (`.venv/`, `venv/`, or `uv`-managed)
- Adds `RAINDROP_LOCAL_DEBUGGER=http://localhost:5899` to `~/.claude/settings.json` (Claude env)
- Adds the same export to `~/.bashrc` (shell env for user-run servers)

To run it manually (idempotent):

```bash
bash ~/.claude/sdd-harness/scripts/raindrop-setup.sh
source ~/.bashrc
```

**Verify:**
```bash
# Workshop starts on port 5899
raindrop workshop &
# Open harness dashboard → Workshop tab
python3 ~/.claude/sdd-harness/scripts/utils/dashboard.py
```

See `docs/raindrop/README.md` for full details on tracing, the eval loop, and troubleshooting.

---

## Step 3: GitNexus (Code Intelligence)

GitNexus is optional but recommended for large repos. It enriches file reads/edits with dependency and blast-radius context via a PreToolUse hook.

### Check if already installed

```bash
which gitnexus && gitnexus --version
```
or
```bash
npx gitnexus --version
```

**If found** — skip to per-project setup below.

**If not found:**
```bash
npm install -g gitnexus
```

### Per-project activation (run once per repo)

GitNexus requires indexing each repo separately. Either:

**Option A:** During `install.sh` (recommended for new projects):
```bash
~/.claude/sdd-harness/install.sh /path/to/project --with-gitnexus
```

**Option B:** After `install.sh`, inside Claude Code:
```
/kiro:gitnexus-setup
```

This indexes the repo (`.gitnexus/`), adds the MCP server to `.claude/settings.json`, updates `.gitignore`, and registers editor integration.

---

## Step 4: impeccable (Frontend Design QA)

Automatically flags design anti-patterns when Claude writes frontend files (`.tsx`, `.jsx`, `.css`, etc.). The hook silently skips if the binary isn't installed — no errors, just no scans.

### Check if already installed

```bash
which impeccable && impeccable --version
```

**If found** — nothing else needed. The `impeccable-detect-hook.sh` is already in place after `install.sh` runs.

**If not found:**
```bash
npm install -g impeccable
```

That's it — the hook in `.claude/hooks/impeccable-detect-hook.sh` picks it up automatically on the next frontend file write.

---

## Step 5: uv (Python Package Manager)

Required for autoresearch and any project using `uv`-managed Python environments.

### Check if already installed

**Linux / macOS / WSL2:**
```bash
which uv && uv --version
```

**Windows (PowerShell):**
```powershell
Get-Command uv -ErrorAction SilentlyContinue; uv --version
```

**If found** — nothing else needed.

**If not found:**

**Linux / macOS / WSL2:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy BypassPolicy -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Or via winget:
```powershell
winget install --id=astral-sh.uv -e
```

---

## Step 6: Privacy Filter / opf (PII Scanning)

Optional. Blocks commits containing secrets, emails, account numbers, etc.

### Check if already installed

```bash
which opf
```

**If found** — nothing else needed (downloads model weights on first run, ~2.8GB to `~/.opf/`).

**If not found** (OPF is not on PyPI — install from OpenAI's GitHub source):
```bash
uv tool install --python 3.13 git+https://github.com/openai/privacy-filter.git
# or: pipx install --python python3.13 git+https://github.com/openai/privacy-filter.git
```

To wire as a pre-commit hook for a project:

**Linux / macOS / WSL2:**
```bash
# In your project root:
cat >> .git/hooks/pre-commit << 'EOF'
#!/bin/bash
bash "$(git rev-parse --show-toplevel)/.claude/hooks/scan-pii.sh" --staged
EOF
chmod +x .git/hooks/pre-commit
```

**Windows (Git Bash or PowerShell):**
```powershell
# In your project root (PowerShell):
$hookPath = ".git\hooks\pre-commit"
Add-Content $hookPath "#!/bin/bash"
Add-Content $hookPath 'bash "$(git rev-parse --show-toplevel)/.claude/hooks/scan-pii.sh" --staged'
# Git Bash handles the bash shebang; no chmod needed on Windows
```

---

## Step 7: Per-Project Install

Once global tools are in place, install the harness into each project:

**Linux / macOS / WSL2:**
```bash
~/.claude/sdd-harness/install.sh /path/to/project
# or with GitNexus in one shot:
~/.claude/sdd-harness/install.sh /path/to/project --with-gitnexus
```

**Windows (native, no WSL2):** Run from Git Bash:
```bash
~/.claude/sdd-harness/install.sh /c/dev/my-project
```
Or use the WSL2 path if Claude Code is running inside WSL2. From PowerShell, invoke Git Bash with the call operator from inside the repo: `& "C:\Program Files\Git\bin\bash.exe" install.sh /c/dev/my-project` (running the `.sh` directly fails with a `#!`-shebang parser error, and `~/...install.sh` fails as "not recognized as a cmdlet").

**Install into all registered projects at once:** use `--all` to walk `projects.txt`, skipping any project already installed (`.claude/kiro/` present):
```bash
~/.claude/sdd-harness/install.sh --all                  # skip already-installed
~/.claude/sdd-harness/install.sh --all --force          # re-sync every project (push updates)
~/.claude/sdd-harness/install.sh --all --with-gitnexus  # batch install + GitNexus
```

`install.sh` propagates **every** hook in the harness's `hooks/` directory into the project's `.claude/hooks/` (and `chmod +x`'s them), syncs `docs/` into `.claude/docs/`, and generates a project stack summary. The harness is the source of truth — which hooks actually fire is governed by the project's `.claude/settings.json` wiring, not by which files are present. Re-run `update.sh` to re-sync after the harness changes.

Then, inside Claude Code in the project directory, run these once:

```
/kiro:steering         # scans codebase, generates steering/product.md, tech.md, structure.md
/codebase-legibility   # sets up CLAUDE.md hierarchy, .claudeignore, and codebase map
```

Daily maintenance runs automatically via the local OS scheduler (registered by `install.sh` / `update.sh`). No per-project setup is required.

Update `.gitignore` to exclude harness files. `install.sh` automatically adds the core three entries (`.claude/`, `specs/`, `CLAUDE.md`) under a `# SDD harness` header — skip those below if already present. For the full recommended exclusion set:
```gitignore
CLAUDE.md
specs/
.claude/settings.json
.claude/.last-harness-check
.claude/hooks/
.claude/steering/
.claude/commands/
.claude/agents/
.claude/kiro/
# Per-user memory — stays local, never shared
.claude/memory/**
!.claude/memory/daily/
!.claude/memory/glacier/
!.claude/memory/meta/
!.claude/memory/.gitkeep
!.claude/memory/**/.gitkeep
.claude/docs/

# Keep this one committed:
!.claude/settings.local.json
```

---

## Quick Checklist

Run through this on a fresh machine:

| Tool | Check (Linux/macOS/WSL2) | Install if missing | Activate |
|---|---|---|---|
| `rg`, `fd`, `jq` | `which rg && which fd && which jq` | macOS: `brew install ripgrep fd jq`; Linux/WSL2: `apt-get install ripgrep fd-find jq` (see Step 0b) | automatic |
| `rtk` | `which rtk` | macOS/Linux/WSL2: `brew install rtk`; Linux no-brew: `curl -fsSL https://rtk-ai.app/install.sh \| sh`; Windows native: requires WSL2 | `rtk init -g --auto-patch` |
| `raindrop` | `which raindrop` | `curl -fsSL https://raindrop.sh/install \| bash` (all platforms) | automatic via `install.sh`; see Step 2 |
| `gitnexus` | `which gitnexus` | `npm install -g gitnexus` (all platforms) | `/kiro:gitnexus-setup` per-project |
| `impeccable` | `which impeccable` | `npm install -g impeccable` (all platforms) | automatic via hook |
| `uv` | `which uv` | Linux/macOS/WSL2: `curl -LsSf https://astral.sh/uv/install.sh \| sh`; Windows: see Step 5 | nothing extra |
| `opf` | `which opf` | `uv tool install --python 3.13 git+https://github.com/openai/privacy-filter.git` | wire pre-commit hook |
| harness | `ls ~/.claude/sdd-harness/install.sh` | clone/copy harness | `install.sh /path/to/project` |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `rtk: command not found` in hook | RTK not installed or not in PATH | `brew install rtk` |
| Workshop tab shows "not installed" | `raindrop` CLI missing | `curl -fsSL https://raindrop.sh/install \| bash` |
| No traces appearing in Workshop | `RAINDROP_LOCAL_DEBUGGER` not in env | Run `source ~/.bashrc`; or re-run `raindrop-setup.sh` |
| `raindrop-ai` import error at agent startup | SDK not installed in venv | `bash ~/.claude/sdd-harness/scripts/raindrop-setup.sh` |
| Permission dialog on every Bash call | Stale legacy hook from a prior token-compression tool still present in `~/.claude/settings.json` | Remove the old hook entry and run `rtk init -g` to install the current `rtk hook claude` entry |
| Hook not firing at all | `rtk init -g` not run | Run `rtk init -g --auto-patch` |
| GitNexus context missing in Claude | MCP not in `settings.json` or repo not indexed | Run `/kiro:gitnexus-setup` |
| impeccable scans not appearing | Binary not in PATH | `npm install -g impeccable` |
| Local daily maintenance not running (macOS) | LaunchAgent not loaded | `launchctl list com.sdd.daily-orchestrator` to check; re-run `install.sh` or `update.sh` to re-register |
| Local daily maintenance not running (Linux) | Cron entry missing | `crontab -l \| grep sdd-daily` to check; re-run `install.sh` or `update.sh` to re-register |
| Local daily maintenance not running (WSL) | Task Scheduler entry missing | `schtasks.exe /Query /TN "SDD Daily Orchestrator"` to check; re-run `install.sh` to re-register |
| **Windows:** hooks fail with `bash: /bin/bash: No such file` | Claude Code running on native Windows; hook paths are Linux-style | Use WSL2 so Claude Code runs in Linux, or change hook commands from `/bin/bash` to the Git Bash path (`C:/Program Files/Git/bin/bash.exe`) |
| **Windows:** `uv` not found after install | PowerShell PATH not reloaded | Restart terminal or run `. $env:USERPROFILE\.cargo\env` (or reopen shell) |
| **Windows:** `install.sh` fails | Script requires bash | Run from Git Bash or WSL2, not PowerShell or CMD |

_Last synced: 2026-06-01_
