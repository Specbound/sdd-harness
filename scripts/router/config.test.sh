#!/usr/bin/env bash
# config.test.sh — scripts/router/config.py's discovered catalog + Ladder.
#
# Thin wrapper around `python3 -m unittest`; the assertions live in
# test_config.py next to it. Fixtures use fictitious model ids throughout —
# config.py's own contract is "no model identifier or price literal
# anywhere in this file" (R5.1), so a passing suite never depended on a
# real id either.
#
# Run: bash scripts/router/config.test.sh

set -uo pipefail

HERE="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

cd "$HERE" && python3 -m unittest test_config -v
exit $?
