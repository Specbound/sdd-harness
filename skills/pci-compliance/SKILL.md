---
name: pci-compliance
description: "Apply PCI DSS v4.0.1 to payment systems — scope reduction, SAQ selection, prohibited data, PAN masking and storage, key management, access control, and audit logging. Use when building or reviewing anything that touches card data, or when choosing an integration pattern to minimise compliance scope."
risk: unknown
source: community
---

# PCI Compliance

PCI DSS **v4.0.1** for engineers: how to keep card data out of your systems, and what
the standard requires of the parts that cannot avoid it.

**This skill ships as `SKILL.md` only — no bundled reference, asset, or script files.
Everything below is meant to be read and inlined, not opened from a path.**

## Use when

- Designing or reviewing a payment flow, to keep PCI scope as small as possible
- Choosing an SAQ, or preparing for an assessment
- Reviewing code that stores, logs, transmits, or displays card data
- Auditing key management, access control, or audit logging in a cardholder data environment

## Version check — do this first

**v4.0.1 is the current standard.** v3.2.1 retired 31 March 2024 and v4.0 was superseded
by v4.0.1. Most PCI material on the web — and the previous version of this skill —
describes v3.2.1, which is recognisable by the old requirement titles ("Install and
maintain a firewall configuration", "Do not use vendor-supplied defaults"). If you see
those, the source is out of date by two revisions. The v4 future-dated requirements all
became mandatory on **31 March 2025**, so nothing in v4 is "upcoming" any more.

Always confirm requirement text against the current document at
`pcisecuritystandards.org`. Nothing below replaces it, and the SAQs in particular changed
between v4.0 and v4.0.1.

## Who enforces this

The Security Standards Council writes PCI DSS but does not enforce it. **Your acquirer
(or payment facilitator) does**, and the merchant levels that decide whether you file an
SAQ or a Report on Compliance are defined by each **card brand** — Visa's thresholds are
not identical to Mastercard's. Roughly: Level 1 is >6M transactions/year for a brand and
requires a QSA-led ROC; lower levels self-assess with an SAQ plus quarterly ASV scans.

Do not derive your obligations from a table on the internet, this one included. Ask your
acquirer which level and which SAQ they expect. Getting that answer first can save
months of work on the wrong questionnaire.

## The 12 requirements (v4.0.1 titles)

1. Install and maintain network security controls
2. Apply secure configurations to all system components
3. Protect stored account data
4. Protect cardholder data with strong cryptography during transmission over open, public networks
5. Protect all systems and networks from malicious software
6. Develop and maintain secure systems and software
7. Restrict access to system components and cardholder data by business need to know
8. Identify users and authenticate access to system components
9. Restrict physical access to cardholder data
10. Log and monitor all access to system components and cardholder data
11. Test security of systems and networks regularly
12. Support information security with organizational policies and programs

Requirements most likely to bite an engineering team in v4: **8.4.2** (MFA for *all*
access into the CDE, not just remote or admin), **12.3.1** (targeted risk analysis
documenting any requirement you meet on a custom frequency), **10.4.1.1** (automated log
review, not a human promising to look), and **6.4.3 / 11.6.1** (payment-page script
inventory and tamper detection — the Magecart controls).

## Start here: reduce scope, then comply

Everything that stores, processes, or transmits account data is in scope, plus anything
that can affect its security. The cheapest compliance work is the work you delete.

| Integration | Card data touches | SAQ | Relative effort |
|---|---|---|---|
| Hosted payment page / redirect (Stripe Checkout, PayPal, Payment Links) | Processor only | **A** | Lowest |
| Processor-hosted iframe fields (Stripe Elements, Adyen Components) | Your page, not your server | **A-EP** | Moderate — you own the page's script integrity |
| Card fields posted to your server | Your servers | **D** | Highest — full standard |

The jump from A-EP to D is the expensive one and it is usually taken by accident: one
"just this once" endpoint that accepts a raw PAN pulls your whole application into the
cardholder data environment. Treat any code path that can receive a PAN as an
architecture decision, not an implementation detail.

Note that A-EP and D carry 6.4.3 and 11.6.1 — you must inventory every script on the
payment page, justify it, and detect unauthorised change. If you are on SAQ A, confirm
the current v4.0.1 eligibility criteria, which changed from v4.0; do not assume a
pre-2025 reading still applies.

## Account data: what you may never keep

**Sensitive authentication data must not be stored after authorisation — ever, even
encrypted.** This is the rule with no exceptions and no compensating control.

| Never store (post-auth) | May store (protected) |
|---|---|
| Full track data (magnetic stripe / chip equivalent) | PAN — rendered unreadable (3.5.1) |
| CVV / CVC2 / CVV2 / CID | Cardholder name |
| PIN or PIN block | Expiration date |
| | Service code |

The three "may store" fields are only protectable at all when stored *with* a PAN that
is itself protected; stored alone they are out of scope but still worth minimising.

### Keeping SAD out of logs

A log sanitiser is a backstop, not a control. The control is never putting card data
into a structure that gets logged. If you do write one, a recursive allowlist beats the
usual shallow denylist:

```python
import re

PROHIBITED = {"cvv", "cvv2", "cvc", "cvc2", "cid", "pin", "pin_block", "track_data"}
PAN_KEYS = {"pan", "card_number", "cardnumber", "account_number"}
PAN_RE = re.compile(r"\b\d{13,19}\b")


class ProhibitedDataError(Exception):
    """Raised when sensitive authentication data reaches a storage or log boundary."""


def mask_pan(pan: str) -> str:
    """BIN + last four is the MAXIMUM PCI DSS 3.4.1 allows on display. Less is fine."""
    digits = re.sub(r"\D", "", pan)
    if len(digits) < 13:
        return "*" * len(digits)           # not a PAN; do not leak it either
    return f"{digits[:6]}{'*' * (len(digits) - 10)}{digits[-4:]}"


def sanitize(value):
    """Deep-sanitise before logging. A shallow dict.copy() leaves nested dicts
    sharing references with the original — the nested PAN is logged untouched."""
    if isinstance(value, dict):
        out = {}
        for k, v in value.items():
            key = k.lower()
            if key in PROHIBITED:
                continue                    # dropped, never masked
            out[k] = mask_pan(str(v)) if key in PAN_KEYS else sanitize(v)
        return out
    if isinstance(value, (list, tuple)):
        return type(value)(sanitize(v) for v in value)
    if isinstance(value, str):
        return PAN_RE.sub(lambda m: mask_pan(m.group()), value)
    return value


def assert_no_prohibited(data: dict) -> None:
    """Call at every persistence boundary. Fails loudly — a silent drop here
    hides the bug that put SAD in the object in the first place."""
    found = {k for k in data if k.lower() in PROHIBITED}
    if found:
        raise ProhibitedDataError(f"prohibited fields at storage boundary: {sorted(found)}")
```

Masking for *display* (3.4.1) and rendering unreadable for *storage* (3.5.1) are
different requirements with different rules. A masked PAN in a log is still fine; a
masked PAN is **not** an acceptable storage protection unless the truncation is
irreversible and no other system holds the rest.

## Tokenisation — use the processor's

The correct answer for almost every team: let the processor hold the card and keep only
its token. Your database stores a customer id and a payment-method id, and your SAQ
stays small.

```python
import stripe   # PaymentIntents + Payment Element. The Charges and Tokens APIs are
                # legacy, and collecting raw card fields to call createToken puts card
                # data on your page — which moves you from SAQ A to A-EP for no gain.

stripe.api_key = os.environ["STRIPE_SECRET_KEY"]

def start_payment(customer_id: str, amount_minor: int, currency: str = "usd"):
    intent = stripe.PaymentIntent.create(
        amount=amount_minor,                 # minor units, set server-side
        currency=currency,
        customer=customer_id,
        automatic_payment_methods={"enabled": True},
        setup_future_usage="off_session",    # token for reuse; you never see the PAN
    )
    return intent.client_secret              # the browser confirms with Payment Element


def attach_saved_method(customer_id: str, payment_method_id: str):
    stripe.PaymentMethod.attach(payment_method_id, customer=customer_id)
    # Persist these two ids only. Never the PAN, never the CVV, not even briefly.
    return {"customer_id": customer_id, "payment_method_id": payment_method_id}
```

**Building your own token vault puts you in SAQ D** and makes you responsible for
requirements 3.5 through 3.7 in full: key-encrypting keys separate from data-encrypting
keys, documented cryptoperiods and rotation, split knowledge and dual control for any
manual clear-text key operation, and key storage in an HSM or an equivalent
cryptographic device. An in-process dictionary with a single hard-coded key is not a
vault, whatever it is named.

If you genuinely must store PANs, use a KMS/HSM-backed envelope scheme with AES-256-GCM
data keys. Note that Python's `cryptography.fernet` is AES-**128**-CBC with HMAC — fine
for many purposes, but do not describe it as AES-256:

```python
import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

class EnvelopeCipher:
    """Data-encrypting key comes from a KMS per operation and is never persisted.
    The nonce is random per message and stored alongside the ciphertext — reusing
    a nonce with the same key destroys AES-GCM's guarantees entirely."""

    def __init__(self, data_key: bytes):
        if len(data_key) != 32:
            raise ValueError("AES-256-GCM requires a 32-byte key")
        self._aes = AESGCM(data_key)

    def encrypt(self, plaintext: str, aad: bytes) -> bytes:
        nonce = os.urandom(12)
        # aad binds the ciphertext to its row (e.g. the customer id), so a swapped
        # row fails to decrypt instead of silently returning another customer's PAN.
        return nonce + self._aes.encrypt(nonce, plaintext.encode(), aad)

    def decrypt(self, blob: bytes, aad: bytes) -> str:
        return self._aes.decrypt(blob[:12], blob[12:], aad).decode()
```

## Access control and audit logging

Requirement 7 (need to know), 8 (authenticate, **MFA for all CDE access** under 8.4.2),
and 10 (log every access to account data) meet in the same place: the decorator in front
of anything that can read card data.

```python
import json
import logging
from datetime import datetime, timezone
from functools import wraps
from flask import request, session

audit = logging.getLogger("pci.audit")   # ship to append-only, off-host storage


def _audit(**fields):
    audit.info(json.dumps({
        # utcnow() is deprecated since Python 3.12 and returns a naive datetime —
        # an audit trail without an unambiguous timezone is hard to defend.
        "ts": datetime.now(timezone.utc).isoformat(),
        # remote_addr behind a proxy records the proxy. Requirement 10.2.2 wants the
        # origin, so read the trusted forwarded header your edge actually sets.
        "source_ip": request.headers.get("X-Forwarded-For", request.remote_addr),
        **fields,
    }))


def require_cde_access(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        user = session.get("user")
        if not user or "pci_access" not in user.get("roles", []):
            # Log the denial too — 10.2.1.4 wants invalid access attempts.
            _audit(event="access_denied", user=(user or {}).get("id"), resource=f.__name__)
            return {"error": "forbidden"}, 403
        if not user.get("mfa_verified"):
            _audit(event="mfa_required", user=user["id"], resource=f.__name__)
            return {"error": "mfa_required"}, 403

        _audit(event="cde_access", user=user["id"], resource=f.__name__, action=request.method)
        return f(*args, **kwargs)
    return wrapper
```

Logs must be protected from the people they record (10.3.2), retained **12 months with
3 months immediately available** (10.5.1), and reviewed by automated mechanisms
(10.4.1.1). Append-only storage in a separate account, with no delete permission for
CDE operators, satisfies the intent far more cheaply than arguing about it later.

## Transport

TLS 1.2 minimum, 1.3 preferred; early TLS is prohibited. Enforce HSTS, disable
renegotiation, and verify certificates on every outbound call — a `verify=False` on a
request to your processor is a requirement 4 failure.

```python
app.config.update(
    SESSION_COOKIE_SECURE=True,
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Strict",
)
```

Never send a PAN over email, chat, SMS, or a ticketing system. That includes screenshots
pasted into an incident channel — the most common way account data escapes the CDE in
practice.

## Validation activities you cannot do in code

- **Quarterly external vulnerability scans by an ASV** (11.3.2), plus internal scans and
  rescans until clean
- **Annual penetration testing**, external and internal, with segmentation testing to
  prove your CDE boundary holds (11.4.x)
- **Targeted risk analysis** documents for anything on a custom frequency (12.3.1)
- **Annual SAQ or ROC**, plus an Attestation of Compliance filed with your acquirer
- **Incident response plan** that is tested, not just written (12.10.x)

## Common violations

1. Storing CVV "temporarily" for retries — prohibited at any duration
2. PAN in application logs, exception traces, or APM payload capture
3. Reversible encryption described as tokenisation
4. One shared key, never rotated, committed next to the data it protects
5. MFA on the VPN only, not on access into the CDE itself (8.4.2)
6. Audit logs writable — or deletable — by the operators they record
7. A new endpoint accepting raw PANs, silently moving the whole app into SAQ D
8. Treating the annual assessment as the control; the requirements are continuous
