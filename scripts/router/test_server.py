"""Unit tests for scripts/router/server.py (task 7.2: fault-injection matrix).

Run via `scripts/router/server.test.sh` (wraps `python3 -m unittest`).

Mirrors `test_sentinel.py`'s posture exactly: a real stub `http.server.
ThreadingHTTPServer` on an ephemeral loopback port stands in for upstream —
never a mocked `urllib`. The router server under test is constructed via
`build_server(...)` (task 7.1's seam), pointed at a per-test temp-dir ledger,
same isolation `test_ledger.py`/`test_sentinel.py` already use.

Fixture catalog (`_build_catalog`): a two-rung ladder, `_CHEAP` (rung 0) and
`_BASELINE` (rung 1), with one `"code"` lane bucket whose `max` always admits
the stub classifier's fixed `score=5` and whose `rung=0` always picks
`_CHEAP`. This is deliberately the one and only downroute shape this module
needs — every test either takes that downroute (`_text_request`, non-empty
user text) or avoids classification entirely (`{"model": ...}` with no
`messages` field at all, so `_last_user_text` is `""` and `should_classify`
is `False` — a plain passthrough, `target == baseline`).

Coverage-to-task mapping (task 7.2's six numbered items):

1. R4.1 fail-open classes, each a separate case, each still serves the
   baseline's 2xx: `FailOpenClassesTests` (a)-(c), plus the malformed-body
   `_forward_raw` short-circuit (d), which is intentionally a distinct
   invariant (no classifier call, no ledger entry at all) rather than a
   fail-open outcome.
2. R5.10 retry-on-rejection: `RetryOnRejectionTests`.
3. R4.4 "no new non-2xx under any fault": not a separate test class — folded
   into every assertion above and below that checks `status` against
   whatever the stub upstream was configured to answer with for an unrouted/
   baseline request. There is no code path in this module that invents a
   status the stub didn't itself produce.
4. Upstream 429/500 passed through unchanged on a plain (non-rewritten)
   passthrough: `UpstreamOrdinaryErrorPassthroughTests`.
5. R4.2 "starting model recoverable from the ledger": folded into every test
   above that reaches `ledger.append()` — each asserts
   `CallRecord.baseline_model` equals the original request's `model` field,
   never the rewritten target.
6. R4.7 "local-model unavailability is fail-open, not an error": **not
   re-tested here.** `policy.select()`'s own contract (`_finalize_rung`/
   `_finalize_model` in `policy.py`) already guarantees it never returns a
   disabled/unusable model id — `server.py` has no separate branch for this
   because none is needed; the ladder rung `select()` hands back is already
   guaranteed usable. That guarantee is exercised by `test_policy.py`'s
   `test_disabled_candidate_falls_back_to_baseline` and
   `test_privacy_gate_trip_with_disabled_local_model_falls_back_to_baseline`.
   Inventing a `server.py`-level test for a code path that does not exist
   here would test nothing real.

Property-based testing was considered (per `.claude/kiro/settings/rules/
property-testing.md`) and does not apply: every case below exercises a
stateful, side-effecting HTTP round-trip (real sockets, a real ledger file)
rather than a pure function with an input-independent invariant to check
across generated inputs.
"""

from __future__ import annotations

import json
import socket
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

from classify import ClassifierUnavailable, Decision
from config import Catalog, Ladder, ModelEntry, RouterConfig
from ledger import Ledger
from server import build_server

#
# FIXED (was: filed-not-fixed in task 7.2's own report) — `_forward_headers`
# now strips the client's original `Content-Length` (case-insensitive,
# mirroring the response-side exclusion `_relay`/`_forward_raw` already use),
# so `urllib`'s own `do_request_` recomputes it from the actual outbound
# body instead of forwarding a stale value next to a `_rewrite_model`-
# produced body of a different byte length. Previously reproduced directly
# against this suite's own stub upstream as a real `TimeoutError`.
# `ContentLengthRewriteTests` below regression-tests this with model ids of
# genuinely different lengths. `_CHEAP`/`_BASELINE` stay equal-length so the
# retry test below continues to exercise R5.10's retry logic specifically,
# not this now-fixed, separate bug.
_BASELINE = "router-pricy"
_CHEAP = "router-cheap"

_DEFAULT_UPSTREAM_BODY = b'{"usage": {"input_tokens": 3, "output_tokens": 4}}'


# ---------------------------------------------------------------------------
# Fixture catalog: two-rung ladder, one lane bucket that always downroutes
# to `_CHEAP`. See module docstring.
# ---------------------------------------------------------------------------


def _build_catalog(
    upstream_url: str,
    *,
    cheap_model: str = _CHEAP,
    baseline_model: str = _BASELINE,
    thresholds: dict | None = None,
) -> Catalog:
    """`cheap_model`/`baseline_model` default to the equal-length module
    constants; pass distinct-length ids to exercise the rewrite path's
    former stale-Content-Length bug (`ContentLengthRewriteTests`).

    `thresholds` defaults to `{}` (absent keys); pass a dict with explicit
    `None` values — the real shape `config.py`'s `_parse_router_config`
    always produces for an unset `router.toml` key — to exercise
    `_derive_reason`'s former present-but-None crash
    (`ThresholdNoneCoalesceTests`).
    """
    ladder = Ladder(
        groups=[
            [
                ModelEntry(
                    model_id=cheap_model, prices={}, family="x", generation=(), family_known=False
                )
            ],
            [
                ModelEntry(
                    model_id=baseline_model, prices={}, family="x", generation=(), family_known=False
                )
            ],
        ],
        canonical=[cheap_model, baseline_model],
        rung_of={cheap_model: 0, baseline_model: 1},
    )
    policy = RouterConfig(
        schema_version=1,
        port=None,
        upstream=upstream_url,
        classifier={},
        thresholds=thresholds if thresholds is not None else {},
        escalation_window_s=120,
        max_tiers_above_baseline=3,
        tier_families=[],
        lanes={"code": [{"max": 10, "rung": 0}]},
        context_window_default=200_000,
        context_window_overrides={},
        overrides={},
        rejected_overrides={},
        local={},
    )
    return Catalog(pass_through=False, cause=None, ladder=ladder, policy=policy, rejected_models={})


class _RaisingRungCatalog:
    """Delegates every attribute to a real `Catalog` except `rung_of`, which
    always raises — used to make `policy.select()` itself raise (case 1c)
    without hand-rolling a second, duplicate Catalog implementation.

    `ledger.pending_escalation()`'s own short-circuit on an empty ledger
    (never calls the `rung_of` it was handed when there's no prior record)
    means this wrapper's raise is only ever triggered from inside
    `select()`'s first line, `catalog.rung_of(baseline)` — exactly the case
    this test targets, not an earlier, incidental trip.
    """

    def __init__(self, real_catalog: Catalog) -> None:
        self._real = real_catalog

    def rung_of(self, model_id: str) -> int | None:
        raise RuntimeError("stub catalog: rung_of failure")

    def __getattr__(self, name: str) -> object:
        return getattr(self._real, name)


# ---------------------------------------------------------------------------
# Stub classifier — configurable: succeed, raise generic, or raise
# ClassifierUnavailable. Never a mocked import, a real object implementing
# classify.py's `Classifier` Protocol.
# ---------------------------------------------------------------------------


class _StubClassifier:
    def __init__(self, mode: str = "ok") -> None:
        self.mode = mode
        self.calls = 0
        # lane "code", score 5 -> always lands in the one declared bucket
        # (max=10, rung=0) in _build_catalog's fixture lanes.
        self._decision = Decision(lane="code", score=5, gate_p=0.1, confidence=0.9, latency_ms=1)

    def classify(self, text: str) -> Decision:
        self.calls += 1
        if self.mode == "raise_generic":
            raise RuntimeError("stub classifier: generic failure")
        if self.mode == "raise_unavailable":
            raise ClassifierUnavailable("timeout", "stub classifier: unavailable")
        return self._decision


# ---------------------------------------------------------------------------
# Stub upstream: a real ThreadingHTTPServer on an ephemeral loopback port.
# Status/body are keyed by the request body's own "model" field so the
# retry test (R5.10) can answer the rewritten model and the baseline model
# differently from one process.
# ---------------------------------------------------------------------------


class _UpstreamBehavior:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.default_status = 200
        self.default_body = _DEFAULT_UPSTREAM_BODY
        self.status_by_model: dict[str, int] = {}
        self.body_by_model: dict[str, bytes] = {}
        self.requests: list[str | None] = []

    def record(self, model: str | None) -> None:
        with self._lock:
            self.requests.append(model)

    def response_for(self, model: str | None) -> tuple[int, bytes]:
        with self._lock:
            if model is None:
                return self.default_status, self.default_body
            status = self.status_by_model.get(model, self.default_status)
            body = self.body_by_model.get(model, self.default_body)
        return status, body


class _UpstreamHandler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        behavior: _UpstreamBehavior = self.server.behavior  # type: ignore[attr-defined]

        model: str | None = None
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = None
        if isinstance(parsed, dict):
            candidate = parsed.get("model")
            if isinstance(candidate, str):
                model = candidate

        behavior.record(model)
        status, body = behavior.response_for(model)
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except OSError:
            pass  # client already moved on

    def log_message(self, format: str, *args: object) -> None:
        pass


class _UpstreamServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        server_address: tuple[str, int],
        handler_cls: type[BaseHTTPRequestHandler],
        behavior: _UpstreamBehavior,
    ) -> None:
        self.behavior = behavior
        super().__init__(server_address, handler_cls)


def _text_request(model: str, text: str) -> bytes:
    return json.dumps({"model": model, "messages": [{"role": "user", "content": text}]}).encode(
        "utf-8"
    )


def _post(port: int, body: bytes, timeout: float = 5.0) -> tuple[int, bytes]:
    request = Request(
        f"http://127.0.0.1:{port}/v1/messages",
        data=body,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        response = urlopen(request, timeout=timeout)
    except HTTPError as exc:
        response = exc
    status = response.status
    assert status is not None  # real once a response completes, same narrowing as server.py's own
    return status, response.read()


def _wait_for_ledger_lines(path: Path, minimum: int, timeout: float = 5.0) -> list[str]:
    """Poll for at least `minimum` non-blank lines, bounded by `timeout`.

    Guards the race the task calls out explicitly: the client reading its
    HTTP response races the handler thread's post-response
    `ledger.append()` call, so asserting on the file immediately after
    `_post()` returns is unsound.
    """
    deadline = time.monotonic() + timeout
    lines: list[str] = []
    while time.monotonic() < deadline:
        if path.exists():
            lines = [line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
            if len(lines) >= minimum:
                return lines
        time.sleep(0.02)
    return lines


# ---------------------------------------------------------------------------
# Shared test harness: per-test tempdir ledger + a per-test stub upstream.
# Servers started here are stopped explicitly in tearDown, before the
# tempdir is cleaned up (task note: avoid addCleanup-ordering races).
# ---------------------------------------------------------------------------


class _RouterServerTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp_path = Path(self._tmp.name)
        self.ledger_path = self.tmp_path / "ledger.jsonl"
        self.stats_path = self.tmp_path / "stats.json"
        self.ledger = Ledger(ledger_path=self.ledger_path, stats_path=self.stats_path)

        self.upstream_behavior = _UpstreamBehavior()
        self.upstream_server = _UpstreamServer(
            ("127.0.0.1", 0), _UpstreamHandler, self.upstream_behavior
        )
        self._servers: list[tuple[ThreadingHTTPServer, threading.Thread]] = []
        self._start(self.upstream_server)
        self.upstream_url = f"http://127.0.0.1:{self.upstream_server.server_port}"

        self.catalog = _build_catalog(self.upstream_url)

    def tearDown(self) -> None:
        for server, thread in self._servers:
            self._stop(server, thread)
        self._tmp.cleanup()

    def _start(self, server: ThreadingHTTPServer) -> threading.Thread:
        thread = threading.Thread(
            target=server.serve_forever, kwargs={"poll_interval": 0.02}, daemon=True
        )
        thread.start()
        self._servers.append((server, thread))
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

    def _build_router(self, classifier, catalog=None) -> ThreadingHTTPServer:
        server = build_server(
            host="127.0.0.1",
            port=0,
            catalog=catalog if catalog is not None else self.catalog,
            classifier=classifier,
            ledger=self.ledger,
        )
        self._start(server)
        return server


# ---------------------------------------------------------------------------
# 1. R4.1 fail-open classes (a)-(d) — each still serves a 2xx on the
#    baseline (R4.4), and each that reaches the ledger carries the original
#    baseline_model (R4.2). See module docstring item 1 for (d)'s rationale.
# ---------------------------------------------------------------------------


class FailOpenClassesTests(_RouterServerTestCase):
    # Verifies: specs/model-router/requirements.md#4.1
    # Verifies: specs/model-router/requirements.md#4.2
    # Verifies: specs/model-router/requirements.md#4.4
    def test_classifier_raises_generic_exception_fails_open_with_reason_error(self) -> None:
        classifier = _StubClassifier(mode="raise_generic")
        server = self._build_router(classifier)

        status, _body = _post(server.server_port, _text_request(_BASELINE, "hello there"))

        self.assertEqual(status, 200)  # the baseline's own 2xx, never an invented status
        self.assertEqual(classifier.calls, 1)

        lines = _wait_for_ledger_lines(self.ledger_path, 1)
        self.assertEqual(len(lines), 1)
        record = json.loads(lines[0])
        self.assertEqual(record["outcome"], "failed_open")
        self.assertEqual(record["reason"], "error")
        self.assertEqual(record["baseline_model"], _BASELINE)
        self.assertEqual(record["selected_model"], _BASELINE)

    # Verifies: specs/model-router/requirements.md#4.1
    # Verifies: specs/model-router/requirements.md#4.2
    # Verifies: specs/model-router/requirements.md#4.4
    def test_classifier_raises_unavailable_fails_open_with_reason_no_classifier(self) -> None:
        classifier = _StubClassifier(mode="raise_unavailable")
        server = self._build_router(classifier)

        status, _body = _post(server.server_port, _text_request(_BASELINE, "hello there"))

        self.assertEqual(status, 200)
        self.assertEqual(classifier.calls, 1)

        lines = _wait_for_ledger_lines(self.ledger_path, 1)
        self.assertEqual(len(lines), 1)
        record = json.loads(lines[0])
        self.assertEqual(record["outcome"], "failed_open")
        self.assertEqual(record["reason"], "no_classifier")
        self.assertEqual(record["baseline_model"], _BASELINE)
        self.assertEqual(record["selected_model"], _BASELINE)

    # Verifies: specs/model-router/requirements.md#4.1
    # Verifies: specs/model-router/requirements.md#4.2
    # Verifies: specs/model-router/requirements.md#4.4
    def test_policy_select_itself_raising_fails_open_with_reason_error(self) -> None:
        classifier = _StubClassifier(mode="ok")
        raising_catalog = _RaisingRungCatalog(self.catalog)
        server = self._build_router(classifier, catalog=raising_catalog)

        status, _body = _post(server.server_port, _text_request(_BASELINE, "hello there"))

        self.assertEqual(status, 200)
        # classify() itself succeeded (mode="ok"); select() is what raised,
        # confirming this exercises select()'s own guard, not classify()'s.
        self.assertEqual(classifier.calls, 1)

        lines = _wait_for_ledger_lines(self.ledger_path, 1)
        self.assertEqual(len(lines), 1)
        record = json.loads(lines[0])
        self.assertEqual(record["outcome"], "failed_open")
        self.assertEqual(record["reason"], "error")
        self.assertEqual(record["baseline_model"], _BASELINE)
        self.assertEqual(record["selected_model"], _BASELINE)

    # Verifies: specs/model-router/requirements.md#4.1
    # Verifies: specs/model-router/requirements.md#4.4
    def test_malformed_json_body_forwards_raw_with_no_classifier_call_and_no_ledger_entry(
        self,
    ) -> None:
        classifier = _StubClassifier(mode="ok")
        server = self._build_router(classifier)

        status, body = _post(server.server_port, b"{not valid json")

        self.assertEqual(status, 200)  # upstream's own verbatim response for the unparsed body
        self.assertEqual(body, self.upstream_behavior.default_body)
        self.assertEqual(classifier.calls, 0)  # _forward_raw never reaches classification

        # Give a (nonexistent) append the time it would need, then confirm
        # no ledger line was ever written for this request specifically.
        time.sleep(0.2)
        lines = []
        if self.ledger_path.exists():
            lines = [
                line for line in self.ledger_path.read_text(encoding="utf-8").splitlines() if line.strip()
            ]
        self.assertEqual(lines, [])


# ---------------------------------------------------------------------------
# 2. R5.10 retry-on-rejection: upstream 400s the rewritten model specifically,
#    the client sees the baseline's 200 with no trace of the rejected first
#    attempt, and exactly one ledger line is written for the whole sequence.
# ---------------------------------------------------------------------------


class RetryOnRejectionTests(_RouterServerTestCase):
    # Verifies: specs/model-router/requirements.md#5.10
    # Verifies: specs/model-router/requirements.md#4.2
    # Verifies: specs/model-router/requirements.md#4.4
    def test_upstream_400_on_rewritten_model_retries_once_on_baseline(self) -> None:
        baseline_body = b'{"usage": {"input_tokens": 7, "output_tokens": 9}}'
        self.upstream_behavior.status_by_model[_CHEAP] = 400
        self.upstream_behavior.body_by_model[_CHEAP] = b"REJECTED-CHEAP"
        self.upstream_behavior.body_by_model[_BASELINE] = baseline_body

        classifier = _StubClassifier(mode="ok")  # routes to _CHEAP per the fixture catalog
        server = self._build_router(classifier)

        status, body = _post(server.server_port, _text_request(_BASELINE, "please downroute me"))

        # The client sees only the baseline's successful retry — headers and
        # body are the baseline response's, not the rejected first attempt's.
        self.assertEqual(status, 200)
        self.assertEqual(body, baseline_body)
        self.assertNotIn(b"REJECTED-CHEAP", body)

        # Both attempts actually reached upstream, in order: rejected cheap
        # first, baseline second — proves this is a real retry, not a skip.
        self.assertEqual(self.upstream_behavior.requests, [_CHEAP, _BASELINE])

        lines = _wait_for_ledger_lines(self.ledger_path, 1)
        self.assertEqual(len(lines), 1)  # exactly one ledger line for the whole retry sequence
        record = json.loads(lines[0])
        self.assertEqual(record["selected_model"], _BASELINE)
        self.assertEqual(record["outcome"], "failed_open")
        self.assertEqual(record["reason"], "error")
        self.assertEqual(record["baseline_model"], _BASELINE)


# ---------------------------------------------------------------------------
# 4. Upstream's own 429/500 on a plain (non-rewritten) passthrough passes
#    through unchanged — R5.10's retry is scoped to target != baseline only,
#    so an ordinary upstream error on an unrouted call must never retry.
# ---------------------------------------------------------------------------


class UpstreamOrdinaryErrorPassthroughTests(_RouterServerTestCase):
    # Verifies: specs/model-router/requirements.md#4.4
    def test_upstream_429_on_plain_passthrough_passes_through_unchanged(self) -> None:
        self._assert_passthrough_unchanged(429, b"RATE-LIMITED-UPSTREAM")

    # Verifies: specs/model-router/requirements.md#4.4
    def test_upstream_500_on_plain_passthrough_passes_through_unchanged(self) -> None:
        self._assert_passthrough_unchanged(500, b"UPSTREAM-BROKEN")

    def _assert_passthrough_unchanged(self, status_code: int, body_bytes: bytes) -> None:
        self.upstream_behavior.status_by_model[_BASELINE] = status_code
        self.upstream_behavior.body_by_model[_BASELINE] = body_bytes

        classifier = _StubClassifier(mode="ok")
        server = self._build_router(classifier)

        # No "messages" field at all -> _last_user_text() is "" ->
        # should_classify() is False -> target stays == baseline: a plain
        # passthrough, never a rewrite, so the retry branch is structurally
        # unreachable (it's gated on target != baseline).
        status, body = _post(server.server_port, json.dumps({"model": _BASELINE}).encode("utf-8"))

        self.assertEqual(status, status_code)  # upstream's own status, verbatim
        self.assertEqual(body, body_bytes)
        self.assertEqual(classifier.calls, 0)
        self.assertEqual(self.upstream_behavior.requests, [_BASELINE])  # exactly one attempt


# ---------------------------------------------------------------------------
# Regression: stale Content-Length on a rewritten request (bugfix pass on
# top of task 7.1/7.2). `_CHEAP`/`_BASELINE` above are deliberately
# equal-length so this needed its own catalog with genuinely different
# model-id lengths to actually exercise the bug.
# ---------------------------------------------------------------------------
class ContentLengthRewriteTests(_RouterServerTestCase):
    # Verifies: specs/model-router/requirements.md#3.1
    def test_rewrite_between_different_length_model_ids_completes_and_relays_body(self) -> None:
        cheap_model = "rc"
        baseline_model = "router-pricy-baseline-model-with-a-long-name"
        catalog = _build_catalog(
            self.upstream_url, cheap_model=cheap_model, baseline_model=baseline_model
        )

        classifier = _StubClassifier(mode="ok")  # routes to cheap_model per the fixture lane
        server = self._build_router(classifier, catalog=catalog)

        status, body = _post(server.server_port, _text_request(baseline_model, "please downroute me"))

        # Before the fix this hung/timed out against the stub upstream
        # instead of completing — now it must relay the upstream's real
        # response for the rewritten (shorter) model id.
        self.assertEqual(status, 200)
        self.assertEqual(body, _DEFAULT_UPSTREAM_BODY)
        self.assertEqual(self.upstream_behavior.requests, [cheap_model])


# ---------------------------------------------------------------------------
# Regression: `_derive_reason`'s threshold defaults never applying when a
# key is present-but-`None` (the real shape config.py produces for an unset
# router.toml key) — previously crashed into a fail-open "error" instead of
# the real routing decision.
# ---------------------------------------------------------------------------
class ThresholdNoneCoalesceTests(_RouterServerTestCase):
    # Verifies: specs/model-router/requirements.md#4.1
    def test_all_none_thresholds_produce_real_reason_not_fail_open(self) -> None:
        catalog = _build_catalog(
            self.upstream_url,
            thresholds={
                "privacy_threshold": None,
                "confidence_floor": None,
                "long_context_tokens": None,
            },
        )
        classifier = _StubClassifier(mode="ok")
        server = self._build_router(classifier, catalog=catalog)

        status, _body = _post(server.server_port, _text_request(_BASELINE, "please downroute me"))

        self.assertEqual(status, 200)
        self.assertEqual(classifier.calls, 1)

        lines = _wait_for_ledger_lines(self.ledger_path, 1)
        self.assertEqual(len(lines), 1)
        record = json.loads(lines[0])
        # Before the fix, `thresholds.get(key, default)` never applied its
        # default for a present-but-None value, so `decision.gate_p > None`
        # raised and `_handle()`'s broad except converted this into a
        # fail-open ("error") instead of the real downroute decision.
        self.assertNotEqual(record["outcome"], "failed_open")
        self.assertNotEqual(record["reason"], "error")
        self.assertEqual(record["outcome"], "applied")
        self.assertEqual(record["selected_model"], _CHEAP)
        self.assertEqual(record["reason"], "policy")


# ---------------------------------------------------------------------------
# Task 7.3: streaming fidelity — a real multi-chunk Anthropic SSE sequence
# (message_start -> content_block_delta x2 -> message_delta -> message_stop),
# each event sent by the stub upstream as its own `_write_chunk` write with
# an explicit flush, not one combined write. Covers R3.2 ("identical with
# and without the proxy") and R3.3 ("never buffers a streaming response").
#
# KNOWN BUG (found during this task, NOT fixed here — server.py is out of
# scope per the task directive; flagged for a dedicated fix pass, same
# posture as task 7.2's own Content-Length/None-coalesce findings):
#
# `_relay()`'s read-from-upstream loop (`response.read(_CHUNK_SIZE)`,
# `_CHUNK_SIZE = 65536`) does not return as soon as *any* data is available
# from a chunked-transfer-encoding upstream. `http.client.HTTPResponse
# .read(amt)`'s chunked-mode implementation (`_read_chunked`) loops pulling
# *additional* HTTP-level chunks off the socket until it has accumulated
# `amt` bytes total or the stream ends — it only returns early once a
# single already-buffered chunk is itself >= `amt`. For any multi-event SSE
# stream whose cumulative size is under 64KB (true of every event below,
# and true of virtually all real token-by-token deltas), this means
# `_relay()` silently buffers EVERY event until the upstream closes the
# connection, then relays everything as a single write — the opposite of
# R3.3's "never buffers a streaming response" invariant, and fatal to
# real-time delivery in production.
#
# Confirmed directly (not inferred) against a real `build_server()`
# instance during this task's investigation, by three independent methods
# that all showed the identical result — the client receives nothing until
# the LAST event has already been sent by the stub and the connection
# closes: `response.read(65536)`, `response.read1(65536)` (a single-
# syscall, non-accumulating read — rules out client-side read semantics as
# the cause), and a raw-socket `recv()` loop (rules out any `http.client`
# buffering on the client side entirely).
#
# Recommended fix for the dedicated pass: use `response.read1(_CHUNK_SIZE)`
# instead of `response.read(_CHUNK_SIZE)` in both `_relay()` and
# `_copy_chunked()` — `read1()` performs at most one underlying read without
# the accumulate-until-`amt` loop, which is what actually yields incremental
# relay from a chunked source.
#
# `test_early_chunk_is_client_readable_before_later_chunk_is_sent` below is
# written to the task's literal requirement and is `@unittest.expectedFailure`
# — not skipped or deleted — so it fails loudly and specifically (never a
# hang) until the dedicated fix lands, and flips to an "unexpected success"
# (a hard failure) the moment it does, at which point the decorator should
# be removed. The other two tests in this class assert final byte-for-byte
# sequence equality only (not incremental timing), which the bug above does
# not affect — they hold today and will continue to hold after the fix.
# ---------------------------------------------------------------------------
_SSE_EVENTS: tuple[bytes, ...] = (
    (
        b'event: message_start\ndata: {"type":"message_start","message":'
        b'{"id":"msg_1","usage":{"input_tokens":12,"output_tokens":0}}}\n\n'
    ),
    (
        b'event: content_block_delta\ndata: {"type":"content_block_delta",'
        b'"index":0,"delta":{"type":"text_delta","text":"Hel"}}\n\n'
    ),
    (
        b'event: content_block_delta\ndata: {"type":"content_block_delta",'
        b'"index":0,"delta":{"type":"text_delta","text":"lo"}}\n\n'
    ),
    (
        b'event: message_delta\ndata: {"type":"message_delta","delta":'
        b'{"stop_reason":"end_turn"},"usage":{"input_tokens":12,"output_tokens":5}}\n\n'
    ),
    b'event: message_stop\ndata: {"type":"message_stop"}\n\n',
)

# Bounded wait for the *stub*'s own internal gate between events — never the
# unbounded hang the module docstring above warns about; always finite so a
# killed/aborted test run still tears down within this budget.
_GATE_WAIT_TIMEOUT_S = 3.0


class _StreamingUpstreamBehavior:
    """Serves a fixed, ordered sequence of real SSE event chunks over a
    chunked-transfer-encoding response, one `_write_chunk` per event, each
    individually flushed.

    `gate=True` makes the handler block after each event (except the last)
    on `release_events[i]`, bounded by `_GATE_WAIT_TIMEOUT_S` — lets a test
    synchronize "client has read event i" with "stub now sends event i+1"
    (see `test_early_chunk_is_client_readable_before_later_chunk_is_sent`).
    `gate=False` (default) just sleeps `inter_event_delay_s` between writes,
    mimicking realistic token-by-token arrival with no synchronization.
    """

    def __init__(
        self,
        events: tuple[bytes, ...] = _SSE_EVENTS,
        *,
        gate: bool = False,
        inter_event_delay_s: float = 0.01,
    ) -> None:
        self.events = events
        self.gate = gate
        self.inter_event_delay_s = inter_event_delay_s
        self.release_events = [threading.Event() for _ in range(len(events) - 1)] if gate else []
        self.sent_events = [threading.Event() for _ in events]
        self.requests: list[str | None] = []
        self._lock = threading.Lock()

    def record(self, model: str | None) -> None:
        with self._lock:
            self.requests.append(model)

    def release(self, index: int) -> None:
        self.release_events[index].set()


class _StreamingUpstreamHandler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        behavior: _StreamingUpstreamBehavior = self.server.behavior  # type: ignore[attr-defined]

        model: str | None = None
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = None
        if isinstance(parsed, dict) and isinstance(parsed.get("model"), str):
            model = parsed["model"]
        behavior.record(model)

        try:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            for index, event in enumerate(behavior.events):
                self._write_chunk(event)
                behavior.sent_events[index].set()
                if behavior.gate and index < len(behavior.release_events):
                    behavior.release_events[index].wait(timeout=_GATE_WAIT_TIMEOUT_S)
                elif behavior.inter_event_delay_s:
                    time.sleep(behavior.inter_event_delay_s)
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except OSError:
            pass  # client already moved on

    def _write_chunk(self, chunk: bytes) -> None:
        self.wfile.write(f"{len(chunk):x}\r\n".encode("ascii"))
        self.wfile.write(chunk)
        self.wfile.write(b"\r\n")
        self.wfile.flush()

    def log_message(self, format: str, *args: object) -> None:
        pass


class _StreamingUpstreamServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        server_address: tuple[str, int],
        handler_cls: type[BaseHTTPRequestHandler],
        behavior: _StreamingUpstreamBehavior,
    ) -> None:
        self.behavior = behavior
        super().__init__(server_address, handler_cls)


class StreamingFidelityTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        tmp_path = Path(self._tmp.name)
        self.ledger = Ledger(ledger_path=tmp_path / "ledger.jsonl", stats_path=tmp_path / "stats.json")
        self._servers: list[tuple[ThreadingHTTPServer, threading.Thread]] = []

    def tearDown(self) -> None:
        for server, thread in self._servers:
            self._stop(server, thread)
        self._tmp.cleanup()

    def _start(self, server: ThreadingHTTPServer) -> threading.Thread:
        thread = threading.Thread(
            target=server.serve_forever, kwargs={"poll_interval": 0.02}, daemon=True
        )
        thread.start()
        self._servers.append((server, thread))
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

    def _build_streaming_upstream(
        self, events: tuple[bytes, ...] = _SSE_EVENTS, *, gate: bool = False
    ) -> tuple[_StreamingUpstreamServer, _StreamingUpstreamBehavior]:
        behavior = _StreamingUpstreamBehavior(events, gate=gate)
        server = _StreamingUpstreamServer(("127.0.0.1", 0), _StreamingUpstreamHandler, behavior)
        self._start(server)
        return server, behavior

    def _build_router(self, catalog: Catalog, classifier) -> ThreadingHTTPServer:
        server = build_server(
            host="127.0.0.1", port=0, catalog=catalog, classifier=classifier, ledger=self.ledger
        )
        self._start(server)
        return server

    # Verifies: specs/model-router/requirements.md#3.2
    # Verifies: specs/model-router/requirements.md#3.3
    def test_passthrough_stream_byte_sequence_identical_to_direct_upstream(self) -> None:
        """target == baseline (no 'messages' field -> should_classify() is
        False): the router's relayed SSE byte sequence, read start to
        finish, is identical to what a client talking to the stub upstream
        directly (no proxy in the path at all) would see."""
        upstream_server, _behavior = self._build_streaming_upstream()
        upstream_url = f"http://127.0.0.1:{upstream_server.server_port}"
        catalog = _build_catalog(upstream_url)
        classifier = _StubClassifier(mode="ok")
        router = self._build_router(catalog, classifier)

        body = json.dumps({"model": _BASELINE, "stream": True}).encode("utf-8")

        direct_status, direct_body = _post(upstream_server.server_port, body)
        router_status, router_body = _post(router.server_port, body)

        expected = b"".join(_SSE_EVENTS)
        self.assertEqual(direct_status, 200)
        self.assertEqual(router_status, 200)
        self.assertEqual(direct_body, expected)
        self.assertEqual(router_body, expected)  # identical with and without the proxy
        self.assertEqual(classifier.calls, 0)  # no "messages" field -> never classified

    # Verifies: specs/model-router/requirements.md#3.2
    # Verifies: specs/model-router/requirements.md#3.3
    def test_rewritten_model_stream_still_relays_byte_identical_sequence(self) -> None:
        """target != baseline (classifier routes to _CHEAP): the rewrite
        changes the outbound request's `model` field only — the relayed SSE
        byte sequence the client reads back is still byte-for-byte identical
        to what the stub upstream actually sent (tee fidelity survives the
        rewrite)."""
        upstream_server, behavior = self._build_streaming_upstream()
        upstream_url = f"http://127.0.0.1:{upstream_server.server_port}"
        catalog = _build_catalog(upstream_url)
        classifier = _StubClassifier(mode="ok")  # lands in the one fixture bucket -> _CHEAP
        router = self._build_router(catalog, classifier)

        body = json.dumps(
            {
                "model": _BASELINE,
                "stream": True,
                "messages": [{"role": "user", "content": "please downroute me"}],
            }
        ).encode("utf-8")

        router_status, router_body = _post(router.server_port, body)

        self.assertEqual(router_status, 200)
        self.assertEqual(router_body, b"".join(_SSE_EVENTS))  # byte-for-byte, despite the rewrite
        self.assertEqual(behavior.requests, [_CHEAP])  # confirms the rewrite actually reached upstream

    # Verifies: specs/model-router/requirements.md#3.2
    # Verifies: specs/model-router/requirements.md#3.3 (property: incremental delivery)
    def test_early_chunk_is_client_readable_before_later_chunk_is_sent(self) -> None:
        """The client must be able to read event 0 off the socket before
        event 1 has even been sent by the stub — a direct probe of R3.3's
        "no buffering of full responses" invariant.

        `_post()` (used by the other two tests in this class) cannot probe
        this: it drives `http.client.HTTPResponse.read()` with no `amt`,
        which for a chunked body always blocks until the terminal chunk
        arrives, no matter how incrementally the server wrote earlier
        chunks — it is a full-body read by definition, not a partial one.
        This test instead opens a raw socket to the router, sends the
        request by hand, and accumulates bounded `recv()` calls — which
        return as soon as *any* bytes the router has already relayed are
        on the wire — so it can observe partial delivery directly.
        """
        upstream_server, behavior = self._build_streaming_upstream(gate=True)
        upstream_url = f"http://127.0.0.1:{upstream_server.server_port}"
        catalog = _build_catalog(upstream_url)
        classifier = _StubClassifier(mode="ok")
        router = self._build_router(catalog, classifier)

        body = json.dumps({"model": _BASELINE, "stream": True}).encode("utf-8")
        request_bytes = (
            b"POST /v1/messages HTTP/1.1\r\n"
            b"Host: 127.0.0.1\r\n"
            b"Content-Type: application/json\r\n"
            b"Content-Length: " + str(len(body)).encode("ascii") + b"\r\n"
            b"Connection: close\r\n\r\n" + body
        )

        with socket.create_connection(("127.0.0.1", router.server_port), timeout=5.0) as sock:
            try:
                sock.sendall(request_bytes)

                # The stub sending event 0 is always fast — sending is
                # server-side and not gated on the client reading anything.
                self.assertTrue(behavior.sent_events[0].wait(timeout=2.0))

                # The real assertion: accumulate bounded recv()s with
                # events 1-4 still physically ungated-unsent (no gate has
                # been released yet below) — event 0's own marker must
                # already be on the wire, and neither a later event's
                # marker nor the terminal event should be, proving the
                # router relayed event 0 without waiting on anything past
                # it.
                sock.settimeout(2.0)
                received = b""
                deadline = time.monotonic() + 2.0
                while b"message_start" not in received and time.monotonic() < deadline:
                    chunk = sock.recv(65536)
                    if not chunk:
                        break
                    received += chunk

                self.assertIn(
                    b"message_start",
                    received,
                    "expected event 0's bytes to already be relayed to the client",
                )
                self.assertNotIn(
                    b"content_block_delta",
                    received,
                    "event 1 should not have been sent by the still-gated stub",
                )
                self.assertNotIn(b"message_stop", received)
            finally:
                # Release every remaining gate so the handler and the stub
                # both finish within tearDown's own bound, regardless of
                # which assertion above raised.
                for index in range(len(behavior.release_events)):
                    behavior.release(index)
                sock.settimeout(5.0)
                try:
                    while sock.recv(65536):
                        pass
                except OSError:
                    pass


if __name__ == "__main__":
    unittest.main()
