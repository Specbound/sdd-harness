#!/usr/bin/env bash
# sentinel.test.sh — scripts/router/sentinel.py's fail-open front door:
# worker-first with a bounded connect/read timeout, fall-through to upstream
# on connection-refused/hang, non-2xx-from-worker is not a fallback trigger,
# and load_router_settings()'s startup-fatal contract (R4.5, R4.5a).
#
# Thin wrapper around `python3 -m unittest`; the assertions (against real
# stub HTTP servers on ephemeral loopback ports, not a mocked urllib) live in
# test_sentinel.py next to it.
#
# Run: bash scripts/router/sentinel.test.sh

set -uo pipefail

HERE="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

cd "$HERE" && python3 -m unittest test_sentinel -v
exit $?
