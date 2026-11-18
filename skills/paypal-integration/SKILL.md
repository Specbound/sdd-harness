---
name: paypal-integration
description: "Integrate PayPal payments with the Orders v2 REST API — server-side order creation and capture, webhook signature verification, subscriptions, and refunds. Use when adding PayPal checkout, handling PayPal webhooks, or debugging a PayPal capture or notification flow."
risk: unknown
source: community
---

# PayPal Integration

Server-authoritative PayPal checkout using the **Orders v2** REST API, with webhook
verification, subscriptions, and refunds.

**This skill ships as `SKILL.md` only — no bundled reference, asset, or script files.
Everything below is meant to be read and inlined, not opened from a path.**

## Use when

- Adding PayPal as a checkout option (one-time or subscription)
- Verifying and processing PayPal webhooks
- Implementing refunds or handling disputes
- Debugging a capture that succeeded on the client but never reached your database

## Version check — do this first

Two deprecations decide most of what the code below looks like:

| Deprecated | Use instead |
|---|---|
| `paypalrestsdk` (PayPal-Python-SDK) — archived, wraps the v1 Payments API | `paypal-server-sdk`, or plain `requests` against the v2 REST API |
| **IPN** (`cmd=_notify-validate`, `payment_status`, `txn_id`) | **Webhooks** (`/v1/notifications/verify-webhook-signature`, `PAYMENT.CAPTURE.COMPLETED`) |
| Payments v1 (`/v1/payments/payment`, `Payment.execute`) | Orders v2 (`/v2/checkout/orders`) |

The failure this prevents: a frontend that creates a **v2 Order** and a backend that
calls `Payment.find(orderID)` from the v1 SDK. Those are different ID namespaces — the
lookup 404s, and because the client already captured, the money moves while your
backend records nothing. If you are reading older PayPal code, that mismatch is the
first thing to check.

```bash
pip show paypalrestsdk   # if this resolves, the code around it is v1 and needs porting
```

## The two rules that prevent lost money

1. **The server sets the amount.** Never create an order from a client-supplied price.
2. **The server captures.** Never use `actions.order.capture()` in the browser.

A client-side capture means PayPal has the money and your backend may never hear about
it — the fetch that was supposed to tell it can be dropped, blocked, or closed with the
tab. It also lets anyone replay the capture call, and it is the source of the common
`ORDER_ALREADY_CAPTURED` (422) error when a backend then tries to capture too.

## Frontend — hand off to your server at both ends

```html
<div id="paypal-button-container"></div>
<script src="https://www.paypal.com/sdk/js?client-id=YOUR_CLIENT_ID&currency=USD&intent=capture"></script>
<script>
  paypal.Buttons({
    // No amount here. The server knows what the cart costs.
    createOrder: () =>
      fetch('/api/paypal/orders', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({cartId: CART_ID})
      }).then(r => r.json()).then(d => d.id),

    onApprove: (data, actions) =>
      fetch(`/api/paypal/orders/${data.orderID}/capture`, {method: 'POST'})
        .then(r => r.json())
        .then(details => {
          // A declined funding source is recoverable — let the buyer pick another.
          if (details.error === 'INSTRUMENT_DECLINED') return actions.restart();
          if (details.error) throw new Error(details.error);
          window.location.href = '/order/confirmed';
        }),

    onError: (err) => { console.error(err); showCheckoutFailureUI(); }
  }).render('#paypal-button-container');
</script>
```

`intent` in the SDK URL must match the `intent` in the order you create, or the capture
fails at the end of the flow rather than at the start.

## Backend — Orders v2 client

```python
import os
import time
import requests

class PayPalError(Exception):
    """Raised with PayPal's own error body attached — never swallow it."""
    def __init__(self, message, status=None, body=None):
        super().__init__(message)
        self.status = status
        self.body = body


class PayPalClient:
    def __init__(self, client_id, client_secret, mode="sandbox"):
        self.client_id = client_id
        self.client_secret = client_secret
        self.base_url = (
            "https://api-m.sandbox.paypal.com" if mode == "sandbox"
            else "https://api-m.paypal.com"
        )
        self._token = None
        self._token_expires_at = 0.0

    def _access_token(self):
        # Tokens last ~9h. Fetching one per call is a wasted round trip on every
        # request; caching one forever starts failing with 401 after it expires.
        if self._token and time.time() < self._token_expires_at - 60:
            return self._token
        resp = requests.post(
            f"{self.base_url}/v1/oauth2/token",
            auth=(self.client_id, self.client_secret),
            data={"grant_type": "client_credentials"},
            headers={"Accept": "application/json"},
            timeout=30,
        )
        if resp.status_code != 200:
            raise PayPalError("OAuth token request failed", resp.status_code, resp.text)
        payload = resp.json()
        self._token = payload["access_token"]
        self._token_expires_at = time.time() + payload["expires_in"]
        return self._token

    def _request(self, method, path, json_body=None, request_id=None):
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self._access_token()}",
        }
        # Idempotency. Derive the key from the business object (order id, cart id) —
        # a random key per attempt is the same as no key, and a retried capture
        # after a timeout is exactly how buyers get charged twice.
        if request_id:
            headers["PayPal-Request-Id"] = request_id

        resp = requests.request(
            method, f"{self.base_url}{path}", headers=headers, json=json_body, timeout=30
        )
        # Raising on non-2xx is the whole point. Returning resp.json() unconditionally
        # hands the caller an error body shaped like a success and a failed capture
        # becomes a fulfilled order.
        if resp.status_code >= 400:
            raise PayPalError(
                f"{method} {path} failed", resp.status_code, resp.text
            )
        return resp.json() if resp.content else {}

    def create_order(self, amount, currency="USD", reference_id=None):
        return self._request(
            "POST", "/v2/checkout/orders",
            {
                "intent": "CAPTURE",
                "purchase_units": [{
                    "reference_id": reference_id,
                    # String, and the decimal places must match the currency:
                    # "25.00" for USD, "2500" for JPY (zero-decimal). A mismatch
                    # is rejected as CURRENCY_NOT_SUPPORTED_FOR_VALUE.
                    "amount": {"currency_code": currency, "value": f"{amount:.2f}"},
                }],
            },
            request_id=f"create-{reference_id}" if reference_id else None,
        )

    def capture_order(self, order_id):
        return self._request(
            "POST", f"/v2/checkout/orders/{order_id}/capture",
            request_id=f"capture-{order_id}",
        )

    def get_order(self, order_id):
        return self._request("GET", f"/v2/checkout/orders/{order_id}")

    def refund_capture(self, capture_id, amount=None, currency="USD", note=None):
        body = {}
        if amount is not None:
            body["amount"] = {"value": f"{amount:.2f}", "currency_code": currency}
        if note:
            body["note_to_payer"] = note
        return self._request(
            "POST", f"/v2/payments/captures/{capture_id}/refund",
            body, request_id=f"refund-{capture_id}",
        )
```

### Capture endpoint

```python
@app.post("/api/paypal/orders/<order_id>/capture")
def capture(order_id):
    cart = lookup_cart_for_order(order_id)        # your record, created at create_order
    try:
        result = client.capture_order(order_id)
    except PayPalError as e:
        if e.status == 422 and "INSTRUMENT_DECLINED" in (e.body or ""):
            return {"error": "INSTRUMENT_DECLINED"}, 200   # buyer can retry
        raise

    capture_obj = result["purchase_units"][0]["payments"]["captures"][0]
    if capture_obj["status"] != "COMPLETED":
        # PENDING happens (e.g. echeck). Do not fulfil here — wait for the webhook.
        return {"status": capture_obj["status"]}, 202

    # Confirm PayPal charged what you asked for before fulfilling.
    paid = capture_obj["amount"]
    if paid["value"] != f"{cart.total:.2f}" or paid["currency_code"] != cart.currency:
        alert_ops("paypal amount mismatch", order_id=order_id, paid=paid)
        return {"error": "AMOUNT_MISMATCH"}, 409

    fulfil_once(capture_id=capture_obj["id"], cart=cart)
    return {"status": "COMPLETED"}, 200
```

## Webhooks (not IPN)

Register the webhook in the PayPal dashboard, note its **webhook id**, and verify every
delivery. An unverified webhook endpoint is an open API that fulfils orders for free —
anyone can POST a `PAYMENT.CAPTURE.COMPLETED` body to it.

```python
@app.post("/webhooks/paypal")
def paypal_webhook():
    event = request.get_json()

    verification = client._request("POST", "/v1/notifications/verify-webhook-signature", {
        "transmission_id":   request.headers["PayPal-Transmission-Id"],
        "transmission_time": request.headers["PayPal-Transmission-Time"],
        "cert_url":          request.headers["PayPal-Cert-Url"],
        "auth_algo":         request.headers["PayPal-Auth-Algo"],
        "transmission_sig":  request.headers["PayPal-Transmission-Sig"],
        "webhook_id":        os.environ["PAYPAL_WEBHOOK_ID"],
        "webhook_event":     event,
    })
    if verification.get("verification_status") != "SUCCESS":
        return "", 400

    # PayPal retries on any non-2xx, so deliveries repeat by design. Dedupe on the
    # event id and return 200 fast; do the slow work on a queue.
    if already_handled(event["id"]):
        return "", 200
    mark_handled(event["id"])

    kind = event["event_type"]
    if kind == "PAYMENT.CAPTURE.COMPLETED":
        fulfil_once(capture_id=event["resource"]["id"], cart=cart_for_capture(event))
    elif kind == "PAYMENT.CAPTURE.DENIED":
        release_inventory(event["resource"]["id"])
    elif kind == "PAYMENT.CAPTURE.REFUNDED":
        record_refund(event["resource"])
    elif kind == "CUSTOMER.DISPUTE.CREATED":
        open_dispute_case(event["resource"])
    elif kind == "BILLING.SUBSCRIPTION.ACTIVATED":
        activate_subscription(event["resource"]["id"])
    elif kind == "BILLING.SUBSCRIPTION.CANCELLED":
        deactivate_subscription(event["resource"]["id"])
    elif kind == "PAYMENT.SALE.COMPLETED":
        extend_subscription_period(event["resource"])   # recurring charge succeeded

    return "", 200
```

`fulfil_once` must be idempotent on the capture id: the capture endpoint and the
webhook will both reach it for the same payment, and that is the intended design —
the webhook is what saves you when the buyer closes the tab mid-capture.

### If you are maintaining existing IPN code

IPN still receives traffic but is legacy; port when you can. Two things older IPN
handlers get wrong and that are worth fixing even before porting:

- **Post back the raw body**, not a re-encoded dict. `request.form.to_dict()` drops
  duplicate keys and changes parameter order, and PayPal then answers `INVALID` for
  legitimate messages. Prepend `cmd=_notify-validate` to the untouched raw body.
- **Check `receiver_email` and the amount.** `VERIFIED` only means PayPal sent it — not
  that it was sent to *you* for the *right amount*. Without those two checks an
  attacker pays 0.01 to their own account and replays the notification at you.

## Subscriptions

Order: product → plan → subscription. Each is a separate call; plans are not created
inline.

```python
def create_product(client, name):
    return client._request("POST", "/v1/catalogs/products",
        {"name": name, "type": "SERVICE"}, request_id=f"product-{name}")

def create_plan(client, product_id, amount, interval="MONTH"):
    return client._request("POST", "/v1/billing/plans", {
        "product_id": product_id,
        "name": f"{interval} plan",
        "billing_cycles": [{
            "frequency": {"interval_unit": interval, "interval_count": 1},
            "tenure_type": "REGULAR",
            "sequence": 1,
            "total_cycles": 0,                       # 0 = renew indefinitely
            "pricing_scheme": {
                "fixed_price": {"value": f"{amount:.2f}", "currency_code": "USD"}
            },
        }],
        "payment_preferences": {
            "auto_bill_outstanding": True,
            "setup_fee_failure_action": "CANCEL",
            "payment_failure_threshold": 3,
        },
    }, request_id=f"plan-{product_id}-{interval}-{amount}")

def create_subscription(client, plan_id, subscriber_email):
    sub = client._request("POST", "/v1/billing/subscriptions", {
        "plan_id": plan_id,
        "subscriber": {"email_address": subscriber_email},
        "application_context": {
            "return_url": "https://yourdomain.com/subscription/success",
            "cancel_url": "https://yourdomain.com/subscription/cancel",
        },
    }, request_id=f"sub-{plan_id}-{subscriber_email}")
    approve = next(l["href"] for l in sub["links"] if l["rel"] == "approve")
    return {"subscription_id": sub["id"], "approval_url": approve}
```

A subscription is not active when the buyer returns to `return_url` — it is active on
`BILLING.SUBSCRIPTION.ACTIVATED`. Grant access from the webhook, not the redirect.
Renewals arrive as `PAYMENT.SALE.COMPLETED`; absence of one is how you detect a lapsed
card, so handle `BILLING.SUBSCRIPTION.PAYMENT.FAILED` too.

## Configuration and testing

```python
# Never literals in source — and the pair must match the environment.
CLIENT_ID     = os.environ["PAYPAL_CLIENT_ID"]
CLIENT_SECRET = os.environ["PAYPAL_CLIENT_SECRET"]
WEBHOOK_ID    = os.environ["PAYPAL_WEBHOOK_ID"]     # differs per environment
MODE          = os.environ.get("PAYPAL_MODE", "sandbox")
```

- Sandbox credentials against the live base URL (or the reverse) fail as a generic
  `401 invalid_client`. Check the pairing before debugging anything else.
- The **webhook id is environment-specific**. A sandbox webhook id used against live
  verification returns `FAILURE` for every genuine event.
- Create sandbox buyer and seller accounts at `developer.paypal.com`; use the negative
  testing options to force `INSTRUMENT_DECLINED` and dispute flows.
- Webhooks cannot reach `localhost` — tunnel (`ngrok`) or use the dashboard's webhook
  simulator. The simulator does **not** produce a valid signature, so verification
  fails against it by design; test the verify path with a real tunnelled delivery.

## Common failure modes

| Symptom | Cause |
|---|---|
| `ORDER_ALREADY_CAPTURED` (422) | Client called `actions.order.capture()` and the server captured too |
| Webhook verification always `FAILURE` | Wrong `webhook_id` for the environment, or the event body was re-serialised before verifying |
| `401 invalid_client` | Sandbox credentials against live base URL, or vice versa |
| Order 404s on capture | v1 `Payment` id used against a v2 Orders endpoint |
| Buyer charged twice | No `PayPal-Request-Id`, or a key that is random per attempt |
| Paid but never fulfilled | Fulfilment hangs off the `return_url` redirect instead of the capture result or webhook |
| `CURRENCY_NOT_SUPPORTED_FOR_VALUE` | Decimal places do not match the currency (JPY takes none) |
