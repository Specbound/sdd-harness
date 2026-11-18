---
name: stripe-integration
description: "Build Stripe payment flows: Checkout, Payment Intents, subscriptions, signature-verified webhooks, refunds and disputes, idempotency, SCA."
risk: unknown
source: community
---

# Stripe Integration

Server-side Stripe payment flows in Python (`stripe-python`), with the frontend contract
each flow requires.

**This skill ships as `SKILL.md` only — no bundled references, assets, or client wrapper
files. Everything below is meant to be inlined, not opened from a path.**

## Use when

- Adding Checkout, Payment Intents, or subscription billing to an application
- Writing or reviewing a Stripe webhook endpoint
- Implementing refunds, disputes, or a customer billing portal
- Debugging a payment that "succeeded" on the client but never fulfilled server-side

## Do not use when

- The work is Stripe Connect marketplace split payments or payouts — those add an
  account-ownership model this skill does not cover
- The task is PCI scope assessment or compliance paperwork rather than implementation
- You are using a Stripe wrapper SDK (Lemon Squeezy, Paddle) — the object model differs

## SDK version — check before copying anything

`stripe-python` **v8 removed the `stripe.error` namespace.** Current code is:

```python
except stripe.StripeError            # v8+ (current)
except stripe.error.StripeError      # v7 and older — will AttributeError on v8+
```

Same move for `SignatureVerificationError`, `CardError`, `InvalidRequestError`. Check with
`pip show stripe` first; the examples below are v8+.

Load secrets from the environment, never as module literals:

```python
import os, stripe
stripe.api_key = os.environ["STRIPE_SECRET_KEY"]
WEBHOOK_SECRET = os.environ["STRIPE_WEBHOOK_SECRET"]
```

## Choosing a flow

| Flow | Use when | Cost |
|---|---|---|
| **Checkout Session** (hosted) | Default choice. One-time or recurring. | Stripe owns the UI; lowest PCI scope; fastest |
| **Payment Intent + Payment Element** | You need the payment form inside your UI | You own the UI; still low PCI scope via Stripe.js |
| **Setup Intent** | Save a card now, charge later | Required before off-session charges |

Rule of thumb: start with Checkout. Move to Payment Element only when a product
requirement — not a preference — forces custom UI.

## Idempotency — the thing most integrations miss

Every create call that moves money should carry an idempotency key. A client retry or a
load-balancer replay without one charges the customer twice.

```python
session = stripe.checkout.Session.create(
    ...,
    idempotency_key=f"checkout:{order_id}",   # stable, derived from YOUR order, not uuid4()
)
```

A random key per attempt is the same as no key. Derive it from the business object.

## Checkout Session (one-time)

```python
def create_checkout_session(order_id: str, amount_cents: int, currency: str = "usd"):
    return stripe.checkout.Session.create(
        mode="payment",
        line_items=[{
            "price_data": {
                "currency": currency,
                "product_data": {"name": "Purchase"},
                "unit_amount": amount_cents,      # smallest currency unit
            },
            "quantity": 1,
        }],
        success_url="https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url="https://example.com/cancel",
        metadata={"order_id": order_id},          # your join key back to your DB
        idempotency_key=f"checkout:{order_id}",
    )
    # Omit payment_method_types entirely. Specifying ["card"] is legacy and
    # disables every payment method you enabled in the Dashboard.
```

Redirect to `session.url`. **Do not fulfill on the `success_url` redirect** — the customer
can close the tab, and the URL can be visited directly. Fulfill on the
`checkout.session.completed` webhook.

## Payment Intent (custom UI)

```python
def create_payment_intent(amount_cents: int, customer_id: str | None = None):
    intent = stripe.PaymentIntent.create(
        amount=amount_cents,
        currency="usd",
        customer=customer_id,
        automatic_payment_methods={"enabled": True},
    )
    return intent.client_secret
```

Frontend uses the **Payment Element** and `confirmPayment`:

```javascript
const stripe = Stripe(PUBLISHABLE_KEY);
const elements = stripe.elements({ clientSecret });
elements.create("payment").mount("#payment-element");

const { error } = await stripe.confirmPayment({
  elements,
  confirmParams: { return_url: "https://example.com/complete" },
});
// `confirmCardPayment` + the card-only Element is the legacy path — it does not
// support the redirect-based methods automatic_payment_methods turns on, and it
// handles SCA/3DS less completely.
```

SCA/3D Secure is handled by the Element automatically; no extra server code. The
`return_url` is mandatory because some methods redirect off-site.

## Subscriptions

```python
def create_subscription(customer_id: str, price_id: str):
    sub = stripe.Subscription.create(
        customer=customer_id,
        items=[{"price": price_id}],
        payment_behavior="default_incomplete",       # don't assume the first charge clears
        payment_settings={"save_default_payment_method": "on_subscription"},
        expand=["latest_invoice.payment_intent"],
    )
    return {"subscription_id": sub.id,
            "client_secret": sub.latest_invoice.payment_intent.client_secret}
```

`default_incomplete` is the correct default: it leaves the subscription inactive until the
first payment confirms, so an SCA challenge does not silently grant access.

Billing portal — cheaper than building cancellation/upgrade UI:

```python
stripe.billing_portal.Session.create(customer=customer_id,
                                     return_url="https://example.com/account").url
```

## Webhooks

```python
from flask import Flask, request
app = Flask(__name__)

@app.post("/webhook")
def webhook():
    try:
        event = stripe.Webhook.construct_event(
            request.data,                               # RAW bytes — see note below
            request.headers.get("Stripe-Signature"),
            WEBHOOK_SECRET,
        )
    except ValueError:
        return "Invalid payload", 400
    except stripe.SignatureVerificationError:           # v8+ namespace
        return "Invalid signature", 400

    if already_processed(event["id"]):                  # Stripe retries; events repeat
        return "", 200

    obj = event["data"]["object"]
    if event["type"] == "checkout.session.completed":
        enqueue_fulfillment(obj["metadata"]["order_id"])
    elif event["type"] == "payment_intent.payment_failed":
        enqueue_failure_notice(obj["id"])
    elif event["type"] == "customer.subscription.deleted":
        enqueue_access_revocation(obj["customer"])
    elif event["type"] == "invoice.payment_succeeded":
        enqueue_period_extension(obj["subscription"])

    mark_processed(event["id"])
    return "", 200     # return fast; do the work in a queue, not in the request
```

Three failure modes that cause real outages:

- **Parsed body breaks verification.** `construct_event` needs the exact raw bytes. Any
  middleware that JSON-parses and re-serializes first changes whitespace and key order,
  and every signature fails. In Flask use `request.data` before touching `request.json`;
  in Express mount `express.raw({type: 'application/json'})` on that route only.
- **Slow handlers get retried.** Stripe times out around 20s and retries with the same
  `event.id`. Do fulfillment in a background job and return 200 immediately.
- **Retries are not duplicates to ignore — they are duplicates to deduplicate.** Key on
  `event["id"]`, which is stable across retries.

### Never hand-roll signature verification

A manual HMAC over the payload alone is wrong and will reject every real event. The
`Stripe-Signature` header is `t=<timestamp>,v1=<hmac>`, and the signed string is
`f"{timestamp}.{raw_payload}"` — not the payload by itself. Hand-rolled versions also skip
the timestamp tolerance check, which is the only thing preventing replay of a captured
request. Use `construct_event`; it does both.

## Customers, refunds, disputes

```python
def create_customer(email: str, user_id: str, payment_method_id: str | None = None):
    kwargs = {"email": email, "metadata": {"user_id": user_id}}
    if payment_method_id:
        kwargs["payment_method"] = payment_method_id
        kwargs["invoice_settings"] = {"default_payment_method": payment_method_id}
    return stripe.Customer.create(**kwargs)
    # Passing invoice_settings={"default_payment_method": None} is an API error,
    # so build the dict conditionally rather than inlining a ternary.

def refund(payment_intent_id: str, amount_cents: int | None = None, reason: str | None = None):
    params = {"payment_intent": payment_intent_id,
              "idempotency_key": f"refund:{payment_intent_id}"}
    if amount_cents:
        params["amount"] = amount_cents          # omit for a full refund
    if reason:
        params["reason"] = reason                # duplicate | fraudulent | requested_by_customer
    return stripe.Refund.create(**params)

def submit_dispute_evidence(dispute_id: str, evidence: dict):
    # dispute_id is dp_..., NOT the charge id. Passing a charge id here 404s.
    # Find it via stripe.Dispute.list(charge=charge_id).
    return stripe.Dispute.modify(dispute_id, evidence={
        "customer_name": evidence.get("customer_name"),
        "customer_email_address": evidence.get("customer_email"),
        "shipping_documentation": evidence.get("shipping_proof_file_id"),  # a File id, not a URL
        "customer_communication": evidence.get("communication_file_id"),
    })
```

Dispute evidence has a hard deadline (`dispute.evidence_details.due_by`). Submitting after
it loses automatically, so wire `charge.dispute.created` to an alert, not a daily digest.

## Testing

```python
TEST_CARDS = {
    "success":            "4242424242424242",
    "declined":           "4000000000000002",
    "insufficient_funds": "4000000000009995",
    "requires_3ds":       "4000002500003155",   # forces an SCA challenge
}
```

Three tools worth knowing:

- `stripe listen --forward-to localhost:5000/webhook` — the CLI prints a `whsec_` secret
  for local use. It differs from your Dashboard endpoint secret; using the wrong one is
  the usual cause of "signature verification failed" in dev.
- `stripe trigger payment_intent.succeeded` — fire a real event without a real payment.
- **Test clocks** (`stripe.test_helpers.TestClock.create`) — advance simulated time to test
  renewals, trial expiry, and dunning. Without them, subscription lifecycle code is
  effectively untested.

## Checklist

- [ ] `stripe` version checked; `stripe.error.*` not used on v8+
- [ ] Secret key and webhook secret read from env, never literals
- [ ] Idempotency keys derived from business objects on every money-moving create
- [ ] Fulfillment driven by webhooks, never by the `success_url` redirect
- [ ] Webhook reads the raw body and verifies with `construct_event`
- [ ] Webhook deduplicates on `event["id"]` and returns 200 before doing work
- [ ] Amounts in the smallest currency unit, with zero-decimal currencies (JPY) considered
- [ ] Subscriptions created with `payment_behavior="default_incomplete"`
- [ ] Dispute evidence wired to the `due_by` deadline
- [ ] Subscription lifecycle covered by test clocks, not just a single charge test
