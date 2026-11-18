#!/usr/bin/env bash
# policy.test.sh — scripts/router/policy.py's full decision-flowchart branch table.
#
# Thin wrapper around `python3 -m unittest`; the assertions live in
# test_policy.py next to it. Fixtures use fictitious model ids throughout —
# policy.py's own contract is "no model identifier here, every model
# identity comes from catalog" so a passing suite never depended on a real
# id either.
#
# Run: bash scripts/router/policy.test.sh

set -uo pipefail

HERE="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

cd "$HERE" && python3 -m unittest test_policy -v
exit $?
