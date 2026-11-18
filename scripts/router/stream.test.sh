#!/usr/bin/env bash
# stream.test.sh — scripts/router/stream.py's verbatim SSE forwarding +
# usage extraction (StreamTee).
#
# Thin wrapper around `python3 -m unittest`; the assertions live in
# test_stream.py next to it. No socket/stub server involved — stream.py
# takes chunks and a write callback directly, so tests build real SSE byte
# strings and feed them straight in.
#
# Run: bash scripts/router/stream.test.sh

set -uo pipefail

HERE="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

cd "$HERE" && python3 -m unittest test_stream -v
exit $?
