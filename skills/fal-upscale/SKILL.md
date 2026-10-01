---
name: fal-upscale
description: Use when increasing image or video resolution / enhancing quality via fal.ai models — upscaling, denoising, or restoring low-res input. Covers fal-client setup, upload-before-upscale requirement, and request/response patterns.
source: "https://github.com/fal-ai-community/skills/blob/main/skills/claude.ai/fal-upscale/SKILL.md"
risk: safe
---

# Fal Upscale

## When to Use

Trigger when:
- Increasing the resolution of an existing image or video
- Enhancing or restoring a low-quality / compressed image
- Denoising or sharpening as a pre- or post-processing step in an image pipeline

Do **not** use for generating new content from a prompt — that's `fal-generate`. Do **not** use for instruction-based edits to content that's already the right resolution — that's `fal-image-edit`.

Note: the upstream `fal-ai-community/skills` repo has been restructured around a `genmedia` CLI, and this skill's original source path no longer resolves. This rewrite documents the underlying `fal_client` Python SDK directly instead.

## Setup

```bash
pip install fal-client
export FAL_KEY="your-fal-api-key"
```

## Upscale Pattern (image → higher-resolution image)

```python
import fal_client

image_url = fal_client.upload_file("/path/to/local/image.png")

result = fal_client.run(
    "fal-ai/clarity-upscaler",       # verify current model name at fal.ai/models
    arguments={
        "image_url": image_url,
        "scale": 2,                  # verify the scale parameter name/range on the model card
    }
)
upscaled_url = result["image"]["url"]
```

Video upscaling is a long-running job, not an instant call — see `fal-platform` for the `submit`/`status`/`result` pattern (or `subscribe()`) instead of blocking with `run()`.

## Anti-Patterns

- Passing a local file path as `image_url` — always call `fal_client.upload_file(path)` first
- Blocking with `run()` on a video-upscale job — use the `fal-platform` submit/poll pattern or `subscribe()` instead
- Hard-coding a model slug without checking fal.ai/models — model IDs and parameter names differ between the image- and video-upscale model families
