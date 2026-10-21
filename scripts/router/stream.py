"""scripts/router/stream.py — verbatim SSE forwarding with usage extraction.

`StreamTee` sits on the response path between upstream (Anthropic) and the
client. Its one job: forward every byte downstream immediately and
unmodified (R3.2, R3.3) while separately harvesting the two numbers the
ledger needs — `input_tokens` and `output_tokens` — without ever buffering
the full response or pattern-matching over text (R8.6, repo-wide regex ban).

Anthropic's streaming wire format is SSE. Confirmed against the vendored
`anthropic` Python SDK's generated types in this repo's `.venv-tools`
(`anthropic/types/raw_message_start_event.py`,
`anthropic/types/raw_message_delta_event.py`, `message_delta_usage.py`,
`usage.py` — generated from Anthropic's own OpenAPI spec, not guessed):

- `message_start`'s `data:` payload is `{"type": "message_start", "message":
  {..., "usage": {"input_tokens": N, "output_tokens": N, ...}}}` —
  `input_tokens` lives at `message.usage.input_tokens`.
- `message_delta`'s `data:` payload is `{"type": "message_delta", "delta":
  {...}, "usage": {"output_tokens": N, ...}}` — `output_tokens` is top-level
  under the event, not nested under `message`. `MessageDeltaUsage.output_tokens`
  is documented as *cumulative* ("The cumulative number of output tokens
  which were used"), so the last `message_delta` seen before the stream ends
  holds the final figure — later values simply overwrite earlier ones here,
  never summed.

Every real Anthropic SSE `data:` payload carries its own `"type"` field
(mirroring the `event:` line), so usage extraction only needs to inspect the
parsed JSON — it never needs to track the separate `event:` SSE field.

This module does no I/O of its own (no socket, no HTTP) — same "pure-ish,
inputs as arguments" posture as `policy.py`. Chunks and a write sink arrive
as arguments/callbacks; a real socket is wired in by the caller (task 7's
`server.py`).
"""

from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import dataclass

# Mirrors ledger.py's CallRecord.cost_state string values exactly (R7.6).
# Not imported from ledger.py — Rule of Three, no coupling yet.
_COST_KNOWN = "known"
_COST_UNKNOWN = "unknown"

_DATA_FIELD = b"data:"


@dataclass(frozen=True)
class UsageResult:
    """Usage harvested from a stream, as of whenever `.usage()` is called.

    `input_tokens`/`output_tokens` are `None` until their event has actually
    been observed — never a guessed `0`. `cost_state` is `"known"` only once
    both have been observed; otherwise `"unknown"` (R7.6 — never estimate).
    """

    input_tokens: int | None
    output_tokens: int | None
    cost_state: str


class StreamTee:
    """Forwards SSE bytes verbatim downstream while harvesting token usage.

    Preconditions: `write` accepts raw bytes and performs no buffering of
    its own that would violate R3.3.
    Postconditions: every byte passed to `feed()` has been passed to `write`
    before `feed()` returns — no chunk is ever held back.
    Invariant: `feed()` never raises on malformed or partial SSE input;
    usage extraction is best-effort and fails open to `"unknown"`.
    """

    def __init__(self, write: Callable[[bytes], None]) -> None:
        self._write = write
        self._buffer = b""
        self._input_tokens: int | None = None
        self._output_tokens: int | None = None

    def feed(self, chunk: bytes) -> None:
        """Write `chunk` downstream immediately, then parse complete lines.

        R3.2/R3.3: the write happens first and unconditionally, before any
        parsing is attempted — a chunk that fails to parse (or splits a
        `data:` payload mid-line) is still forwarded in full.
        """
        self._write(chunk)
        self._buffer += chunk
        while b"\n" in self._buffer:
            line, self._buffer = self._buffer.split(b"\n", 1)
            self._parse_line(line.rstrip(b"\r"))

    def _parse_line(self, line: bytes) -> None:
        """Parse one complete SSE line; never a partial one.

        Only `data:` lines carry Anthropic event payloads. Everything else
        (`event:`, `id:`, blank separator lines, SSE comments) is structural
        noise this tee does not need, since every real payload's own `type`
        field already names the event.
        """
        if not line.startswith(_DATA_FIELD):
            return
        payload = line[len(_DATA_FIELD) :].strip()
        if not payload:
            return
        try:
            obj = json.loads(payload)
        except json.JSONDecodeError:
            # Malformed/unexpected payload — best-effort harvesting fails
            # open to "unknown" rather than guessing at a partial parse.
            return
        event_type = obj.get("type")
        if event_type == "message_start":
            self._harvest_input_tokens(obj)
        elif event_type == "message_delta":
            self._harvest_output_tokens(obj)

    def _harvest_input_tokens(self, obj: dict) -> None:
        message = obj.get("message")
        if not isinstance(message, dict):
            return
        usage = message.get("usage")
        if not isinstance(usage, dict):
            return
        input_tokens = usage.get("input_tokens")
        if input_tokens is not None:
            self._input_tokens = input_tokens

    def _harvest_output_tokens(self, obj: dict) -> None:
        usage = obj.get("usage")
        if not isinstance(usage, dict):
            return
        output_tokens = usage.get("output_tokens")
        if output_tokens is not None:
            # Cumulative per Anthropic's MessageDeltaUsage — last one wins.
            self._output_tokens = output_tokens

    def usage(self) -> UsageResult:
        """Return usage harvested so far. Safe to call mid-stream or after."""
        if self._input_tokens is None or self._output_tokens is None:
            return UsageResult(
                input_tokens=self._input_tokens,
                output_tokens=self._output_tokens,
                cost_state=_COST_UNKNOWN,
            )
        return UsageResult(
            input_tokens=self._input_tokens,
            output_tokens=self._output_tokens,
            cost_state=_COST_KNOWN,
        )
