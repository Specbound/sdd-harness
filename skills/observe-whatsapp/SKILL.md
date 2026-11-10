---
name: observe-whatsapp
description: "Diagnose Kapso WhatsApp operations: message delivery, webhook deliveries and retries, API error triage, phone-number health checks."
source: "https://github.com/gokapso/agent-skills/tree/master/skills/observe-whatsapp"
risk: safe
---

# Observe WhatsApp (Kapso)

Operational diagnostics for WhatsApp on Kapso: why a message did not arrive, why a
webhook did not fire, what the API actually returned, and whether a phone number is
healthy. Read-only — nothing here changes configuration.

## Before running any command — check the toolchain is present

**This skill ships as `SKILL.md` only.** The `scripts/`, `references/` and `assets/`
directories that the commands below invoke are **not installed here**. Running
`node scripts/<anything>.js` as-is fails with `Cannot find module`.

```bash
ls scripts/messages.js 2>/dev/null || echo "NOT INSTALLED — fetch the toolchain first"
```

If it is missing, fetch the upstream skill directory (see `source:` in the frontmatter)
into the skill folder and run `npm i` there once. Everything below assumes that has
happened. If you cannot fetch it, say so and fall back to the Kapso Platform API
directly — do not report a `scripts/` command as run when it was not.

## Setup

Env vars:
- `KAPSO_API_BASE_URL` — host only, no `/platform/v1` suffix
- `KAPSO_API_KEY`

## Investigate message delivery

Work outward from the message, not from the conversation — the message record carries
the delivery status and the error code; the conversation only tells you it exists.

1. `node scripts/messages.js --phone-number-id <id>` — find the message
2. `node scripts/message-details.js --message-id <id>` — status and failure reason
3. `node scripts/lookup-conversation.js --phone-number <e164>` — if you have a phone
   number but no message ID, start here instead and come back to step 2

## Triage an error

Three different layers, and they disagree often enough that checking only one is how
a delivery failure gets misattributed:

1. `node scripts/errors.js` — message-level errors (what WhatsApp rejected)
2. `node scripts/api-logs.js` — external API call logs (what Kapso sent and got back)
3. `node scripts/webhook-deliveries.js` — inbound webhook attempts and retries
   (what reached your endpoint, and how many times it was retried)

A message that shows no error in step 1 but a failed webhook in step 3 is a delivery
problem on your side, not on WhatsApp's.

## Health check

1. `node scripts/overview.js` — project-wide state
2. `node scripts/whatsapp-health.js --phone-number-id <id>` — per-number health

## Explore the API surface

```bash
node scripts/openapi-explore.mjs --spec platform search "webhook deliveries"
node scripts/openapi-explore.mjs --spec platform op listWebhookDeliveries
node scripts/openapi-explore.mjs --spec platform schema WebhookDelivery
```

Use this rather than guessing an endpoint — it is also the fallback path for working
against the Platform API directly when the `scripts/` toolchain is unavailable.

## Scope

| Need | Skill |
|---|---|
| Read delivery state, errors, logs, health | this skill |
| Build or debug workflows, triggers, functions, D1 | `automate-whatsapp` |
| Webhook setup, templates, flows, onboarding | `integrate-whatsapp` — **not installed in this library**; fetch from the same upstream org or use the Platform API |
