"""scripts/router/server.py — the worker: HTTP handler owning the one fail-open guard.

Binds `127.0.0.1:8798` only — behind `sentinel.py`, never the public port
(`ANTHROPIC_BASE_URL` points at the sentinel, not here). Wires together the
five already-shipped modules in `scripts/router/` (`config.py`, `policy.py`,
`classify.py`, `ledger.py`, `stream.py` — none of which this file modifies)
into the single request/response path design.md's "Router / server.py"
section describes, matching its worked `handle()` pseudocode almost exactly:

    body = read once -> baseline = body["model"]
    try:                                      # R4.1's one broad guard
        decision = classifier.classify(last_user_text)
        target   = policy.select(decision, catalog, baseline, token_estimate, escalation)
    except Exception:
        decision, target = None, baseline      # fail-open
    response = forward(target or baseline)
    if target != baseline and response.status >= 400:
        response = forward(baseline)            # R5.10 retry
    ledger.append(...)                          # exactly once per served request

Named decisions this module makes that no shipped module already covers
(flagged here rather than silently, per the task that produced this file):

- **Reason derivation** (`_derive_reason`). `policy.select()` returns only a
  model id, with no breadcrumb for *which* precedence branch fired, and its
  branch-check helpers are private (`_privacy_pick` etc.) and must not be
  imported. This independently re-checks the same three threshold fields
  `select()` itself reads off `catalog.policy.thresholds`, in the same
  priority order — a deliberate, documented duplication of three comparisons
  (not of `select()`'s actual branching logic).
- **Streaming vs. non-streaming usage extraction** (`_usage_from_json_body`).
  `stream.py`'s `StreamTee` parses SSE `data:` lines and does not recognize a
  plain JSON body. A non-streaming Anthropic response is one deliverable
  unit, not a stream — reading it whole and parsing its top-level `usage`
  object once is not what R3.3's "no buffering" invariant is guarding
  against, so it is handled separately rather than forced through `StreamTee`.
- **No-model/malformed-body short-circuit carries no ledger entry.**
  design.md's own invariant ("missing/malformed body short-circuits verbatim
  forwarding before parsing is attempted") has no `baseline_model` to log
  against — `ledger.CallRecord.baseline_model` is a required, non-optional
  `str`. This path (`_forward_raw`) forwards unmodified and returns before
  ever constructing a `CallRecord`.
- **Startup-fatal upstream check.** `catalog.policy is None` or an empty
  `upstream` means this process cannot reach anywhere to forward a request —
  structurally unrecoverable per-request, so `main()` logs and exits rather
  than treating it as a fail-open case, the same posture `sentinel.py`'s own
  `UpstreamNotConfigured` takes for its half of this exact problem.
- **Classifier startup fallback** (`_build_classifier`, `_probe_reachable`).
  R2.5 says an unavailable classifier backend must start the process anyway,
  in pass-through mode. Construction failure (bad `base_url`) or a one-time
  startup reachability probe failing both fall back to `NullClassifier` —
  never attempted again per-request; `NullClassifier` always raises
  `ClassifierUnavailable`, which the per-request guard already handles.

`_HOP_BY_HOP_HEADERS`, the exact/chunked body-copy helpers, and the
`_RouterServer` config-holder pattern duplicate `sentinel.py`'s own
equivalents rather than importing them — the two processes are deliberately
independent (design.md Key Decision 1a); importing worker-side plumbing into
the sentinel, or vice versa, would recreate the shared-failure-surface
problem that decision exists to avoid.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from classify import (
    Classifier,
    ClassifierUnavailable,
    Decision,
    JeffClassifier,
    NullClassifier,
    resolve_base_url,
    should_classify,
)
from config import Catalog, load_catalog
from ledger import CallRecord, Ledger
from policy import Escalation, select
from stream import StreamTee, UsageResult

logger = logging.getLogger("router")

# This process's own bind address — independently matching (not imported
# from) sentinel.py's `WORKER_HOST`/`WORKER_PORT`, which name the same
# address from the sentinel's point of view. See module docstring.
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8798

# Mirrors ledger.py's `Path.home() / ".sdd-router" / ...` convention exactly,
# same as sentinel.py's own `DEFAULT_ROUTER_TOML_PATH` — independently
# duplicated, not imported (Key Decision 1a).
DEFAULT_ROUTER_TOML_PATH = Path.home() / ".sdd-router" / "router.toml"

_CHUNK_SIZE = 65536

# Duplicated from sentinel.py's own `_HOP_BY_HOP_HEADERS` (RFC 7230 6.1) —
# same literal set, independently maintained per the two-process boundary.
_HOP_BY_HOP_HEADERS = frozenset(
    {
        "connection",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailers",
        "transfer-encoding",
        "upgrade",
        "host",
    }
)

# `_token_estimate`'s char-count heuristic (no tokenizer dependency, stdlib
# only) — a documented approximation, not Anthropic's real token count.
_CHARS_PER_TOKEN_ESTIMATE = 4

# Mirrors ledger.py's own `_DEFAULT_ESCALATION_WINDOW_S` (that name is
# private to ledger.py) — used only when `catalog.policy` is absent.
_DEFAULT_ESCALATION_WINDOW_S = 120

# One-time startup classifier-reachability probe budget (R2.5) — never a
# per-request timeout; `classify.py`'s own `timeout_ms` governs those.
_STARTUP_PROBE_TIMEOUT_S = 0.5


def _forward_headers(headers) -> dict[str, str]:
    """Copy a client header set, dropping hop-by-hop headers (RFC 7230 6.1)
    and the client's own `Content-Length`.

    `Content-Length` is dropped (not just hop-by-hop) because `_rewrite_model`
    can re-serialize the body to a different byte length than the client's
    original `raw_body`; `http.client` only auto-computes `Content-Length`
    when the header is absent, so a stale value here would desync upstream's
    framing. Mirrors the exact `key.lower() == "content-length"` exclusion
    `_relay`/`_forward_raw` already apply when copying the *response*
    headers back to the client. Everything else — including auth/credentials
    (R3.5) — passes through untouched.
    """
    return {
        k: v
        for k, v in headers.items()
        if k.lower() not in _HOP_BY_HOP_HEADERS and k.lower() != "content-length"
    }


def _parse_body(raw_body: bytes) -> tuple[dict, str] | None:
    """`(body, baseline_model)` for a well-formed request, else `None`.

    `None` covers unparseable JSON, a non-object body, and a missing/empty
    `model` field — design.md's own invariant: "missing/malformed body
    short-circuits verbatim forwarding before parsing is attempted."
    """
    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return None
    if not isinstance(body, dict):
        return None
    baseline = body.get("model")
    if not isinstance(baseline, str) or not baseline:
        return None
    return body, baseline


def _last_user_text(body: dict) -> str:
    """Text of the most recent `role: "user"` message, `text` blocks only.

    A tool-loop continuation's user-role message is entirely `tool_result`
    content; those blocks are deliberately skipped, so this returns `""` for
    that turn and `should_classify("")` correctly treats it as PASS_THROUGH
    (classify.py's own module docstring).
    """
    messages = body.get("messages")
    if not isinstance(messages, list):
        return ""
    for message in reversed(messages):
        if not isinstance(message, dict) or message.get("role") != "user":
            continue
        content = message.get("content")
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            parts = [
                block.get("text", "")
                for block in content
                if isinstance(block, dict) and block.get("type") == "text"
            ]
            return "".join(parts)
        return ""
    return ""


def _token_estimate(raw_body: bytes) -> int:
    """Char-count/`_CHARS_PER_TOKEN_ESTIMATE` heuristic for `policy.select()`'s
    `token_estimate` argument (feeds R1.5's long-context guard) — no
    tokenizer dependency, a documented approximation only.
    """
    return len(raw_body) // _CHARS_PER_TOKEN_ESTIMATE


def _rewrite_model(body: dict, target: str) -> bytes:
    """Re-serialize `body` with `model` replaced by `target`.

    Used only when `target != baseline` (R3.1) — every other key is carried
    through unchanged. When no rewrite is needed, callers forward the
    original raw bytes instead of calling this at all (R3.2).
    """
    rewritten = dict(body)
    rewritten["model"] = target
    return json.dumps(rewritten).encode("utf-8")


def _escalation_window_s(catalog: Catalog) -> int:
    return catalog.policy.escalation_window_s if catalog.policy is not None else _DEFAULT_ESCALATION_WINDOW_S


def _derive_reason(catalog: Catalog, decision: Decision, token_estimate: int) -> str:
    """Re-derive *why* a successful `select()` call picked what it picked.

    See module docstring's "Reason derivation" note — a deliberate,
    documented duplication of three threshold comparisons, in the same
    priority order `select()` itself uses, not of its branching logic.
    """
    thresholds = catalog.policy.thresholds if catalog.policy is not None else {}
    # `.get(key, default)` only applies `default` when the key is *absent* —
    # config.py's real `_parse_router_config` always populates all 5 keys,
    # leaving the value `None` when unset in router.toml, so an explicit
    # None-coalesce is required here (not just a `.get` default) to avoid
    # `decision.gate_p > None` / `decision.confidence < None` raising.
    privacy_threshold = thresholds.get("privacy_threshold")
    if privacy_threshold is None:
        privacy_threshold = float("inf")
    confidence_floor = thresholds.get("confidence_floor")
    if confidence_floor is None:
        confidence_floor = 0.0
    long_context_tokens = thresholds.get("long_context_tokens")
    if long_context_tokens is None:
        long_context_tokens = float("inf")

    if decision.gate_p is not None and decision.gate_p > privacy_threshold:
        return "privacy_gate"
    if decision.confidence is not None and decision.confidence < confidence_floor:
        return "low_confidence"
    if token_estimate > long_context_tokens:
        return "long_context"
    return "policy"


def _usage_from_json_body(raw: bytes) -> UsageResult:
    """Usage for a non-streaming Anthropic response (module docstring's
    "Streaming vs. non-streaming usage extraction" note) — reads the single
    top-level `usage` object once; never guesses a `0` (mirrors `stream.py`'s
    own `UsageResult` convention).
    """
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        return UsageResult(input_tokens=None, output_tokens=None, cost_state="unknown")
    usage = obj.get("usage") if isinstance(obj, dict) else None
    if not isinstance(usage, dict):
        return UsageResult(input_tokens=None, output_tokens=None, cost_state="unknown")
    input_tokens = usage.get("input_tokens")
    output_tokens = usage.get("output_tokens")
    if input_tokens is None or output_tokens is None:
        return UsageResult(input_tokens=input_tokens, output_tokens=output_tokens, cost_state="unknown")
    return UsageResult(input_tokens=input_tokens, output_tokens=output_tokens, cost_state="known")


def _probe_reachable(base_url: str) -> bool:
    """One-time startup connectivity check (R2.5) — never called per-request.

    A non-2xx response still proves the host answered; only a
    connection-level failure (refused, DNS, timeout) counts as unreachable.
    """
    try:
        urllib.request.urlopen(base_url, timeout=_STARTUP_PROBE_TIMEOUT_S)
    except urllib.error.HTTPError:
        return True
    except (urllib.error.URLError, TimeoutError, OSError):
        return False
    return True


def _build_classifier(catalog: Catalog) -> Classifier:
    """Construct the configured classifier, falling back to `NullClassifier`
    (R2.5) rather than crashing the process: missing policy, an explicitly
    disabled backend, a malformed `base_url`, or an unreachable backend at
    startup all degrade to pass-through instead.
    """
    policy = catalog.policy
    if policy is None:
        logger.warning(
            "startup: no router policy loaded (%s) — pass-through mode, no classifier", catalog.cause
        )
        return NullClassifier()

    classifier_cfg = policy.classifier
    backend = classifier_cfg.get("backend", "jeff")
    if backend == "none":
        logger.warning("startup: [classifier].backend is 'none' — pass-through mode, no classifier")
        return NullClassifier()

    base_url = resolve_base_url(classifier_cfg.get("base_url", ""))
    try:
        classifier: Classifier = JeffClassifier(
            base_url=base_url,
            api_key_env=classifier_cfg.get("api_key_env", ""),
            timeout_ms=classifier_cfg.get("timeout_ms", 400),
            circuit_open_s=classifier_cfg.get("circuit_open_s", 60),
            scale_max=classifier_cfg.get("scale_max", 10),
            lanes=tuple(policy.lanes.keys()),
        )
    except ValueError as exc:
        logger.warning(
            "startup: classifier construction failed (%s) — pass-through mode, no classifier", exc
        )
        return NullClassifier()

    if not _probe_reachable(base_url):
        logger.warning(
            "startup: classifier at %s unreachable — pass-through mode, no classifier", base_url
        )
        return NullClassifier()
    return classifier


class RouterHandler(BaseHTTPRequestHandler):
    """HTTP handler owning the one fail-open guard (R1.1, 3.*, 4.*, 5.10).

    Bound to `127.0.0.1:8798` only by `main()`'s defaults — behind the
    sentinel, never the public port.
    """

    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        self._handle()

    def do_POST(self) -> None:
        self._handle()

    def do_PUT(self) -> None:
        self._handle()

    def do_PATCH(self) -> None:
        self._handle()

    def do_DELETE(self) -> None:
        self._handle()

    def do_HEAD(self) -> None:
        self._handle()

    def do_OPTIONS(self) -> None:
        self._handle()

    def _router_server(self) -> _RouterServer:
        """Narrow `self.server` from its inherited `BaseServer` type
        (tech.md "Protocol/base-class attribute invariance" — the same fix
        `sentinel.py`'s own `_sentinel_server()` applies).
        """
        assert isinstance(self.server, _RouterServer)
        return self.server

    def _handle(self) -> None:
        raw_body = self._read_body()
        headers = _forward_headers(self.headers)

        parsed = _parse_body(raw_body)
        if parsed is None:
            self._forward_raw(raw_body, headers)
            return
        body, baseline = parsed

        router = self._router_server()
        catalog, classifier, ledger = router.catalog, router.classifier, router.ledger

        decision: Decision | None = None
        target = baseline
        outcome = "passthrough"
        reason = "tool_loop"

        last_text = _last_user_text(body)
        if should_classify(last_text):
            token_estimate = _token_estimate(raw_body)
            try:
                # Deliberate, narrowly-scoped exception to the repo's
                # no-bare-except standard (CLAUDE.md) — R4.1 names classifier
                # error, timeout, malformed decision, policy miss, and
                # catalog miss as fail-open triggers; this single guard
                # catches all of them, matching design.md's `handle()`
                # pseudocode exactly. Same convention `classify.py`/
                # `ledger.py` already use for their own narrow exceptions.
                pending = ledger.pending_escalation(
                    baseline, catalog.rung_of, escalation_window_s=_escalation_window_s(catalog)
                )
                escalation = Escalation(active=pending.active, previous_model=pending.previous_model)
                decision = classifier.classify(last_text)
                target = select(decision, catalog, baseline, token_estimate, escalation)
                outcome = "applied" if target != baseline else "passthrough"
                reason = _derive_reason(catalog, decision, token_estimate)
            except ClassifierUnavailable as exc:
                logger.warning("fail-open: %s", exc)
                decision, target, outcome, reason = None, baseline, "failed_open", "no_classifier"
            except Exception as exc:  # noqa: BLE001 — intentional breadth, see R4.1 above
                logger.warning("fail-open: %s", exc)
                decision, target, outcome, reason = None, baseline, "failed_open", "error"

        stream_requested = bool(body.get("stream"))
        outbound_body = raw_body if target == baseline else _rewrite_model(body, target)

        response = self._open_upstream(outbound_body, headers)
        status = response.status
        assert status is not None  # tech.md "Optional narrowing": real once a response completes

        if target != baseline and status >= 400:
            # R5.10/R4.4: the rewrite, not the client, caused this rejection
            # (e.g. a model the installed Claude Code version can't use yet).
            # Nothing from this response reaches the client; retry once on
            # the identical, unmodified original bytes (baseline) and serve
            # that instead.
            logger.warning(
                "fail-open: upstream rejected selection %s (%s) — retrying on baseline %s",
                target,
                status,
                baseline,
            )
            response.close()
            response = self._open_upstream(raw_body, headers)
            status = response.status
            assert status is not None
            target, outcome, reason = baseline, "failed_open", "error"

        usage = self._relay(response, status, stream_requested=stream_requested)

        ledger.append(
            CallRecord(
                lane=decision.lane if decision is not None else "",
                score=decision.score if decision is not None else 0,
                gate_p=decision.gate_p if decision is not None else None,
                confidence=decision.confidence if decision is not None else None,
                baseline_model=baseline,
                selected_model=target,
                outcome=outcome,
                reason=reason,
                latency_ms=decision.latency_ms if decision is not None else 0,
                input_tokens=usage.input_tokens or 0,
                output_tokens=usage.output_tokens or 0,
                cost_state=usage.cost_state,
            ),
            rung_of=catalog.rung_of,
            escalation_window_s=_escalation_window_s(catalog),
        )

    def _read_body(self) -> bytes:
        length = self.headers.get("Content-Length")
        if length is None:
            return b""
        return self.rfile.read(int(length))

    def _upstream_url(self) -> str:
        catalog = self._router_server().catalog
        assert catalog.policy is not None  # main() refuses to start otherwise
        return f"{catalog.policy.upstream.rstrip('/')}{self.path}"

    def _open_upstream(self, body_bytes: bytes, headers: dict[str, str]):
        """Open one upstream request. `HTTPError` is itself response-shaped
        (status/headers/read()), not a connection failure — same convention
        sentinel.py's own `_open` documents; only a genuine connection-level
        failure (`URLError`/`TimeoutError`/`OSError`) is left to propagate
        (module docstring: "server.py should let a genuine upstream
        connection failure propagate as whatever status/exception naturally
        results").
        """
        request = urllib.request.Request(
            self._upstream_url(),
            data=body_bytes if body_bytes else None,
            method=self.command,
            headers=headers,
        )
        try:
            return urllib.request.urlopen(request)
        except urllib.error.HTTPError as exc:
            return exc

    def _relay(self, response, status: int, *, stream_requested: bool) -> UsageResult:
        """Stream the already-opened `response` to the client and harvest
        usage for the ledger. `status` is read by the caller before this is
        invoked — R3.3: never buffers a streaming response.
        """
        self.send_response(status)
        for key, value in response.headers.items():
            if key.lower() in _HOP_BY_HOP_HEADERS or key.lower() == "content-length":
                continue
            self.send_header(key, value)

        if stream_requested:
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            tee = StreamTee(write=self._write_chunk)
            while True:
                chunk = response.read1(_CHUNK_SIZE)
                if not chunk:
                    break
                tee.feed(chunk)
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
            return tee.usage()

        # Non-streaming: one complete JSON object is one deliverable unit —
        # not what R3.3's "no buffering" invariant guards against (module
        # docstring's "Streaming vs. non-streaming usage extraction" note).
        raw = response.read()
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)
        self.wfile.flush()
        return _usage_from_json_body(raw)

    def _forward_raw(self, raw_body: bytes, headers: dict[str, str]) -> None:
        """Verbatim relay for the no-model/malformed-body short-circuit —
        upstream's own framing (Content-Length or chunked), no SSE/usage
        parsing, no ledger entry (no baseline model exists to log against;
        see module docstring).
        """
        request = urllib.request.Request(
            self._upstream_url(),
            data=raw_body if raw_body else None,
            method=self.command,
            headers=headers,
        )
        try:
            response = urllib.request.urlopen(request)
        except urllib.error.HTTPError as exc:
            response = exc

        status = response.status
        assert status is not None
        self.send_response(status)
        for key, value in response.headers.items():
            if key.lower() in _HOP_BY_HOP_HEADERS or key.lower() == "content-length":
                continue
            self.send_header(key, value)

        content_length = response.headers.get("Content-Length")
        if content_length is not None:
            self.send_header("Content-Length", content_length)
            self.end_headers()
            self._copy_exact(response, int(content_length))
        else:
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            self._copy_chunked(response)

    def _copy_exact(self, response, remaining: int) -> None:
        while remaining > 0:
            chunk = response.read(min(_CHUNK_SIZE, remaining))
            if not chunk:
                break
            self.wfile.write(chunk)
            self.wfile.flush()
            remaining -= len(chunk)

    def _copy_chunked(self, response) -> None:
        while True:
            chunk = response.read1(_CHUNK_SIZE)
            if not chunk:
                break
            self._write_chunk(chunk)
        self.wfile.write(b"0\r\n\r\n")
        self.wfile.flush()

    def _write_chunk(self, chunk: bytes) -> None:
        self.wfile.write(f"{len(chunk):x}\r\n".encode("ascii"))
        self.wfile.write(chunk)
        self.wfile.write(b"\r\n")
        self.wfile.flush()

    def log_message(self, format: str, *args: object) -> None:
        logger.info("%s - %s", self.address_string(), format % args)


class _RouterServer(ThreadingHTTPServer):
    """Holds the per-process config a `BaseHTTPRequestHandler` has no
    constructor for — same pattern as sentinel.py's `_SentinelServer`.
    """

    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        server_address: tuple[str, int],
        handler_cls: type[BaseHTTPRequestHandler],
        *,
        catalog: Catalog,
        classifier: Classifier,
        ledger: Ledger,
    ) -> None:
        self.catalog = catalog
        self.classifier = classifier
        self.ledger = ledger
        super().__init__(server_address, handler_cls)


def build_server(
    *,
    host: str,
    port: int,
    catalog: Catalog,
    classifier: Classifier,
    ledger: Ledger,
) -> _RouterServer:
    """Construct (but do not start) a router server — the seam `server.test.sh`
    (task 7.2) uses, matching `sentinel.py`'s own `build_server()` pattern.
    """
    return _RouterServer(
        (host, port), RouterHandler, catalog=catalog, classifier=classifier, ledger=ledger
    )


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s router %(levelname)s %(message)s")

    parser = argparse.ArgumentParser(description="Router worker (R1.1, 3.*, 4.*, 5.10).")
    parser.add_argument("--router-toml", type=Path, default=DEFAULT_ROUTER_TOML_PATH)
    parser.add_argument("--catalogue-path", type=Path, default=None)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args(argv)

    catalog = load_catalog(args.router_toml, args.catalogue_path)
    if catalog.policy is None or not catalog.policy.upstream:
        # Startup-fatal, not a per-request fail-open path — a worker with no
        # discoverable upstream cannot satisfy R4.* no matter what it does
        # per request (same posture sentinel.py's own `UpstreamNotConfigured`
        # takes for its half of this exact problem).
        logger.error(
            "fatal: %s", catalog.cause or f"[router].upstream not configured in {args.router_toml}"
        )
        return 1
    if catalog.pass_through:
        logger.warning("startup: catalog in pass-through mode (%s)", catalog.cause)

    classifier = _build_classifier(catalog)
    ledger = Ledger()

    server = build_server(
        host=args.host, port=args.port, catalog=catalog, classifier=classifier, ledger=ledger
    )
    logger.info("listening on %s:%s, upstream=%s", args.host, args.port, catalog.policy.upstream)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
