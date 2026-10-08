#!/usr/bin/env bash
# ledger.test.sh — scripts/router/ledger.py's append-only log + atomic
# stats.json rollup + escalation detector.
#
# Thin wrapper around `python3 -m unittest`; the assertions live in
# test_ledger.py next to it. Every test runs against a
# tempfile.TemporaryDirectory(), never ~/.sdd-router/.
#
# Run: bash scripts/router/ledger.test.sh

set -uo pipefail

HERE="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

cd "$HERE" && python3 -m unittest test_ledger -v
exit $?
