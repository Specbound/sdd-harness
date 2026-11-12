# Model Router — Per-Message Cost Routing

> Detailed reference for the local, fail-open proxy that routes each `claude` request to the cheapest model that can do that message's work.

## What It Is

A stdlib-only Python proxy that sits in front of every Claude Code request in a **wired project**. A local, non-generative classifier (`jeff`) scores each message for lane (what kind of work), difficulty, and a privacy signal; a pure policy function turns that score into a model selection; the proxy rewrites the request's `model` field before forwarding. When anything in that chain is unavailable — the classifier, the policy, the config — the request is forwarded unmodified on the model the conversation started with. Routing is a pure cost optimization: it never changes prompt content, never blocks a request, and `claude` never breaks because a routing component failed (R4).

## Architecture — The Proxy Chain

The router is two separate processes, not one (plus the jeff classifier as a third):

```
claude  --ANTHROPIC_BASE_URL-->  sentinel :8799  -->  worker :8798  -->  headroom proxy :8787 / upstream
                                       |                    |
                                       |                    +--> jeff classifier :8000 (loopback)
                                       |                    +--> ~/.sdd-router/ledger.jsonl + stats.json
                                       |
                                       +-- worker unreachable --> headroom proxy / upstream (skip worker)
```

`ANTHROPIC_BASE_URL` points at the **sentinel**, never directly at the worker. On the common path the sentinel forwards to the worker, which classifies, decides, rewrites `model` only if the selection differs from the baseline, and forwards to `upstream` — the address discovered at install time (headroom's proxy if headroom is installed, otherwise the Anthropic default). If the worker is unreachable (killed, hung, OOM), the sentinel's fallback forwards straight to `upstream` itself, skipping the worker entirely — the same behavior as a router-less install. Either way, headroom's compression (if installed) and the real API always sit downstream of the router, not in front of it: the classifier needs the user's original, uncompressed text to score accurately (`scripts/router/sentinel.py`, `scripts/router/server.py`).

## Why Two Services: Sentinel and Worker (the Watchdog)

The classifier/policy/ledger logic (the **worker**) is a non-trivial process — it parses TOML, calls an HTTP classifier, and writes a ledger. Any one of those can misbehave. If that logic lived in the same process that holds the public port Claude Code's traffic depends on, a crash in the logic would take the port down with it, and `claude` would simply fail. So the router splits into:

- **`sentinel.py`** — the only process bound to the public port. It imports nothing beyond stdlib, has no classifier/policy/ledger code in it at all, and on every request tries the worker first with a short connect timeout; any failure (refused, timeout, exception) falls through to direct upstream forwarding.
- **`server.py`** (the **worker**) — the actual classify → policy → ledger logic, listening only on loopback, never exposed as `ANTHROPIC_BASE_URL`.

Both run as separate processes — this is the requirement 4.5a watchdog split. Killing the worker leaves the sentinel serving pass-through immediately, with no restart wait. A single-process design cannot satisfy this: an in-process `try`/`except` guard cannot protect against the process itself disappearing.

## On-Demand Lifecycle (No Resident Service)

Since 2026-11-12 nothing is installed as a `launchd`/`systemd` service. `scripts/router/router-ctl.sh` starts and stops the sentinel (:8799), worker (:8798) and jeff (:8000), and `hooks/claude/router-session-hook.sh` — registered for both `SessionStart` and `SessionEnd` in `templates/settings.json.template` / `settings.harness.json.template` — calls it:

| Subcommand | What it does |
|---|---|
| `up <session-id>` | Registers the session; starts whatever is not running. Blocks until the sentinel accepts connections (exit 1 if it never does). Worker and jeff start without waiting — jeff takes seconds to load its model. |
| `down <session-id>` | Unregisters; stops everything once no live session remains. |
| `wired <project-dir>` | Exit 0 iff that project routes through the sentinel. |
| `status` | Prints what is running and which sessions hold it. |
| `stop` | Stops everything regardless of sessions. |

- **Refcount:** one marker file per session under `~/.sdd-router/run/sessions/`, holding the owning `claude` PID. `down` prunes markers whose PID is gone, so a session that crashed without `SessionEnd` cannot pin the router up.
- **Unwired projects are a no-op:** the hook checks `wired` first, so nothing starts for a project the router does not serve.
- **Loud failure:** if a wired session's `up` fails, the hook prints `[ROUTER-DOWN]` with the fix (`router-setup.sh`, or `uninstall` to unroute) — a wired session with no sentinel cannot reach the API at all.
- **No auto-restart:** a killed sentinel is not restarted by a service manager any more; the next `up` (next session start) starts it again.

## Pinned Python Interpreter (R10.8)

The router's config file (`router.toml`) is parsed with the stdlib `tomllib` module, which does not exist before Python 3.11. `router-setup.sh` resolves an interpreter satisfying `>=3.11` via `uv python find`, provisioning `3.12` with `uv python install` if nothing qualifying is found, and `router-ctl.sh` resolves the same way (`uv python find '>=3.11'`) each time it spawns a process — never a bare `python3`. This matters because the system `python3` on a stock Mac (`/usr/bin/python3`) is 3.9.6, and hooks run with a minimal `PATH` that would resolve that stale system interpreter first.

## The Reclaim Hazard and Its Three Mitigations

`headroom init --global --memory claude` reclaims the **global** `ANTHROPIC_BASE_URL` (`~/.claude/settings.json`) every time it runs — which `update.sh` does on every update. Under the old global wiring this silently pointed Claude Code back at headroom's proxy and un-routed the router: everything kept working, the request just stopped being classified and never got cheaper. Since 2026-11-12 the router no longer writes the global value at all — it wires each project's `.claude/settings.local.json`, which headroom's global write does not touch. The mitigations:

1. **Ordering.** `router-setup.sh` still runs immediately *after* `headroom-setup.sh` in both `install.sh` and `update.sh`, so `discover_upstream` sees headroom's proxy on a first run.
2. **Re-assertive repair.** Every run of `router-setup.sh` re-wires each eligible project's `settings.local.json` to the sentinel (idempotent — `Already wired` otherwise), without re-discovering (and overwriting) the `[router].upstream` value already stored in `router.toml` — that value is written exactly once, on the first successful install, and never touched again. If the global `settings.json` still points at the sentinel (old global wiring), install restores it to the stored upstream (or deletes the key for the SDK default) so non-harness sessions keep working.
3. **Visibility.** `check-harness-deps.sh` reports a `router routing` row as `wired` / `unwired` / `looped`, so a reclaimed router shows up without being asked about. **Not yet updated for per-project wiring:** it still reads the global `~/.claude/settings.json` (so a correctly wired install now reads `unwired`) and reports `router sentinel` / `router worker` as `FAILED (not listening)` whenever no wired session is open — the normal idle state under the on-demand lifecycle.

A first-run self-loop — `ANTHROPIC_BASE_URL` already pointing at the sentinel's own address before any real upstream has ever been recorded — is refused outright (`exit 1`, nothing written) rather than guessed at, since there would be no real upstream to fall back to.

## Install / Uninstall

```bash
# Automatic: install.sh and update.sh both run this, immediately after headroom-setup.sh
bash scripts/setup/router-setup.sh             # install (default, idempotent)
bash scripts/setup/router-setup.sh uninstall   # restore + remove
```

Install resolves the pinned interpreter, writes `router.toml` from the template (never overwriting an existing one), records the discovered upstream on a first run, removes any legacy `launchd`/`systemd` units (`com.sdd.router-sentinel` / `-worker` / `com.sdd.jeff-classifier`, `sdd-router-*.service` / `sdd-jeff-classifier.service`), preflights by starting the router via `router-ctl.sh` under a setup-only session, sending one real request through the sentinel's public port and stopping it again (exiting 1, wiring nothing, if nothing answers), and only then wires `env.ANTHROPIC_BASE_URL` to the sentinel's address in `<project>/.claude/settings.local.json` for each project in `projects.txt` whose `.claude/settings.json` registers `router-session-hook.sh`. Wiring is per project, never global: a session in any other directory never points at a router that is not running. `settings.local.json` is used because `update.sh` rewrites `settings.json` from a template. A project not yet updated to the new template is skipped — run `update.sh` in it, then re-run `router-setup.sh`.

Uninstall removes `ANTHROPIC_BASE_URL` from each project's `settings.local.json` where it points at the sentinel, stops all router processes (`router-ctl.sh stop`), and removes any legacy services. It deliberately leaves `router.toml` on disk: the stored `[router].upstream` value is reused as-is if the router is ever reinstalled, rather than being rediscovered. If you want a fully clean slate including that file, remove `~/.sdd-router/` by hand after uninstalling.

## The Privacy Gate Is a Cost-Safety Feature, Not a DLP Control

The classifier's third question type returns a `gate` probability alongside lane and difficulty. When that probability exceeds `[policy].privacy_threshold` (default `0.80` in the shipped template), the policy's precedence order picks a local model instead of whatever the lane/score lookup would otherwise have chosen — and if no local model is configured (the shipped default, since slice 1 ships no `[local.*]` entries), it returns the conversation's starting model outright, never a cheaper remote (R6.2).

That is the entire mechanism: it only ever changes **which already-authorized model serves the request**. It does not inspect, redact, block, or log any message content — the ledger records a numeric gate probability per decision and nothing else (no message bodies, R7.3/R11). It exists to stop the router's own cost-optimization logic from being the thing that routes a sensitive message somewhere cheaper than the conversation's starting model would have gone; it is not a content-inspection or data-loss-prevention system, and should not be relied on as one. Treat it as a routing safety valve on an optimization, not a security boundary.

## Verifying It Works

```bash
bash scripts/router/router-ctl.sh status                # what is running, which sessions hold it
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:8799/v1/messages \
  -H 'Content-Type: application/json' -d '{}'          # any HTTP answer = front door alive (only while a wired session is open)

bash scripts/setup/check-harness-deps.sh                # router sentinel / router worker / router routing rows
python3 scripts/utils/dashboard.py                       # Router layer: Net Saving, routed/fallback, per-lane/model
tail -5 ~/.sdd-router/ledger.jsonl                       # per-request routing decisions
```

`check-harness-deps.sh` reports health (is the chain wired); the dashboard's Router layer reports whether being wired is worth anything (Net Saving, priced through the same pricing history the other savings layers use). The layer renders dimmed when `~/.sdd-router/stats.json` is absent, which is the uninstalled state, not a failure.

## jeff's API Key Wiring

`router-ctl.sh` reads jeff's generated `JEFF_API_KEYS` from jeff's own env file (`~/.sdd-router/jeff/.jeff-service.env`, written by `jeff-setup.sh`) and exports it into the worker's environment at spawn time under the name `router.toml`'s `[classifier].api_key_env` expects (`JEFF_API_KEY` by default) — no second copy of the secret is written anywhere. This closes the former gap where every classify call 401'd and the router ran permanently in pass-through. `jeff-setup.sh` itself no longer installs a resident service: it preflights one real classification by starting jeff temporarily, then stops it.
