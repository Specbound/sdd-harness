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


if __name__ == "__main__":
    unittest.main()
