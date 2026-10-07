#!/usr/bin/env bash
# server.test.sh — scripts/router/server.py's fault-injection matrix: every
# R4.1 fail-open class, the R5.10 retry-on-rejection path, R4.4's "no new
# non-2xx" invariant, and R4.2's baseline-recoverable-from-the-ledger check
# (task 7.2).
#
# Thin wrapper around `python3 -m unittest`; the assertions (against a real
# stub `http.server.ThreadingHTTPServer` upstream on an ephemeral loopback
# port, not a mocked urllib) live in test_server.py next to it.
#
# Run: bash scripts/router/server.test.sh

set -uo pipefail

HERE="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

cd "$HERE" && python3 -m unittest test_server -v
exit $?
