"""Unit tests for scripts/router/stream.py.

Run via `scripts/router/stream.test.sh` (wraps `python3 -m unittest`).

`stream.py` does no I/O of its own (no socket, no HTTP) — same "pure-ish,
inputs as arguments" posture `test_policy.py`/`test_ledger.py` already
exercise. These tests build real Anthropic-shaped multi-frame SSE byte
strings by hand and feed them to `StreamTee.feed()` directly; there is no
stub HTTP server here (unlike `test_classify.py`) because `stream.py`'s own
public surface takes chunks and a `write` callback as plain arguments, never
a socket.
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from stream import StreamTee, UsageResult


def _message_start_frame(input_tokens: int) -> bytes:
    """Build a real Anthropic-shaped `message_start` SSE frame."""
    payload = json.dumps(
        {
            "type": "message_start",
            "message": {"usage": {"input_tokens": input_tokens, "output_tokens": 0}},
        }
    )
    return f"data: {payload}\n\n".encode()


def _message_delta_frame(output_tokens: int) -> bytes:
    """Build a real Anthropic-shaped `message_delta` SSE frame."""
    payload = json.dumps(
        {"type": "message_delta", "delta": {}, "usage": {"output_tokens": output_tokens}}
    )
    return f"data: {payload}\n\n".encode()


def _ping_frame() -> bytes:
    """A real SSE event type Anthropic sends that carries no usage data."""
    return b'data: {"type":"ping"}\n\n'


class _Recorder:
    """Stand-in `write` callback: records every chunk it is handed, verbatim."""

    def __init__(self) -> None:
        self.chunks: list[bytes] = []

    def __call__(self, chunk: bytes) -> None:
        self.chunks.append(chunk)


# ---------------------------------------------------------------------------
# 1. Usage recovered when an SSE line is split mid-payload across chunks
#    (R3.2, R3.3 — the split must not defeat usage harvesting).
# ---------------------------------------------------------------------------


class StreamTeeSplitPayloadRecoversUsageTests(unittest.TestCase):
    # Verifies: specs/model-router/requirements.md#3.2
    # Verifies: specs/model-router/requirements.md#3.3
    def test_split_mid_value_recovers_usage(self) -> None:
        full = _message_start_frame(42) + _message_delta_frame(17)
        # Split inside the JSON *value* "42" — neither a frame nor a line
        # boundary, nor inside a key name (that is the next test).
        marker = b'"input_tokens": 4'
        split_at = full.index(marker) + len(marker)
        self.assertNotEqual(full[split_at - 1 : split_at + 1], b"\n\n")  # sanity: not at a frame edge

        tee = StreamTee(_Recorder())
        tee.feed(full[:split_at])
        tee.feed(full[split_at:])

        result = tee.usage()
        self.assertEqual(result.cost_state, "known")
        assert result.input_tokens is not None  # Optional[int] narrowing before use
        assert result.output_tokens is not None  # Optional[int] narrowing before use
        self.assertEqual(result.input_tokens, 42)
        self.assertEqual(result.output_tokens, 17)

    # Verifies: specs/model-router/requirements.md#3.2
    # Verifies: specs/model-router/requirements.md#3.3
    def test_split_mid_key_recovers_usage(self) -> None:
        full = _message_start_frame(42) + _message_delta_frame(17)
        # Split inside the JSON *key* name "input_tokens" itself.
        marker = b'"input_tok'
        split_at = full.index(marker) + len(marker)

        tee = StreamTee(_Recorder())
        tee.feed(full[:split_at])
        tee.feed(full[split_at:])

        result = tee.usage()
        self.assertEqual(result.cost_state, "known")
        assert result.input_tokens is not None  # Optional[int] narrowing before use
        assert result.output_tokens is not None  # Optional[int] narrowing before use
        self.assertEqual(result.input_tokens, 42)
        self.assertEqual(result.output_tokens, 17)

    # Verifies: specs/model-router/requirements.md#3.2
    # Verifies: specs/model-router/requirements.md#3.3
    def test_split_at_newline_boundary_recovers_usage(self) -> None:
        full = _message_start_frame(42) + _message_delta_frame(17)
        # Edge case: the split point lands exactly on a `\n` character — the
        # first newline, which terminates the `message_start` data line.
        split_at = full.index(b"\n") + 1
        self.assertEqual(full[split_at - 1 : split_at], b"\n")

        tee = StreamTee(_Recorder())
        tee.feed(full[:split_at])
        tee.feed(full[split_at:])

        result = tee.usage()
        self.assertEqual(result.cost_state, "known")
        assert result.input_tokens is not None  # Optional[int] narrowing before use
        assert result.output_tokens is not None  # Optional[int] narrowing before use
        self.assertEqual(result.input_tokens, 42)
        self.assertEqual(result.output_tokens, 17)


# ---------------------------------------------------------------------------
# 2. Chunk sequence out matches in — byte-identical, no buffering/reordering
#    (R3.2, R3.3).
# ---------------------------------------------------------------------------


class StreamTeeChunkSequenceMatchesInputTests(unittest.TestCase):
    # Verifies: specs/model-router/requirements.md#3.2
    # Verifies: specs/model-router/requirements.md#3.3
    def test_write_receives_every_chunk_unmodified_in_order(self) -> None:
        full = _message_start_frame(42) + _message_delta_frame(17)
        midpoint = len(full) // 2
        chunks = [
            full[:midpoint],
            b"",  # an empty chunk is still a chunk — must pass through untouched
            b"this chunk has no data: line in it at all",
            full[midpoint:],
            b"\n",  # trailing stray newline, no payload after it
        ]

        recorder = _Recorder()
        tee = StreamTee(recorder)
        for chunk in chunks:
            tee.feed(chunk)

        # Exact sequence match: proves no re-chunking, no reordering, no
        # dropped/duplicated chunk — not just an equal concatenation.
        self.assertEqual(recorder.chunks, chunks)
        # Byte-identical concatenation out vs. in (R3.2).
        self.assertEqual(b"".join(recorder.chunks), b"".join(chunks))
        # One write() call per feed() call — no buffering of the full
        # response and no splitting a chunk into more than one write (R3.3).
        self.assertEqual(len(recorder.chunks), len(chunks))


# ---------------------------------------------------------------------------
# 3. Missing usage yields explicit unknown, never a fabricated number (R7.6).
# ---------------------------------------------------------------------------


class StreamTeeMissingUsageUnknownTests(unittest.TestCase):
    # Verifies: specs/model-router/requirements.md#7.6
    def test_message_delta_without_message_start_is_unknown(self) -> None:
        tee = StreamTee(_Recorder())
        tee.feed(_message_delta_frame(17))

        result = tee.usage()
        self.assertEqual(result.cost_state, "unknown")
        self.assertIsNone(result.input_tokens)

    # Verifies: specs/model-router/requirements.md#7.6
    def test_neither_event_present_is_unknown(self) -> None:
        tee = StreamTee(_Recorder())
        tee.feed(_ping_frame())
        tee.feed(b": keep-alive\n\n")  # SSE comment line, not a data: line

        result = tee.usage()
        self.assertEqual(result.cost_state, "unknown")
        self.assertIsNone(result.input_tokens)
        self.assertIsNone(result.output_tokens)

    # Verifies: specs/model-router/requirements.md#7.6
    def test_empty_stream_is_unknown(self) -> None:
        tee = StreamTee(_Recorder())

        result = tee.usage()
        self.assertEqual(result, UsageResult(input_tokens=None, output_tokens=None, cost_state="unknown"))

    # Verifies: specs/model-router/requirements.md#7.6
    def test_message_start_without_message_delta_is_still_unknown(self) -> None:
        # Pass 8's ledger decision, locked in here: both fields are required
        # for "known" — one observed event is not enough, even though
        # input_tokens itself is already a real, non-None number.
        tee = StreamTee(_Recorder())
        tee.feed(_message_start_frame(42))

        result = tee.usage()
        self.assertEqual(result.cost_state, "unknown")
        assert result.input_tokens is not None  # Optional[int] narrowing before use
        self.assertEqual(result.input_tokens, 42)
        self.assertIsNone(result.output_tokens)


# ---------------------------------------------------------------------------
# 4. Malformed/truncated JSON in a `data:` line never raises out of feed()
#    (stream.py's own documented invariant).
# ---------------------------------------------------------------------------


class StreamTeeMalformedJsonDoesNotRaiseTests(unittest.TestCase):
    def test_malformed_json_data_line_does_not_raise(self) -> None:
        tee = StreamTee(_Recorder())
        try:
            tee.feed(b"data: {not valid json at all\n\n")
        except Exception as exc:  # noqa: BLE001 - this IS the assertion
            self.fail(f"feed() raised {exc!r} on malformed JSON instead of failing open")

        result = tee.usage()
        self.assertEqual(result.cost_state, "unknown")

    def test_truncated_json_data_line_does_not_raise(self) -> None:
        # A complete *line* (terminated by \n) whose JSON body is truncated —
        # distinct from the split-mid-payload tests above, which eventually
        # deliver a complete, valid line once both chunks have arrived.
        tee = StreamTee(_Recorder())
        try:
            tee.feed(b'data: {"type": "message_start", "message": {\n\n')
        except Exception as exc:  # noqa: BLE001 - this IS the assertion
            self.fail(f"feed() raised {exc!r} on truncated JSON instead of failing open")

        result = tee.usage()
        self.assertEqual(result.cost_state, "unknown")

    def test_malformed_line_still_forwarded_to_write_unmodified(self) -> None:
        # Fail-open for parsing must not mean fail-closed for forwarding:
        # R3.2 holds even when the payload on that line cannot be parsed.
        recorder = _Recorder()
        tee = StreamTee(recorder)
        chunk = b"data: {not valid json at all\n\n"
        tee.feed(chunk)

        self.assertEqual(recorder.chunks, [chunk])


if __name__ == "__main__":
    unittest.main()
