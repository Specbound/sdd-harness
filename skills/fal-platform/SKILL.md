---
name: fal-platform
description: Use when managing fal.ai async job execution directly — submitting long-running requests to the queue, polling status, fetching results, cancelling, or wiring a webhook instead of blocking on fal_client.run(). Covers submit/status/result/cancel and webhook patterns; not for a specific model's request shape (see fal-generate/fal-audio/fal-image-edit/fal-upscale for that).
source: "https://github.com/fal-ai-community/skills/blob/main/skills/claude.ai/fal-platform/SKILL.md"
risk: safe
---

# Fal Platform

## When to Use

Trigger when:
- A fal.ai call is long-running (video generation, batch image jobs) and blocking with `fal_client.run()` isn't acceptable
- You need to poll job status, retrieve logs, or cancel an in-flight request
- You want a webhook callback instead of polling

Do **not** use for a specific model's request/response shape — see `fal-generate`, `fal-audio`, `fal-image-edit`, `fal-upscale` for those.

Note: the upstream `fal-ai-community/skills` repo has been restructured around a `genmedia` CLI, and this skill's original source path no longer resolves. This rewrite documents the underlying `fal_client` Python SDK directly instead.

## Setup

```bash
pip install fal-client
export FAL_KEY="your-fal-api-key"
```

## Async Queue Pattern (submit → poll → result)

```python
import fal_client

handler = fal_client.submit(
    "fal-ai/<model>",              # verify current model name at fal.ai/models
    arguments={...},
)
request_id = handler.request_id

status = fal_client.status("fal-ai/<model>", request_id, with_logs=True)
# status is Queued(position=N) | InProgress(logs=[...]) | Completed(...)

result = fal_client.result("fal-ai/<model>", request_id)
```

`fal_client.subscribe(...)` wraps submit+poll+result into one blocking call with an `on_queue_update` callback — prefer it over manual polling when you don't also need a webhook.

## Cancel

```python
fal_client.cancel("fal-ai/<model>", request_id)
```

## Webhooks (skip polling entirely)

```python
handler = fal_client.submit(
    "fal-ai/<model>",
    arguments={...},
    webhook_url="https://your-server.example.com/fal-webhook",
)
```
fal.ai POSTs the completed result to `webhook_url` — verify your endpoint accepts fal's payload shape and signature before relying on it in production.

## Usage / Pricing

fal.ai has no public usage-tracking API — cost and usage are per-model (billed by output unit: images, seconds of audio/video, or compute-seconds) and visible only on the [fal.ai dashboard](https://fal.ai/dashboard/billing). Don't fabricate a pricing API call; point the user to the dashboard instead.

## Anti-Patterns

- Using `fal_client.run()` (blocking) for a job you also want to poll or cancel — `run()` doesn't expose a `request_id` until the job has already finished
- Polling `status()` in a tight loop — use `subscribe()`'s callback or a webhook instead
- Assuming a usage/billing REST endpoint exists — it doesn't; the dashboard is the only source
