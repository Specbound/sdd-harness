# First-Time Setup

> Use this when setting up the SDD harness on a new machine or for the first time.  
> Each section tells you what to check first — only run the install steps if the tool isn't already there.

---

## Platform Support

| Platform | Support level | Notes |
|---|---|---|
| **Linux** | Full | All tools supported natively |
| **macOS** | Full | ztk via Homebrew; rest identical to Linux |
| **Windows (WSL2)** | Full | Recommended for Windows — run all commands inside WSL2; identical to Linux |
| **Windows (native)** | Partial | npm/Node tools work natively; ztk and bash hooks require WSL2 or Git Bash |

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

## Step 1: ztk (Token Compression)

ztk is the most impactful global tool — it compresses all Bash output by 78–90% before it reaches Claude.

### Check if already installed

```bash
which ztk && ztk --version
```

**If found** — just wire the global hook (one command):
```bash
ztk init -g
```

**If not found** — build from source (Linux / macOS / WSL2):

**macOS** — use Homebrew:
```bash
brew install codejunkie99/ztk/ztk
ztk init -g
```

**Linux / WSL2** — build from source (no prebuilt binary):
```bash
# 1. Get the Zig toolchain
curl -fL "https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz" -o /tmp/zig.tar.xz
tar -xf /tmp/zig.tar.xz -C /tmp/

# 2. Clone source
git clone https://github.com/codejunkie99/ztk /tmp/ztk-src
cd /tmp/ztk-src

# 3. Apply required patches before building:
#    In src/proxy.zig     — remove: permissions.checkCommand(cmd_str, &.{}, allocator)
#    In src/hooks/claude_rewrite.zig — change: permissionDecision: "ask" → "allow"
#    (without these patches: blocked commands + permission dialogs on every Bash call)

# 4. Build
/tmp/zig-x86_64-linux-0.16.0/zig build -Doptimize=ReleaseSmall

# 5. Install
mkdir -p ~/.local/bin
cp zig-out/bin/ztk ~/.local/bin/ztk
chmod +x ~/.local/bin/ztk

# 6. Ensure ~/.local/bin is in PATH (add to ~/.bashrc if not already there)
export PATH="$HOME/.local/bin:$PATH"

# 7. Wire the global hook
ztk init -g
```

**Windows (native — no WSL2)**: ztk has no Windows binary. Skip this step; token compression will not be active. To get it, install WSL2 and run the Linux instructions above inside it.

`ztk init -g` writes a `PreToolUse` hook to `~/.claude/settings.json`. All projects inherit it automatically.

**Verify:**
```bash
ztk stats    # shows cumulative savings (starts at 0 on fresh install)
```

---

## Step 2: GitNexus (Code Intelligence)

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

## Step 3: impeccable (Frontend Design QA)

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

## Step 4: uv (Python Package Manager)

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

## Step 5: Privacy Filter / opf (PII Scanning)

Optional. Blocks commits containing secrets, emails, account numbers, etc.

### Check if already installed

```bash
which opf
```

**If found** — nothing else needed (downloads model weights on first run, ~600MB to `~/.opf/`).

**If not found:**
```bash
uv pip install opf
# or: pip install opf
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

## Step 6: Per-Project Install

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
Or use the WSL2 path if Claude Code is running inside WSL2.

Then, inside Claude Code in the project directory, run these once:

```
/kiro:steering         # scans codebase, generates steering/product.md, tech.md, structure.md
/kiro:setup-routine    # registers nightly maintenance (runs in Anthropic's cloud at 11pm)
```

Update `.gitignore` to exclude harness files:
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
.claude/memory/
.claude/docs/

# Keep this one committed:
!.claude/settings.local.json
```

---

## Quick Checklist

Run through this on a fresh machine:

| Tool | Check (Linux/macOS/WSL2) | Install if missing | Activate |
|---|---|---|---|
| `ztk` | `which ztk` | Linux/WSL2: build from source (Step 1); macOS: `brew install codejunkie99/ztk/ztk`; Windows native: requires WSL2 | `ztk init -g` |
| `gitnexus` | `which gitnexus` | `npm install -g gitnexus` (all platforms) | `/kiro:gitnexus-setup` per-project |
| `impeccable` | `which impeccable` | `npm install -g impeccable` (all platforms) | automatic via hook |
| `uv` | `which uv` | Linux/macOS/WSL2: `curl -LsSf https://astral.sh/uv/install.sh \| sh`; Windows: see Step 4 | nothing extra |
| `opf` | `which opf` | `uv pip install opf` (all platforms) | wire pre-commit hook |
| harness | `ls ~/.claude/sdd-harness/install.sh` | clone/copy harness | `install.sh /path/to/project` |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ztk: command not found` in hook | `~/.local/bin` not in PATH | Add `export PATH="$HOME/.local/bin:$PATH"` to `~/.bashrc` |
| Permission dialog on every Bash call | ztk built without the `"ask"→"allow"` patch | Rebuild with patch applied |
| Bash commands blocked with "command denied" | ztk built without the `isSuspicious` removal patch | Rebuild with patch applied |
| Hook not firing at all | `ztk init -g` not run | Run `ztk init -g` |
| GitNexus context missing in Claude | MCP not in `settings.json` or repo not indexed | Run `/kiro:gitnexus-setup` |
| impeccable scans not appearing | Binary not in PATH | `npm install -g impeccable` |
| Maintenance not running | `/kiro:setup-routine` not run | Run it inside Claude Code |
| **Windows:** hooks fail with `bash: /bin/bash: No such file` | Claude Code running on native Windows; hook paths are Linux-style | Use WSL2 so Claude Code runs in Linux, or change hook commands from `/bin/bash` to the Git Bash path (`C:/Program Files/Git/bin/bash.exe`) |
| **Windows:** `uv` not found after install | PowerShell PATH not reloaded | Restart terminal or run `. $env:USERPROFILE\.cargo\env` (or reopen shell) |
| **Windows:** `install.sh` fails | Script requires bash | Run from Git Bash or WSL2, not PowerShell or CMD |
