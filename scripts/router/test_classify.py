"""Unit tests for scripts/router/classify.py.

Run via `scripts/router/classify.test.sh` (wraps `python3 -m unittest`).

The `JeffClassifier` tests below drive a real stub HTTP server
(`http.server.BaseHTTPRequestHandler` + `ThreadingHTTPServer` on an ephemeral
loopback port, started/stopped per test via `setUp`/`addCleanup`) rather than
mocking `urllib` — the behaviours under test (one POST carrying all three
question types, a bounded timeout, and the circuit breaker's suppression of
further *attempts*) are properties of real socket/wall-clock behaviour that a
mocked `urlopen` would assert away rather than prove.

`classify.py`'s own public surface has no factory that chooses between
`JeffClassifier` and `NullClassifier` based on reachability — that selection
(tasks.md 3.2: "unreachable backend selects `NullClassifier`") belongs to a
higher-level module not yet built (config.py/server.py). This suite instead
verifies the two `classify.py`-level contracts that make that selection safe:
`JeffClassifier` reports `reason="unreachable"` when its backend is down
(`test_classify_unreachable_raises_unreachable`), and `NullClassifier` always
raises and never attempts an HTTP call at all
(`test_null_classifier_never_calls_and_always_raises`).
"""

from __future__ import annotations

import json
import os
import sys
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

from classify import (
    ClassifierUnavailable,
    JeffClassifier,
    NullClassifier,
    resolve_base_url,
    should_classify,
)

# ---------------------------------------------------------------------------
# Stub HTTP server — real sockets, no urllib mocking.
# ---------------------------------------------------------------------------


class _RequestRecorder:
    """Thread-safe log of every request the stub handler received."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.requests: list[tuple[str, str, bytes]] = []

    def record(self, method: str, path: str, body: bytes) -> None:
        with self._lock:
            self.requests.append((method, path, body))

    def __len__(self) -> int:
        with self._lock:
            return len(self.requests)


class _StubBehavior:
    """Mutable per-test knob for how the next request(s) get answered."""

    def __init__(self) -> None:
        self.mode = "ok"  # "ok" | "sleep" | "error"
        self.sleep_s = 0.0
        self.status = 200
        self.response: dict[str, object] = {
            "lane": "simple",
            "score": 2,
            "gate_p": 0.1,
            "confidence": 0.9,
        }


class _StubHandler(BaseHTTPRequestHandler):
    # Default HTTP/1.0 behaviour (one request per connection, then close) —
    # deliberate: it sidesteps keep-alive/Content-Length bookkeeping that is
    # irrelevant to what these tests check.

    def do_POST(self) -> None:  # BaseHTTPRequestHandler's own naming convention
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        self.server.recorder.record(self.command, self.path, body)  # type: ignore[attr-defined]

        behavior: _StubBehavior = self.server.behavior  # type: ignore[attr-defined]
        if behavior.mode == "sleep":
            time.sleep(behavior.sleep_s)
        if behavior.mode == "error":
            try:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(b"stub error")
            except OSError:
                pass  # client may already have moved on (timeout path)
            return

        try:
            payload = json.dumps(behavior.response).encode("utf-8")
            self.send_response(behavior.status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(payload)
        except OSError:
            pass  # client already disconnected (e.g. after its own timeout)

    def log_message(self, format_str: str, *args: object) -> None:
        pass  # silence BaseHTTPRequestHandler's default stderr access log


class _StubServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self,
        server_address: tuple[str, int],
        handler_cls: type[BaseHTTPRequestHandler],
        recorder: _RequestRecorder,
        behavior: _StubBehavior,
    ) -> None:
        self.recorder = recorder
        self.behavior = behavior
        super().__init__(server_address, handler_cls)

    def handle_error(self, request: object, client_address: object) -> None:
        # Expected noise: the timeout test's client gives up and closes its
        # socket before the deliberately slow handler finishes sleeping and
        # tries to write a response. Suppress rather than spam stderr on
        # every test run.
        pass


class _StubServerTestCase(unittest.TestCase):
    """Base class wiring up/tearing down one stub server per test."""

    def setUp(self) -> None:
        self.behavior = _StubBehavior()
        self.recorder = _RequestRecorder()
        self.server = _StubServer(
            ("127.0.0.1", 0), _StubHandler, self.recorder, self.behavior
        )
        self.server_thread = threading.Thread(
            target=self.server.serve_forever,
            kwargs={"poll_interval": 0.05},  # default 0.5s makes shutdown() slow
            daemon=True,
        )
        self.server_thread.start()
        self._server_stopped = False
        self.addCleanup(self._stop_server)
        self.base_url = f"http://127.0.0.1:{self.server.server_port}"

    def _stop_server(self) -> None:
        if self._server_stopped:
            return
        self._server_stopped = True
        try:
            self.server.shutdown()
        except OSError:
            pass
        try:
            self.server.server_close()
        except OSError:
            pass
        self.server_thread.join(timeout=5)

    def make_classifier(self, **overrides: object) -> JeffClassifier:
        kwargs: dict[str, object] = {
            "base_url": self.base_url,
            "api_key_env": "ROUTER_TEST_API_KEY_UNSET",
            "timeout_ms": 2000,
            "circuit_open_s": 60,
            "scale_max": 10,
            "lanes": ("chitchat", "simple", "code"),
        }
        kwargs.update(overrides)
        return JeffClassifier(**kwargs)  # type: ignore[arg-type]


# ---------------------------------------------------------------------------
# 1. Single call carries all three question types (R2.2).
# ---------------------------------------------------------------------------


class ClassifySinglePostTests(_StubServerTestCase):
    # Verifies: specs/model-router/requirements.md#2.2
    def test_classify_sends_single_post_with_full_payload(self) -> None:
        classifier = self.make_classifier()

        decision = classifier.classify("book me a flight to Austin")

        self.assertEqual(len(self.recorder), 1)  # one call, not three
        method, path, body = self.recorder.requests[0]
        self.assertEqual(method, "POST")
        self.assertEqual(path, "/v1/systemone")

        payload = json.loads(body)
        self.assertEqual(payload["text"], "book me a flight to Austin")
        self.assertEqual(payload["lanes"], ["chitchat", "simple", "code"])
        self.assertEqual(payload["scale_max"], 10)

        self.assertEqual(decision.lane, "simple")
        self.assertEqual(decision.score, 2)
        self.assertAlmostEqual(decision.gate_p, 0.1)
        self.assertAlmostEqual(decision.confidence, 0.9)
        self.assertGreaterEqual(decision.latency_ms, 0)


# ---------------------------------------------------------------------------
# 2. Timeout yields pass-through within budget (R2.4, R4.3).
# ---------------------------------------------------------------------------


class ClassifyTimeoutTests(_StubServerTestCase):
    # Verifies: specs/model-router/requirements.md#2.4
    # Verifies: specs/model-router/requirements.md#4.3
    def test_classify_timeout_raises_within_budget(self) -> None:
        self.behavior.mode = "sleep"
        self.behavior.sleep_s = 2.0
        classifier = self.make_classifier(timeout_ms=200)

        started = time.monotonic()
        with self.assertRaises(ClassifierUnavailable) as ctx:
            classifier.classify("how do I reverse a linked list in place")
        elapsed = time.monotonic() - started

        self.assertEqual(ctx.exception.reason, "timeout")
        # Budget is 200ms; the stub sleeps for 2000ms. Assert elapsed stays
        # well under the stub's sleep (not just "eventually raised") — this
        # is what proves classify() abandoned the call instead of waiting
        # for it. 1.0s gives ~5x the budget of scheduling slack while still
        # being 2x tighter than the stub's full sleep.
        self.assertLess(elapsed, 1.0)


# ---------------------------------------------------------------------------
# 3. Circuit opens after three failures and suppresses further calls
#    (design.md circuit breaker; closest numbered ref is R4.3's "abandon
#    the decision" — suppression is that guarantee extended across calls).
# ---------------------------------------------------------------------------


class ClassifyCircuitBreakerTests(_StubServerTestCase):
    # Verifies: specs/model-router/requirements.md#4.3
    def test_circuit_opens_after_three_failures_and_suppresses_calls(self) -> None:
        self.behavior.mode = "error"
        classifier = self.make_classifier(circuit_open_s=60)

        for _ in range(3):
            with self.assertRaises(ClassifierUnavailable) as ctx:
                classifier.classify("tell me about the weather")
            self.assertEqual(ctx.exception.reason, "http_error")
        self.assertEqual(len(self.recorder), 3)

        # Circuit is now open: the next call must be suppressed before any
        # network attempt — the stub must receive ZERO further requests.
        with self.assertRaises(ClassifierUnavailable) as ctx:
            classifier.classify("tell me about the weather again")
        self.assertEqual(ctx.exception.reason, "circuit_open")
        self.assertEqual(len(self.recorder), 3)  # unchanged - no new attempt

        # A second suppressed call, to be doubly sure nothing leaks through.
        with self.assertRaises(ClassifierUnavailable) as ctx:
            classifier.classify("and one more time")
        self.assertEqual(ctx.exception.reason, "circuit_open")
        self.assertEqual(len(self.recorder), 3)


# ---------------------------------------------------------------------------
# 4. Unreachable backend (JeffClassifier's own contract) and NullClassifier
#    (R2.5: unavailable backend starts in pass-through mode).
# ---------------------------------------------------------------------------


class ClassifyUnreachableTests(_StubServerTestCase):
    # Verifies: specs/model-router/requirements.md#2.5
    def test_classify_unreachable_raises_unreachable(self) -> None:
        port = self.server.server_port
        self._stop_server()  # stub is now a closed loopback port

        classifier = JeffClassifier(
            base_url=f"http://127.0.0.1:{port}",
            api_key_env="ROUTER_TEST_API_KEY_UNSET",
            timeout_ms=2000,
            circuit_open_s=60,
            scale_max=10,
            lanes=(),
        )

        with self.assertRaises(ClassifierUnavailable) as ctx:
            classifier.classify("anything")
        self.assertEqual(ctx.exception.reason, "unreachable")


class NullClassifierTests(unittest.TestCase):
    # Verifies: specs/model-router/requirements.md#2.5
    def test_null_classifier_never_calls_and_always_raises(self) -> None:
        classifier = NullClassifier()

        with mock.patch("urllib.request.urlopen") as mocked_urlopen:
            for _ in range(3):
                with self.assertRaises(ClassifierUnavailable) as ctx:
                    classifier.classify("anything at all")
                self.assertEqual(ctx.exception.reason, "no_backend")
            mocked_urlopen.assert_not_called()


# ---------------------------------------------------------------------------
# 5. should_classify() — pure predicate, no server needed.
# ---------------------------------------------------------------------------


class ShouldClassifyTests(unittest.TestCase):
    # Verifies: specs/model-router/requirements.md#4.3
    # (closest numbered ref among task 3.2's set: skipping entirely is the
    # strongest form of "never adds latency" for a tool-loop continuation.
    # should_classify() itself is a pure function; the "zero calls" half of
    # the guarantee is enforced by its caller, not yet built, so it is
    # tested here only as the boolean contract this module owns.)
    def test_empty_text_is_not_classifiable(self) -> None:
        self.assertFalse(should_classify(""))

    def test_whitespace_only_text_is_not_classifiable(self) -> None:
        self.assertFalse(should_classify("   \n\t  "))

    def test_real_user_text_is_classifiable(self) -> None:
        self.assertTrue(should_classify("hello there"))

    def test_text_with_surrounding_whitespace_is_classifiable(self) -> None:
        self.assertTrue(should_classify("  hello there  "))


# ---------------------------------------------------------------------------
# 6. resolve_base_url() — pure unit tests, no server needed.
# ---------------------------------------------------------------------------


class ResolveBaseUrlTests(unittest.TestCase):
    # Verifies: specs/model-router/requirements.md#2.3
    @mock.patch.dict(os.environ, {"TYPESAFE_BASE_URL": "http://127.0.0.1:9999"})
    def test_env_override_wins_over_configured(self) -> None:
        self.assertEqual(
            resolve_base_url("http://127.0.0.1:8080"), "http://127.0.0.1:9999"
        )

    @mock.patch.dict(os.environ, {}, clear=False)
    def test_falls_back_to_configured_when_env_unset(self) -> None:
        os.environ.pop("TYPESAFE_BASE_URL", None)
        self.assertEqual(
            resolve_base_url("http://127.0.0.1:8080"), "http://127.0.0.1:8080"
        )


if __name__ == "__main__":
    unittest.main()
