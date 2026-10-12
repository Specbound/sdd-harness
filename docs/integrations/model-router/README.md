# Model Router — Per-Message Cost Routing

> Detailed reference for the local, fail-open proxy that routes each `claude` request to the cheapest model that can do that message's work.

## What It Is

A stdlib-only Python proxy that sits in front of every Claude Code request. A local, non-generative classifier (`jeff`) scores each message for lane (what kind of work), difficulty, and a privacy signal; a pure policy function turns that score into a model selection; the proxy rewrites the request's `model` field before forwarding. When anything in that chain is unavailable — the classifier, the policy, the config — the request is forwarded unmodified on the model the conversation started with. Routing is a pure cost optimization: it never changes prompt content, never blocks a request, and `claude` never breaks because a routing component failed (R4).

## Architecture — The Proxy Chain

The router is two independently-supervised processes, not one:

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

Both are registered as separate, independently OS-supervised services (`launchd` `KeepAlive`/`ThrottleInterval` on macOS, `systemd` `Restart=always`/`RestartSec` on Linux) — this is the requirement 4.5a watchdog split. Killing the worker leaves the sentinel serving pass-through immediately, with no restart wait; killing the sentinel itself gets it restarted by the service manager. A single-process design cannot satisfy this: an in-process `try`/`except` guard cannot protect against the process itself disappearing.

## Pinned Python Interpreter (R10.8)

The router's config file (`router.toml`) is parsed with the stdlib `tomllib` module, which does not exist before Python 3.11. `router-setup.sh` resolves an interpreter satisfying `>=3.11` via `uv python find`, provisioning `3.12` with `uv python install` if nothing qualifying is found, and writes that interpreter's **absolute path** into every generated service unit — never a bare `python3`. This matters because the system `python3` on a stock Mac (`/usr/bin/python3`) is 3.9.6, and `launchd`/`systemd` run services with a minimal `PATH` that would resolve that stale system interpreter first if the service definition just said `python3`.

## The Reclaim Hazard and Its Three Mitigations

`headroom init --global --memory claude` reclaims `ANTHROPIC_BASE_URL` every time it runs — which `update.sh` does on every update. Left unchecked, this silently points Claude Code back at headroom's proxy and un-routes the router: everything keeps working, the request just stops being classified and never gets cheaper. This class of bug — invisible because nothing breaks — is why `router-setup.sh` applies three required mitigations together, not any one alone:

1. **Ordering.** `router-setup.sh` runs immediately *after* `headroom-setup.sh` in both `install.sh` and `update.sh`, so the router's own write to `ANTHROPIC_BASE_URL` is always the last word on a given run.
2. **Re-assertive repair.** Every run of `router-setup.sh` re-checks whether the global value still points at the sentinel; if headroom (or anything else) reclaimed it, the run repairs it back without re-discovering (and overwriting) the `[router].upstream` value already stored in `router.toml` — that value is written exactly once, on the first successful install, and never touched again.
3. **Visibility.** `check-harness-deps.sh` reports a `router routing` row as `wired` / `unwired` / `looped`, so a reclaimed router shows up without being asked about, instead of silently costing nothing while looking installed.

A first-run self-loop — `ANTHROPIC_BASE_URL` already pointing at the sentinel's own address before any real upstream has ever been recorded — is refused outright (`exit 1`, nothing written) rather than guessed at, since there would be no real upstream to fall back to.

## Install / Uninstall

```bash
# Automatic: install.sh and update.sh both run this, immediately after headroom-setup.sh
bash scripts/setup/router-setup.sh             # install (default, idempotent)
bash scripts/setup/router-setup.sh uninstall   # restore + remove
```

Install resolves the pinned interpreter, writes `router.toml` from the template (never overwriting an existing one), installs and starts both services, preflights by sending one real request through the sentinel's public port (exiting 1 without touching `~/.claude/settings.json` if nothing answers), and only then wires `env.ANTHROPIC_BASE_URL` in `~/.claude/settings.json` to the sentinel's address.

Uninstall restores `ANTHROPIC_BASE_URL` to whatever upstream was discovered at install time — removing the key entirely if the router was installed when no upstream had ever been set (the SDK default), or writing back the real discovered value (e.g. headroom's proxy address) otherwise — and removes both services. It deliberately leaves `router.toml` on disk: the stored `[router].upstream` value is reused as-is if the router is ever reinstalled, rather than being rediscovered. If you want a fully clean slate including that file, remove `~/.sdd-router/` by hand after uninstalling.

## The Privacy Gate Is a Cost-Safety Feature, Not a DLP Control

The classifier's third question type returns a `gate` probability alongside lane and difficulty. When that probability exceeds `[policy].privacy_threshold` (default `0.80` in the shipped template), the policy's precedence order picks a local model instead of whatever the lane/score lookup would otherwise have chosen — and if no local model is configured (the shipped default, since slice 1 ships no `[local.*]` entries), it returns the conversation's starting model outright, never a cheaper remote (R6.2).

That is the entire mechanism: it only ever changes **which already-authorized model serves the request**. It does not inspect, redact, block, or log any message content — the ledger records a numeric gate probability per decision and nothing else (no message bodies, R7.3/R11). It exists to stop the router's own cost-optimization logic from being the thing that routes a sensitive message somewhere cheaper than the conversation's starting model would have gone; it is not a content-inspection or data-loss-prevention system, and should not be relied on as one. Treat it as a routing safety valve on an optimization, not a security boundary.

## Verifying It Works

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:8799/v1/messages \
  -H 'Content-Type: application/json' -d '{}'          # any HTTP answer = front door alive

bash scripts/setup/check-harness-deps.sh                # router sentinel / router worker / router routing rows
python3 scripts/utils/dashboard.py                       # Router layer: Net Saving, routed/fallback, per-lane/model
tail -5 ~/.sdd-router/ledger.jsonl                       # per-request routing decisions
```

`check-harness-deps.sh` reports health (is the chain wired); the dashboard's Router layer reports whether being wired is worth anything (Net Saving, priced through the same pricing history the other savings layers use). The layer renders dimmed when `~/.sdd-router/stats.json` is absent, which is the uninstalled state, not a failure.

## Known Gap

Nothing currently wires jeff's generated `JEFF_API_KEYS` secret into the worker service's environment under the name `router.toml`'s `[classifier].api_key_env` expects. Until that wiring lands, every classify call 401s, the circuit breaker opens, and the router runs permanently (but silently, fail-open) in pass-through mode — `claude` keeps working, but no cost savings happen. See `scripts/setup/router-setup.sh`'s header comment for the recommended fix.
