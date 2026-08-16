---
name: agent-manager-skill
description: "Control coding-agent CLI panes/sessions running in the terminal — start, prompt, wait on lifecycle state, read output. Prefers Herdr (github.com/herdrdev/herdr) when the session is Herdr-managed; falls back to a tmux+python3 wrapper otherwise."
risk: low
source: community (herdr) + community (fractalmind-ai/agent-manager-skill, fallback path)
---

# Agent Manager Skill

## When to use

Use this skill when the user explicitly asks to inspect, control, or coordinate another coding-agent CLI session running in a terminal pane — split panes, start a named agent, prompt it, wait for it to go idle/blocked/done, or read its output.

Do **not** use this merely because a task could benefit from a background terminal, delegation, or parallel work in the abstract — that's `dispatching-parallel-agents` / `multi-agent-patterns` territory (in-process `Agent`/`Task` orchestration). This skill is specifically for controlling *other terminal panes*.

## Path 1 — Herdr (preferred, if available)

Herdr is a terminal runtime purpose-built for hosting coding-agent CLI sessions: it classifies each pane's agent as `idle`/`working`/`blocked`/`done`/`unknown`, persists sessions through disconnects, and exposes a CLI + JSON socket API.

**Gate every use on this check — do not skip it:**

```bash
test "${HERDR_ENV:-}" = 1
```

If it fails, you are not running inside a Herdr-managed pane. Say so and stop — do not attempt to control a Herdr session from outside Herdr, and do not install/launch Herdr just to gain this capability unless the user asks for it.

Install (user-initiated only, never silently): `curl -fsSL https://herdr.dev/install.sh | sh`, then launch a session with `herdr`.

### Command reference (verified against `herdrdev/herdr` v0.8.0 upstream skill)

Discover state — never predict IDs, always read them from JSON responses:

```bash
herdr workspace list
herdr tab list --workspace "$HERDR_WORKSPACE_ID"
herdr pane list --workspace "$HERDR_WORKSPACE_ID"
herdr agent list
```

Split a sibling pane, preserving the caller's cwd and focus:

```bash
herdr pane split --current --direction right --cwd "$PWD" --no-focus
# → read new pane ID from .result.pane.pane_id
```

Start a named agent in an existing, idle shell pane (this does not create/split panes itself):

```bash
herdr agent start reviewer --kind codex --pane <pane-id>
```

Prompt it and wait for a settled state (`idle`/`done`/`blocked`) — this is the normal case, don't add `--until` on top of it:

```bash
herdr agent prompt reviewer "Review current diff, report only actionable findings." --wait --timeout 120000
```

Wait for a *specific* state only (e.g. blocked-on-approval) when you need to react to that specific transition:

```bash
herdr agent wait reviewer --until blocked --timeout 120000
```

Read output before deciding what to send next:

```bash
herdr agent get reviewer
herdr agent read reviewer --source recent-unwrapped --lines 120
```

Send raw keys (e.g. dismiss a prompt, interrupt):

```bash
herdr agent send-keys reviewer esc
```

Run/inspect an ordinary (non-agent) process in a pane: `herdr pane run <pane-id> "<cmd>"`, `herdr pane wait-output <pane-id> --match "<text>" --timeout 120000`, `herdr pane read <pane-id> --source recent-unwrapped --lines 120`.

**Safety rules:** use `--no-focus` for background work unless the user asked to switch context; never close workspaces/tabs/panes/sessions you didn't create; never run `herdr server stop` or kill the main Herdr process. Full syntax: `herdr --help` and `herdr <group> --help` (don't run bare `herdr` — it launches the attach TUI).

## Path 2 — tmux fallback (no Herdr available)

If `HERDR_ENV` isn't set and the user hasn't opted into installing Herdr, fall back to the plain tmux wrapper. This path has no lifecycle-state detection (idle/working/blocked/done) — you can only tell whether the tmux pane process is alive, not what the agent inside it is doing.

```bash
git clone https://github.com/fractalmind-ai/agent-manager-skill.git
python3 agent-manager/scripts/main.py doctor
python3 agent-manager/scripts/main.py list
python3 agent-manager/scripts/main.py start EMP_0001
python3 agent-manager/scripts/main.py monitor EMP_0001 --follow
python3 agent-manager/scripts/main.py assign EMP_0002 <<'EOF'
Follow teams/fractalmind-ai-maintenance.md Workflow
EOF
```

Requires `tmux` and `python3`. Agents are configured under an `agents/` directory (see the fractalmind-ai repo for examples).

## Notes

- This skill deliberately does not install or configure Herdr on your behalf — that's an environment choice the user makes, not something to wire into a hook.
- See also: `loki-mode` (in-repo `tmux new-session`/`new-window` pattern for parallel Claude Code sessions), `dispatching-parallel-agents`, `using-git-worktrees` (git-level isolation, a different axis from terminal-session control).
