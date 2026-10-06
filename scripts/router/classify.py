"""scripts/router/classify.py — local classifier client, circuit breaker.

Drives a local, loopback-only `jeff` instance (the Jev System One API, served
on-machine — see `specs/model-router/docs/adr/0001-local-system-one-classifier-not-jev.md`).
One HTTP POST carries all three Jev-compatible question types — lane
(choice), difficulty (score), privacy gate (null) — so three answers cost
roughly one answer's latency (R2.2). `classify(text) -> Decision` either
returns a typed answer or fails fast: a wall-clock budget breach, a refused
connection, or a malformed response all raise the one named
`ClassifierUnavailable` exception with a `reason` attribute distinguishing
*why* (R2.4) — never a fabricated `Decision`.

`Decision` here is the real, frozen dataclass this module owns; it
structurally satisfies `policy.py`'s `DecisionLike` Protocol (read-only
properties, compatible field types) without importing it — Rule of Three:
two independent readers of one shape is not a reason to couple the two
modules (see `policy.py`'s own `DecisionLike` docstring, which makes the same
choice in the other direction).

NEEDS-USER — wire schema not discoverable in-repo: `jeff`'s exact
`/v1/systemone` request/response JSON shape is not vendored, captured, or
documented anywhere in this repository (confirmed by search of `specs/`,
`docs/`, and `design.md`; only the endpoint path and question-type names are
recorded). The request/response shape implemented below —
`{"text", "lanes", "scale_max"}` in, `{"lane", "score", "gate_p",
"confidence"}` out — is this implementation's own reasonable, documented
placeholder, not a verified contract. It must be checked against a real
`jeff` instance (task 8 setup, or an integration test) before this is
trusted in production. Flagged for the choices ledger rather than guessed at
silently.

Circuit breaker state (a failure counter and an open-until timestamp) lives
on the `JeffClassifier` instance only — nothing persisted, nothing shared
across processes (design.md "Classifier / classify.py" implementation
notes).
"""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Protocol
from urllib.parse import urlsplit

# Hosts `JeffClassifier` accepts as loopback (R2.1). Anything else fails
# construction rather than silently trusting a config value that could point
# classification traffic — and the bearer key — at a non-local host.
_LOOPBACK_HOSTS = frozenset({"127.0.0.1", "localhost", "::1"})

# R2.4/circuit breaker: this many consecutive failures opens the circuit.
_CONSECUTIVE_FAILURES_TO_OPEN = 3


class ClassifierUnavailable(Exception):
    """Raised whenever `classify()` cannot produce a real `Decision`.

    `reason` distinguishes *why*, for whoever logs it later (R2.4) — never
    raised with a fabricated `Decision` attached (R2.5):

    - ``"circuit_open"``   — suppressed without attempting a call.
    - ``"timeout"``        — wall-clock budget (`timeout_ms`) breached.
    - ``"unreachable"``    — connection refused, DNS failure, etc.
    - ``"http_error"``     — classifier responded with a non-2xx status.
    - ``"bad_response"``   — malformed JSON or an out-of-range/unknown field.
    - ``"no_backend"``     — `NullClassifier`: no backend is configured.
    """

    def __init__(self, reason: str, message: str | None = None) -> None:
        self.reason = reason
        super().__init__(message or reason)


@dataclass(frozen=True)
class Decision:
    """One classifier response: Lane, Difficulty Score, Gate Probability,
    Confidence (see `specs/model-router/CONTEXT.md`'s language glossary),
    plus the measured call latency.
    """

    lane: str  # from config; e.g. chitchat | simple | rewrite | code | reasoning
    score: int  # 0..scale_max, difficulty
    gate_p: float  # 0..1, privacy gate "yes" probability
    confidence: float  # 0..1, winning choice probability
    latency_ms: int


class Classifier(Protocol):
    def classify(self, text: str) -> Decision: ...


def should_classify(text: str) -> bool:
    """False for a turn with no user text — a tool-loop continuation made
    entirely of `tool_result` content. The caller (the Router's request
    handler, `server.py`) must skip calling `Classifier.classify()` entirely
    in that case rather than invoke it and discard the answer — that is what
    keeps the tool-loop path at zero added latency and makes it `PASS_THROUGH`
    by definition rather than a policy decision (design.md "Classifier /
    classify.py" implementation notes).
    """
    return bool(text) and bool(text.strip())


def resolve_base_url(configured_base_url: str) -> str:
    """R2.3: `TYPESAFE_BASE_URL`, when set, overrides `classifier.base_url`
    from `router.toml` — `jeff`'s own drop-in mechanism for the official
    `typesafe-sdk` (see `specs/model-router/prefs.md`'s research findings and
    ADR-0001). Resolved once, at construction time, by whoever builds a
    `JeffClassifier` — not re-read per call, since R2.2's "read at call time"
    language is specific to the bearer key, not this override.
    """
    return os.environ.get("TYPESAFE_BASE_URL") or configured_base_url


class NullClassifier:
    """Selected when the configured backend is unavailable (R2.5).

    Always raises `ClassifierUnavailable` — never fabricates a `Decision`.
    """

    def classify(self, text: str) -> Decision:
        raise ClassifierUnavailable(
            "no_backend", "no classifier backend is configured or reachable"
        )


class JeffClassifier:
    """Drives a loopback-only `jeff` instance over plain HTTP (`urllib`,
    stdlib only — no `typesafe-sdk` dependency).
    """

    def __init__(
        self,
        base_url: str,
        api_key_env: str,
        timeout_ms: int,
        circuit_open_s: int,
        scale_max: int,
        lanes: tuple[str, ...] = (),
    ) -> None:
        host = urlsplit(base_url).hostname
        if host is None or host.lower() not in _LOOPBACK_HOSTS:
            raise ValueError(
                f"classifier base_url must be loopback-only, got {base_url!r} (R2.1)"
            )
        self._base_url = base_url.rstrip("/")
        self._api_key_env = api_key_env
        self._timeout_s = timeout_ms / 1000.0
        self._circuit_open_s = circuit_open_s
        self._scale_max = scale_max
        self._lanes = tuple(lanes)
        self._consecutive_failures = 0
        self._circuit_open_until: float | None = None

    def classify(self, text: str) -> Decision:
        if self._circuit_is_open():
            raise ClassifierUnavailable(
                "circuit_open", "circuit open after repeated classifier failures"
            )
        started = time.monotonic()
        try:
            decision = self._call(text, started)
        except ClassifierUnavailable:
            self._record_failure()
            raise
        self._consecutive_failures = 0
        return decision

    def _circuit_is_open(self) -> bool:
        """True while suppressing calls. Auto-closes (one probe allowed
        through) once `circuit_open_s` has elapsed since the circuit opened.
        """
        if self._circuit_open_until is None:
            return False
        if time.monotonic() >= self._circuit_open_until:
            self._circuit_open_until = None
            return False
        return True

    def _record_failure(self) -> None:
        self._consecutive_failures += 1
        if self._consecutive_failures >= _CONSECUTIVE_FAILURES_TO_OPEN:
            self._circuit_open_until = time.monotonic() + self._circuit_open_s
            self._consecutive_failures = 0

    def _call(self, text: str, started: float) -> Decision:
        # NEEDS-USER (see module docstring): placeholder wire shape, not a
        # verified `jeff` contract. `lanes`/`scale_max` tell the classifier
        # how to interpret the choice/score question types; the privacy-gate
        # ("null") question type is assumed always-answered, not toggled
        # per request.
        payload = json.dumps(
            {"text": text, "lanes": list(self._lanes), "scale_max": self._scale_max}
        ).encode("utf-8")
        request = urllib.request.Request(
            f"{self._base_url}/v1/systemone",
            data=payload,
            method="POST",
            headers={"Content-Type": "application/json"},
        )
        api_key = os.environ.get(self._api_key_env)  # R2.2: value read at call time, never from toml
        if api_key:
            request.add_header("Authorization", f"Bearer {api_key}")

        try:
            with urllib.request.urlopen(request, timeout=self._timeout_s) as response:
                raw = response.read()
        except TimeoutError as exc:
            raise ClassifierUnavailable(
                "timeout", f"classifier exceeded {self._timeout_s * 1000:.0f}ms budget"
            ) from exc
        except urllib.error.HTTPError as exc:
            raise ClassifierUnavailable(
                "http_error", f"classifier returned HTTP {exc.code}"
            ) from exc
        except urllib.error.URLError as exc:
            raise ClassifierUnavailable(
                "unreachable", f"classifier unreachable: {exc.reason}"
            ) from exc

        latency_ms = int((time.monotonic() - started) * 1000)
        return self._parse(raw, latency_ms)

    def _parse(self, raw: bytes, latency_ms: int) -> Decision:
        try:
            data = json.loads(raw)
            lane = str(data["lane"])
            score = int(data["score"])
            gate_p = float(data["gate_p"])
            confidence = float(data["confidence"])
        except (json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
            # Deliberate broad-ish catch: any malformed-response shape becomes
            # one named failure (R2.4) rather than letting a parsing exception
            # escape uncaught — CLAUDE.md's no-bare-except rule names this as
            # the one case requiring a comment, same as server.py's R4.1 guard.
            raise ClassifierUnavailable(
                "bad_response", f"malformed classifier response: {exc}"
            ) from exc

        # "Classifier nonsense" (design.md): unknown lane or out-of-range
        # score/probability validates-rejects rather than reaching policy.
        if self._lanes and lane not in self._lanes:
            raise ClassifierUnavailable("bad_response", f"unknown lane {lane!r}")
        if not (0 <= score <= self._scale_max):
            raise ClassifierUnavailable(
                "bad_response", f"score {score} out of range 0..{self._scale_max}"
            )
        if not (0.0 <= gate_p <= 1.0):
            raise ClassifierUnavailable("bad_response", f"gate_p {gate_p} out of range 0..1")
        if not (0.0 <= confidence <= 1.0):
            raise ClassifierUnavailable(
                "bad_response", f"confidence {confidence} out of range 0..1"
            )

        return Decision(
            lane=lane, score=score, gate_p=gate_p, confidence=confidence, latency_ms=latency_ms
        )
