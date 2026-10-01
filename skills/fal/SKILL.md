---
name: fal
description: Call fal.ai models via the fal_client Python SDK — text-to-image/video generation, image editing (inpainting/style transfer), upscaling, TTS/STT audio, multi-model workflow chaining, and async job management (submit/poll/webhook). Use for any fal.ai / fal_client task.
---

# Fal.ai

All fal.ai model families share one SDK and one request shape; only the model slug and `arguments` payload differ.

## Setup
```bash
pip install fal-client
export FAL_KEY="your-fal-api-key"   # required, from fal.ai dashboard
```

## Universal rules (apply to every model family below)
- **Always verify the model slug at [fal.ai/models](https://fal.ai/models) before use** — IDs are versioned and change; never hard-code one from memory.
- **Inputs must be URLs, not local paths.** Upload local files first: `image_url = fal_client.upload_file("/path/to/file.png")`.
- **Output URLs expire.** Download and persist results yourself if you need them beyond the session — don't rely on the returned URL staying valid.
- Use `fal_client.run(...)` for quick synchronous calls; switch to the async queue pattern (below) for anything long-running (video, batch jobs) or when you need to poll/cancel/webhook.

## Generate (text → image/video)
```python
import fal_client
result = fal_client.run(
    "fal-ai/<model>",  # e.g. a flux/image or video-gen model — verify at fal.ai/models
    arguments={"prompt": "a watercolor fox in a forest"},
)
output_url = result["images"][0]["url"]  # shape varies by model family — check the model card
```
Video generation is typically long-running — use the async queue pattern instead of blocking `run()`.

## Image edit (image + instruction → edited image)
Style transfer, inpainting/object removal, instruction-based edits — requires an existing input image (not for generating from scratch; use Generate above for that).
```python
image_url = fal_client.upload_file("/path/to/local/image.png")
result = fal_client.run(
    "fal-ai/image-editing",
    arguments={"image_url": image_url, "prompt": "remove the person on the left"},
)
edited_url = result["images"][0]["url"]
```

## Upscale (resolution increase / restoration)
Increasing resolution, denoising, or restoring low-quality input — not for generating new content (Generate) or instruction-based edits at the same resolution (Image edit).
```python
image_url = fal_client.upload_file("/path/to/local/image.png")
result = fal_client.run(
    "fal-ai/clarity-upscaler",
    arguments={"image_url": image_url, "scale": 2},  # verify param name/range on model card
)
upscaled_url = result["image"]["url"]
```
Video upscaling is a long-running job — use the async queue pattern, not blocking `run()`.

## Audio: TTS (text → speech)
```python
result = fal_client.run(
    "fal-ai/kokoro",
    arguments={"prompt": "Hello, world.", "voice": "af_sarah"},  # voice IDs vary by model
)
audio_url = result["audio"]["url"]
```

## Audio: STT (speech → text)
```python
result = fal_client.run(
    "fal-ai/whisper",
    arguments={"audio_url": "https://example.com/speech.mp3", "task": "transcribe"},  # or "translate"
)
text = result["text"]
chunks = result.get("chunks", [])  # word-level timestamps, if available
```
fal.ai audio models are batch/async — not for real-time/low-latency streaming interception.

## Workflow chaining (multi-model pipelines)
Chain fal.ai calls by feeding one model's output URL (image/audio/video) directly into the next call's `arguments` — e.g. generate → upscale, or generate → image-edit → audio narration. There is no special "workflow file" API; it's plain sequential Python using the patterns above, passing `result["...]["url"]` forward. For long pipelines, prefer the async queue pattern per step so slow steps don't block, and use webhooks to kick off the next step on completion.

## Async queue pattern (submit → poll → result)
Use for long-running jobs (video, batch), or when you need status/cancel:
```python
handler = fal_client.submit("fal-ai/<model>", arguments={...})
request_id = handler.request_id
status = fal_client.status("fal-ai/<model>", request_id, with_logs=True)
# status: Queued(position=N) | InProgress(logs=[...]) | Completed(...)
result = fal_client.result("fal-ai/<model>", request_id)
```
`fal_client.subscribe(...)` wraps submit+poll+result into one blocking call with an `on_queue_update` callback — prefer this over manual polling when you don't also need a webhook.

Cancel: `fal_client.cancel("fal-ai/<model>", request_id)`

### Webhooks (skip polling entirely)
```python
handler = fal_client.submit(
    "fal-ai/<model>",
    arguments={...},
    webhook_url="https://your-server.example.com/fal-webhook",
)
```
fal.ai POSTs the completed result to `webhook_url` — verify your endpoint accepts fal's payload shape/signature before relying on it in production.

## Pricing / usage
fal.ai has no public usage-tracking API. Cost is per-model (billed by output unit: images, seconds of audio/video, or compute-seconds) and visible only on the [fal.ai dashboard](https://fal.ai/dashboard/billing). Don't fabricate a pricing API — point the user to the dashboard.

## Anti-patterns
- Using blocking `fal_client.run()` for a job you also want to poll or cancel — `run()` doesn't expose a `request_id` until the job has already finished.
- Polling `status()` in a tight loop — use `subscribe()`'s callback or a webhook instead.
- Passing a local file path as `image_url`/`audio_url` — always `fal_client.upload_file(path)` first.
- Hard-coding a model slug without checking fal.ai/models — IDs and parameter names change and differ across model families.
- Assuming a usage/billing REST endpoint exists — it doesn't; the dashboard is the only source.
