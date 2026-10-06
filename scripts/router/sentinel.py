"""scripts/router/sentinel.py — trivial, dependency-free front door (R4.5, R4.5a).

Binds `127.0.0.1:8799`, the address `ANTHROPIC_BASE_URL` points at. On every request it
tries the worker at `127.0.0.1:8798` first with a short connect/read timeout; connection
refused, timeout, or any other connection-level failure falls through to the discovered
upstream directly, unmodified, with no classification/rewrite attempted here at all —
that is the worker's job (task 7's `server.py`), a different process from this one.

Key Decision 1a (design.md): two processes, not one, so a crash in the classifier/
policy/ledger logic can never take the public port down with it. This module therefore
imports **nothing** beyond stdlib, and deliberately does **not** import `config.py`,
`policy.py`, `classify.py`, or `ledger.py` — even though `config.py` itself is
stdlib-only (`tomllib`). The point is zero shared failure surface, not stdlib purity: if
`config.py` ever grows a bug that raises at import time or on a malformed catalogue,
that must never be able to take this process down too. The `[router]` table's `port`/
`upstream` keys are read directly with `tomllib` below, duplicating the ~2 lines
`config.py`'s `load_policy()` already has — the deliberate, named tradeoff.

A missing/unparseable `router.toml`, or an empty `upstream`, is startup-time fatal (log
and exit), not a per-request fail-open path: a sentinel that cannot find its own
upstream cannot satisfy R4.5 no matter what it does per request.
"""

from __future__ import annotations

import argparse
import logging
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import tomllib

logger = logging.getLogger("sentinel")

# Mirrors ledger.py's `Path.home() / ".sdd-router" / ...` convention exactly — not
# imported from ledger.py, just the same literal pattern independently (Key Decision 1a).
DEFAULT_ROUTER_TOML_PATH = Path.home() / ".sdd-router" / "router.toml"

SENTINEL_HOST = "127.0.0.1"
DEFAULT_SENTINEL_PORT = 8799
WORKER_HOST = "127.0.0.1"
WORKER_PORT = 8798

# R4.5a: bounds the client-visible outage window for a dead worker to one request's
# connect/read timeout, not however long the OS service manager takes to restart it.
WORKER_TIMEOUT_S = 0.150

_CHUNK_SIZE = 65536

# Headers that are specific to one hop and must never be copied verbatim onto the next
# hop's request/response — "Host" too, since the target differs per hop (worker vs.
# upstream) and urllib derives the correct one from the target URL on its own.
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


class UpstreamNotConfigured(RuntimeError):
    """`router.toml` is missing/unparseable, or declares no `upstream` — startup-fatal."""


def load_router_settings(router_toml_path: Path) -> tuple[int, str]:
    """Read only the `[router]` table's `port`/`upstream` keys with `tomllib`.

    Deliberately duplicated from `config.py`'s `load_policy()` rather than imported
    from it (Key Decision 1a — zero shared failure surface with the worker's logic).

    Returns `(port, upstream)`. `port` falls back to `DEFAULT_SENTINEL_PORT` when the
    key is absent, matching `templates/router.toml.template`'s shipped default. An
    empty/missing `upstream`, or a missing/unparseable file, raises
    `UpstreamNotConfigured` — a sentinel with no upstream cannot do its one job.
    """
    try:
        raw = tomllib.loads(router_toml_path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise UpstreamNotConfigured(f"router.toml not found: {router_toml_path}") from exc
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise UpstreamNotConfigured(f"router.toml unparseable: {exc}") from exc

    router_tbl = raw.get("router")
    if not isinstance(router_tbl, dict):
        router_tbl = {}

    upstream = router_tbl.get("upstream") or ""
    if not upstream:
        raise UpstreamNotConfigured(f"[router] upstream is empty in {router_toml_path}")

    port = router_tbl.get("port", DEFAULT_SENTINEL_PORT)
    return int(port), str(upstream)


def _forward_headers(headers) -> dict[str, str]:
    """Copy a client/upstream header set, dropping hop-by-hop headers (RFC 7230 6.1)."""
    return {k: v for k, v in headers.items() if k.lower() not in _HOP_BY_HOP_HEADERS}


def _open(url: str, method: str, headers: dict[str, str], body: bytes, timeout: float | None):
    """Open `url` and return a response-like object exposing `.status`/`.headers`/`.read()`.

    `HTTPError` is itself response-shaped (same three members, confirmed by direct
    probe against this Python's `urllib`) — a peer answering with a non-2xx status is
    returned here, not raised, since that is still "the peer answered", not a
    connection-level failure. Only `URLError`/`TimeoutError`/`OSError` propagate to the
    caller, which is exactly the set that should trigger sentinel's fallback.
    """
    request = Request(url, data=body if body else None, method=method, headers=headers)
    try:
        return urlopen(request, timeout=timeout)
    except HTTPError as exc:
        return exc


class SentinelHandler(BaseHTTPRequestHandler):
    """Pure byte-forwarding proxy with a two-tier fallback.

    No classification, no policy, no ledger writes, no retry-on-model-rejection — all
    of that is task 7's `server.py`'s job, a different process this one does not
    import and must keep working without.
    """

    protocol_version = "HTTP/1.1"
    server: _SentinelServer  # narrows the type ThreadingHTTPServer gives at runtime

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

    def _handle(self) -> None:
        body = self._read_body()
        headers = _forward_headers(self.headers)

        try:
            response = _open(self._worker_url(), self.command, headers, body, self.server.worker_timeout_s)
        except (URLError, TimeoutError, OSError) as exc:
            logger.warning("worker unreachable (%s) — falling through to upstream", exc)
            try:
                response = _open(self._upstream_url(), self.command, headers, body, None)
            except (URLError, TimeoutError, OSError) as upstream_exc:
                self.send_error(502, f"upstream unreachable: {upstream_exc}")
                return

        self._relay(response)

    def _read_body(self) -> bytes:
        length = self.headers.get("Content-Length")
        if length is None:
            return b""
        return self.rfile.read(int(length))

    def _worker_url(self) -> str:
        return f"http://{self.server.worker_host}:{self.server.worker_port}{self.path}"

    def _upstream_url(self) -> str:
        return f"{self.server.upstream.rstrip('/')}{self.path}"

    def _relay(self, response) -> None:
        """Stream `response` back to the client verbatim — body bytes untouched.

        `response.read()` already de-chunks a chunked wire body, so this re-frames the
        *outgoing* side itself (chunked, when the peer's length is unknown) rather than
        forwarding a stale `Transfer-Encoding` header next to an already-decoded body,
        which would corrupt the client's framing.
        """
        self.send_response(response.status)
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
            chunk = response.read(_CHUNK_SIZE)
            if not chunk:
                break
            self.wfile.write(f"{len(chunk):x}\r\n".encode("ascii"))
            self.wfile.write(chunk)
            self.wfile.write(b"\r\n")
            self.wfile.flush()
        self.wfile.write(b"0\r\n\r\n")
        self.wfile.flush()

    def log_message(self, format_str: str, *args: object) -> None:
        logger.info("%s - %s", self.address_string(), format_str % args)


class _SentinelServer(ThreadingHTTPServer):
    """Holds the per-request config a `BaseHTTPRequestHandler` has no constructor for."""

    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        server_address: tuple[str, int],
        handler_cls: type[BaseHTTPRequestHandler],
        *,
        upstream: str,
        worker_host: str,
        worker_port: int,
        worker_timeout_s: float,
    ) -> None:
        self.upstream = upstream
        self.worker_host = worker_host
        self.worker_port = worker_port
        self.worker_timeout_s = worker_timeout_s
        super().__init__(server_address, handler_cls)


def build_server(
    *,
    host: str,
    port: int,
    upstream: str,
    worker_host: str = WORKER_HOST,
    worker_port: int = WORKER_PORT,
    worker_timeout_s: float = WORKER_TIMEOUT_S,
) -> _SentinelServer:
    """Construct (but do not start) a sentinel server — the seam `sentinel.test.sh` uses."""
    return _SentinelServer(
        (host, port),
        SentinelHandler,
        upstream=upstream,
        worker_host=worker_host,
        worker_port=worker_port,
        worker_timeout_s=worker_timeout_s,
    )


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s sentinel %(levelname)s %(message)s")

    parser = argparse.ArgumentParser(description="Sentinel front door (R4.5, R4.5a).")
    parser.add_argument("--router-toml", type=Path, default=DEFAULT_ROUTER_TOML_PATH)
    parser.add_argument("--host", default=SENTINEL_HOST)
    parser.add_argument("--port", type=int, default=None)
    parser.add_argument("--worker-host", default=WORKER_HOST)
    parser.add_argument("--worker-port", type=int, default=WORKER_PORT)
    parser.add_argument("--worker-timeout-s", type=float, default=WORKER_TIMEOUT_S)
    args = parser.parse_args(argv)

    try:
        configured_port, upstream = load_router_settings(args.router_toml)
    except UpstreamNotConfigured as exc:
        logger.error("fatal: %s", exc)
        return 1

    # Explicit narrowing (tech.md: "Optional narrowing") — `args.port` is `int | None`
    # from argparse's default; never used before this check resolves it to `int`.
    port = args.port if args.port is not None else configured_port

    server = build_server(
        host=args.host,
        port=port,
        upstream=upstream,
        worker_host=args.worker_host,
        worker_port=args.worker_port,
        worker_timeout_s=args.worker_timeout_s,
    )
    logger.info(
        "listening on %s:%s, worker=%s:%s, upstream=%s",
        args.host,
        port,
        args.worker_host,
        args.worker_port,
        upstream,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
