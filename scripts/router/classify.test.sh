#!/usr/bin/env bash
# classify.test.sh — scripts/router/classify.py's wire contract: single POST,
# bounded timeout, circuit breaker suppression, NullClassifier, should_classify.
#
# Thin wrapper around `python3 -m unittest`; the assertions (against a real
# stub HTTP server, not a mocked urllib) live in test_classify.py next to it.
#
# Run: bash scripts/router/classify.test.sh

set -uo pipefail

HERE="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

cd "$HERE" && python3 -m unittest test_classify -v
exit $?
