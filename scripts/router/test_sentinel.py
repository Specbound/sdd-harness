"""Unit tests for scripts/router/sentinel.py.

Run via `scripts/router/sentinel.test.sh` (wraps `python3 -m unittest`).

Mirrors `test_classify.py`'s posture: real stub `http.server.ThreadingHTTPServer`
instances on ephemeral loopback ports, started/stopped per test via `setUp`/
`addCleanup`, never a mocked `urllib`. This module needs two stub backends at
once (a stub "worker" and a stub "upstream") plus the real `sentinel.py` server
itself, constructed via `build_server(...)` — the seam that module's own
docstring names for exactly this purpose.

Call on required-coverage item 3 ("worker OOM-kill"): from a TCP client's
perspective, a cleanly-shut-down listening socket and an OOM-killed process's
socket are both observed as connection-refused on the next connect attempt —
there is no distinct OS-level signal the sentinel's connection code could
branch on even if it wanted to. `test_worker_killed_mid_session_falls_through_
to_upstream_and_sentinel_survives` below (via `_stop`'s `shutdown()` +
`server_close()`) is therefore treated as covering both "worker exit" and
"worker OOM-kill" from `sentinel.py`'s own vantage point; no separate OOM test
is written. The genuinely distinct code path — a worker that accepts the
connection but never answers — is `SentinelWorkerHangTests` below.
"""

from __future__ import annotations

import sys
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parent))

from classify import NullClassifier
from config import Catalog, Ladder, RouterConfig
from ledger import Ledger
from sentinel import UpstreamNotConfigured, build_server, load_router_settings
from server import build_server as build_router_worker

# ---------------------------------------------------------------------------
# Stub backend — real sockets, no urllib mocking. One class plays both the
# "worker" and "upstream" role across tests, distinguished by `role` so a
# response body alone proves which backend actually answered a request.
# ---------------------------------------------------------------------------


class _RequestRecorder:
    """Thread-safe count of every request a stub backend received."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._count = 0

    def record(self) -> None:
        with self._lock:
            self._count += 1

    def __len__(self) -> int:
        with self._lock:
            return self._count


class _StubBehavior:
    """Mutable per-test knob for how a stub backend answers the next request."""

    def __init__(self, role: str) -> None:
        self.role = role
        self.mode = "ok"  # "ok" | "hang"
        self.hang_s = 0.0
        self.status = 200
        self.body = f"FROM-{role.upper()}".encode()


class _StubHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        self._respond()

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)
        self._respond()

    def _respond(self) -> None:
        self.server.recorder.record()  # type: ignore[attr-defined]
        behavior: _StubBehavior = self.server.behavior  # type: ignore[attr-defined]
        if behavior.mode == "hang":
            time.sleep(behavior.hang_s)
        try:
            self.send_response(behavior.status)
            self.send_header("Content-Type", "text/plain")
            self.send_header("X-Stub-Role", behavior.role)
            self.send_header("Content-Length", str(len(behavior.body)))
            self.end_headers()
            self.wfile.write(behavior.body)
        except OSError:
            pass  # client (sentinel, or its own client) already moved on

    def log_message(self, format: str, *args: object) -> None:
        pass  # silence BaseHTTPRequestHandler's default stderr access log

    def handle_error(self, request: object, client_address: object) -> None:
        # Expected noise: the hang test's client (sentinel) times out and
        # closes its connection before the deliberately slow handler finishes
        # sleeping and tries to write a response. Suppress rather than spam
        # stderr on every test run.
        pass


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


def _get(port: int, timeout: float = 5.0) -> tuple[int, bytes]:
    """GET `/v1/test` from a server bound to `port` on loopback.

    `HTTPError` is response-shaped (status/headers/read()) for a non-2xx
    reply — caught here rather than letting it propagate, same as
    `sentinel.py`'s own `_open()` helper treats "the peer answered" as a
    non-exceptional outcome.
    """
    request = Request(f"http://127.0.0.1:{port}/v1/test")
    try:
        response = urlopen(request, timeout=timeout)
    except HTTPError as exc:
        response = exc
    status = response.status
    # `addinfourl.status` (base of both `urlopen`'s return type and `HTTPError`) is
    # typed `int | None` in typeshed, but a real HTTP response always carries a real
    # status code by the time it reaches here — narrow per tech.md's convention.
    assert status is not None
    return status, response.read()


# ---------------------------------------------------------------------------
# 1 & 2. Worker killed mid-session: in-flight path proven healthy first, then
#    a NEW request falls through to upstream, and the sentinel itself keeps
#    serving a THIRD request afterward (R4.5, R4.5a).
# 3. Worker OOM-kill: see module docstring — same code path as "worker
#    exit" below, not a separate test.
# 5. Non-2xx from worker is forwarded verbatim, never treated as a fallback
#    trigger (sentinel.py's own documented behavior).
# ---------------------------------------------------------------------------


class SentinelFallbackTests(unittest.TestCase):
    """Real stub worker + real stub upstream + a real `build_server(...)` sentinel."""

    def setUp(self) -> None:
        self.worker_recorder = _RequestRecorder()
        self.worker_behavior = _StubBehavior("worker")
        self.worker_server = _StubServer(
            ("127.0.0.1", 0), _StubHandler, self.worker_recorder, self.worker_behavior
        )
        self.worker_thread = self._start(self.worker_server)

        self.upstream_recorder = _RequestRecorder()
        self.upstream_behavior = _StubBehavior("upstream")
        self.upstream_server = _StubServer(
            ("127.0.0.1", 0), _StubHandler, self.upstream_recorder, self.upstream_behavior
        )
        self._start(self.upstream_server)
        upstream_url = f"http://127.0.0.1:{self.upstream_server.server_port}"

        self.sentinel = build_server(
            host="127.0.0.1",
            port=0,
            upstream=upstream_url,
            worker_host="127.0.0.1",
            worker_port=self.worker_server.server_port,
            worker_timeout_s=0.150,
        )
        self.sentinel_thread = self._start(self.sentinel)
        self.sentinel_port = self.sentinel.server_port

    def _start(self, server: ThreadingHTTPServer) -> threading.Thread:
        thread = threading.Thread(
            target=server.serve_forever,
            kwargs={"poll_interval": 0.02},
            daemon=True,
        )
        thread.start()
        self.addCleanup(self._stop, server, thread)
        return thread

    def _stop(self, server: ThreadingHTTPServer, thread: threading.Thread) -> None:
        try:
            server.shutdown()
        except OSError:
            pass
        try:
            server.server_close()
        except OSError:
            pass
        thread.join(timeout=5)

    # Verifies: specs/model-router/requirements.md#4.5
    # Verifies: specs/model-router/requirements.md#4.5a
    def test_worker_killed_mid_session_falls_through_to_upstream_and_sentinel_survives(
        self,
    ) -> None:
        # Request 1: worker is healthy -> served by the worker.
        status, body = _get(self.sentinel_port)
        self.assertEqual(status, 200)
        self.assertEqual(body, b"FROM-WORKER")
        self.assertEqual(len(self.worker_recorder), 1)
        self.assertEqual(len(self.upstream_recorder), 0)

        # Kill the worker mid-session: shut its listening socket down so the
        # port refuses new connections, simulating a crashed/OOM-killed
        # process (see module docstring on item 3).
        self._stop(self.worker_server, self.worker_thread)

        # Request 2 (new, post-kill): must fall through to upstream, bounded
        # by worker_timeout_s (0.150s) rather than hanging on a dead worker.
        started = time.monotonic()
        status, body = _get(self.sentinel_port)
        elapsed = time.monotonic() - started
        self.assertEqual(status, 200)
        self.assertEqual(body, b"FROM-UPSTREAM")
        # Generous bound (~6.7x the 0.150s connect budget) to absorb
        # scheduling jitter without making the suite flaky.
        self.assertLess(elapsed, 1.0)

        # Request 3: the sentinel's own server/thread is still alive and
        # able to serve again — the worker's death did not take the
        # sentinel process down with it.
        self.assertTrue(self.sentinel_thread.is_alive())
        status, body = _get(self.sentinel_port)
        self.assertEqual(status, 200)
        self.assertEqual(body, b"FROM-UPSTREAM")
        self.assertEqual(len(self.upstream_recorder), 2)

    # Verifies: specs/model-router/requirements.md#4.5a
    def test_worker_non_2xx_is_forwarded_verbatim_not_treated_as_fallback_trigger(
        self,
    ) -> None:
        self.worker_behavior.status = 429
        self.worker_behavior.body = b"RATE-LIMITED"

        status, body = _get(self.sentinel_port)

        self.assertEqual(status, 429)
        self.assertEqual(body, b"RATE-LIMITED")
        self.assertEqual(len(self.worker_recorder), 1)
        self.assertEqual(len(self.upstream_recorder), 0)  # never fell through


# ---------------------------------------------------------------------------
# Task 7.3, case 2: confirm the SAME fallback mechanism
# `test_worker_killed_mid_session_falls_through_to_upstream_and_sentinel_
# survives` above already proves (R4.5, R4.5a) still holds when the thing
# behind the worker port is a REAL scripts/router/server.py `build_server()`
# instance — task 6.2's own test used a generic stub as the "worker", never
# a real router process. From the sentinel's point of view this substitution
# is mechanical (it only ever sees an HTTP status/headers/body, same as any
# other worker), so this is exactly one dedicated test, not a duplicate of
# the mechanism coverage above: a real router worker, with its own real
# backing stub upstream, behind a real sentinel with its own separate
# fallback stub upstream.
# ---------------------------------------------------------------------------
class SentinelWithRealRouterWorkerTests(unittest.TestCase):
    """Real `server.py` worker (not a generic stub) behind a real sentinel."""

    def setUp(self) -> None:
        # The real router worker's OWN backing upstream.
        self.worker_upstream_recorder = _RequestRecorder()
        self.worker_upstream_behavior = _StubBehavior("worker-upstream")
        self.worker_upstream_server = _StubServer(
            ("127.0.0.1", 0),
            _StubHandler,
            self.worker_upstream_recorder,
            self.worker_upstream_behavior,
        )
        self._start(self.worker_upstream_server)
        worker_upstream_url = f"http://127.0.0.1:{self.worker_upstream_server.server_port}"

        # Minimal real Catalog/RouterConfig: the GET to /v1/test below has
        # no body, so `_parse_body` returns None and server.py's
        # `_forward_raw` short-circuit is what actually runs — classifier/
        # policy/ladder are never reached, but `catalog.policy.upstream`
        # still has to be a real, valid URL (`_upstream_url()` asserts it).
        ladder = Ladder(groups=[], canonical=[], rung_of={})
        policy = RouterConfig(
            schema_version=1,
            port=None,
            upstream=worker_upstream_url,
            classifier={},
            thresholds={},
            escalation_window_s=120,
            max_tiers_above_baseline=3,
            tier_families=[],
            lanes={},
            context_window_default=200_000,
            context_window_overrides={},
            overrides={},
            rejected_overrides={},
            local={},
        )
        catalog = Catalog(
            pass_through=False, cause=None, ladder=ladder, policy=policy, rejected_models={}
        )

        self._tmp = tempfile.TemporaryDirectory()
        tmp_path = Path(self._tmp.name)
        self.addCleanup(self._tmp.cleanup)
        ledger = Ledger(ledger_path=tmp_path / "ledger.jsonl", stats_path=tmp_path / "stats.json")

        self.worker_server = build_router_worker(
            host="127.0.0.1",
            port=0,
            catalog=catalog,
            classifier=NullClassifier(),
            ledger=ledger,
        )
        self.worker_thread = self._start(self.worker_server)

        # The sentinel's OWN direct fallback upstream — deliberately a
        # *different* stub/port than the worker's own backing upstream, so
        # a response body alone proves which path actually served a
        # request.
        self.sentinel_upstream_recorder = _RequestRecorder()
        self.sentinel_upstream_behavior = _StubBehavior("sentinel-upstream")
        self.sentinel_upstream_server = _StubServer(
            ("127.0.0.1", 0),
            _StubHandler,
            self.sentinel_upstream_recorder,
            self.sentinel_upstream_behavior,
        )
        self._start(self.sentinel_upstream_server)
        sentinel_upstream_url = f"http://127.0.0.1:{self.sentinel_upstream_server.server_port}"

        self.sentinel = build_server(
            host="127.0.0.1",
            port=0,
            upstream=sentinel_upstream_url,
            worker_host="127.0.0.1",
            worker_port=self.worker_server.server_port,
            worker_timeout_s=0.150,
        )
        self.sentinel_thread = self._start(self.sentinel)
        self.sentinel_port = self.sentinel.server_port

    def _start(self, server: ThreadingHTTPServer) -> threading.Thread:
        thread = threading.Thread(
            target=server.serve_forever,
            kwargs={"poll_interval": 0.02},
            daemon=True,
        )
        thread.start()
        self.addCleanup(self._stop, server, thread)
        return thread

    def _stop(self, server: ThreadingHTTPServer, thread: threading.Thread) -> None:
        try:
            server.shutdown()
        except OSError:
            pass
        try:
            server.server_close()
        except OSError:
            pass
        thread.join(timeout=5)

    # Verifies: specs/model-router/requirements.md#4.5
    # Verifies: specs/model-router/requirements.md#4.5a
    def test_real_router_worker_killed_mid_session_falls_through_to_stub_upstream(
        self,
    ) -> None:
        # Request 1: the real router worker is healthy — served via the
        # worker's own `_forward_raw` relay to its backing upstream.
        status, body = _get(self.sentinel_port)
        self.assertEqual(status, 200)
        self.assertEqual(body, b"FROM-WORKER-UPSTREAM")
        self.assertEqual(len(self.worker_upstream_recorder), 1)
        self.assertEqual(len(self.sentinel_upstream_recorder), 0)

        # Kill the real router worker process's server/thread mid-session —
        # same `_stop()` (shutdown + server_close) as the generic-stub
        # worker test above, simulating a crashed/OOM-killed process.
        self._stop(self.worker_server, self.worker_thread)

        # Request 2 (new, post-kill): falls through to the sentinel's own
        # direct upstream, bounded by worker_timeout_s — the same mechanism
        # the generic-stub test above already proves, now confirmed with a
        # real router worker substituted in behind the sentinel.
        started = time.monotonic()
        status, body = _get(self.sentinel_port)
        elapsed = time.monotonic() - started
        self.assertEqual(status, 200)
        self.assertEqual(body, b"FROM-SENTINEL-UPSTREAM")
        self.assertLess(elapsed, 1.0)

        # Request 3: the sentinel itself is still alive and serving — the
        # real worker's death did not take the sentinel process down.
        self.assertTrue(self.sentinel_thread.is_alive())
        status, body = _get(self.sentinel_port)
        self.assertEqual(status, 200)
        self.assertEqual(body, b"FROM-SENTINEL-UPSTREAM")
        self.assertEqual(len(self.sentinel_upstream_recorder), 2)


# ---------------------------------------------------------------------------
# 4. Worker hang (timeout path): the worker accepts the connection but never
#    answers — distinct from the connection-refused case above. Uses a short
#    `worker_timeout_s` override for test speed (R4.5a).
# ---------------------------------------------------------------------------


class SentinelWorkerHangTests(unittest.TestCase):
    """A stub worker that accepts the connection but sleeps past the timeout."""

    def setUp(self) -> None:
        self.upstream_recorder = _RequestRecorder()
        self.upstream_behavior = _StubBehavior("upstream")
        self.upstream_server = _StubServer(
            ("127.0.0.1", 0), _StubHandler, self.upstream_recorder, self.upstream_behavior
        )
        self._start(self.upstream_server)
        upstream_url = f"http://127.0.0.1:{self.upstream_server.server_port}"

        self.worker_recorder = _RequestRecorder()
        self.worker_behavior = _StubBehavior("worker")
        self.worker_behavior.mode = "hang"
        self.worker_behavior.hang_s = 2.0  # far longer than worker_timeout_s below
        self.worker_server = _StubServer(
            ("127.0.0.1", 0), _StubHandler, self.worker_recorder, self.worker_behavior
        )
        self._start(self.worker_server)

        self.sentinel = build_server(
            host="127.0.0.1",
            port=0,
            upstream=upstream_url,
            worker_host="127.0.0.1",
            worker_port=self.worker_server.server_port,
            worker_timeout_s=0.05,
        )
        self._start(self.sentinel)
        self.sentinel_port = self.sentinel.server_port

    def _start(self, server: ThreadingHTTPServer) -> threading.Thread:
        thread = threading.Thread(
            target=server.serve_forever,
            kwargs={"poll_interval": 0.02},
            daemon=True,
        )
        thread.start()
        self.addCleanup(self._stop, server, thread)
        return thread

    def _stop(self, server: ThreadingHTTPServer, thread: threading.Thread) -> None:
        try:
            server.shutdown()
        except OSError:
            pass
        try:
            server.server_close()
        except OSError:
            pass
        thread.join(timeout=5)

    # Verifies: specs/model-router/requirements.md#4.5a
    def test_worker_hang_past_timeout_falls_through_to_upstream_within_budget(
        self,
    ) -> None:
        started = time.monotonic()
        status, body = _get(self.sentinel_port, timeout=5.0)
        elapsed = time.monotonic() - started

        self.assertEqual(status, 200)
        self.assertEqual(body, b"FROM-UPSTREAM")
        self.assertEqual(len(self.upstream_recorder), 1)
        # Bounded by the 0.05s connect/read budget (10x generous multiplier
        # for scheduling jitter), not by however long the worker actually
        # hangs (2.0s) — this is what proves the timeout is exercised, not
        # just configured.
        self.assertLess(elapsed, 0.5)


# ---------------------------------------------------------------------------
# 6. load_router_settings() — pure unit tests, no server needed (R4.5:
#    a sentinel that cannot find its own upstream is startup-fatal).
# ---------------------------------------------------------------------------


class LoadRouterSettingsTests(unittest.TestCase):
    # Verifies: specs/model-router/requirements.md#4.5
    def test_missing_file_raises_upstream_not_configured(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            missing_path = Path(tmp) / "router.toml"
            with self.assertRaises(UpstreamNotConfigured):
                load_router_settings(missing_path)

    # Verifies: specs/model-router/requirements.md#4.5
    def test_unparseable_toml_raises_upstream_not_configured(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            toml_path = Path(tmp) / "router.toml"
            toml_path.write_text("not [ valid toml", encoding="utf-8")
            with self.assertRaises(UpstreamNotConfigured):
                load_router_settings(toml_path)

    # Verifies: specs/model-router/requirements.md#4.5
    def test_missing_upstream_key_raises_upstream_not_configured(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            toml_path = Path(tmp) / "router.toml"
            toml_path.write_text("[router]\nport = 8799\n", encoding="utf-8")
            with self.assertRaises(UpstreamNotConfigured):
                load_router_settings(toml_path)

    # Verifies: specs/model-router/requirements.md#4.5
    def test_empty_upstream_value_raises_upstream_not_configured(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            toml_path = Path(tmp) / "router.toml"
            toml_path.write_text('[router]\nupstream = ""\n', encoding="utf-8")
            with self.assertRaises(UpstreamNotConfigured):
                load_router_settings(toml_path)

    # Verifies: specs/model-router/requirements.md#4.5
    def test_well_formed_file_returns_port_and_upstream(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            toml_path = Path(tmp) / "router.toml"
            toml_path.write_text(
                '[router]\nport = 8799\nupstream = "https://api.example.com"\n',
                encoding="utf-8",
            )

            port, upstream = load_router_settings(toml_path)

            self.assertEqual(port, 8799)
            self.assertEqual(upstream, "https://api.example.com")


if __name__ == "__main__":
    unittest.main()
