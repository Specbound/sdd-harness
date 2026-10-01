---
name: fal-image-edit
description: Use when editing an existing image via fal.ai models — style transfer, object removal/inpainting, or instruction-based edits. Covers fal-client setup, upload-before-edit requirement, and request/response patterns.
source: "https://github.com/fal-ai-community/skills/blob/main/skills/claude.ai/fal-image-edit/SKILL.md"
risk: safe
---

# Fal Image Edit

## When to Use

Trigger when:
- Applying style transfer to an existing image
- Removing or replacing an object in an image (inpainting)
- Making an instruction-based edit to an image ("make the sky sunset-colored", "remove the person on the left")

Do **not** use for generating an image from scratch with no input image — that's text-to-image, a different fal.ai model family than image-to-image editing.

Note: the upstream `fal-ai-community/skills` repo has been restructured around a `genmedia` CLI, and this skill's original source path no longer resolves. This rewrite documents the underlying `fal_client` Python SDK directly instead of mirroring a dead source.

## Setup

```bash
pip install fal-client
export FAL_KEY="your-fal-api-key"   # required; get from fal.ai dashboard
```

## Edit Pattern (image + instruction → edited image)

```python
import fal_client

# Input images must be a URL — upload local files first
image_url = fal_client.upload_file("/path/to/local/image.png")

result = fal_client.run(
    "fal-ai/image-editing",         # verify current model name at fal.ai/models
    arguments={
        "image_url": image_url,
        "prompt": "remove the person on the left",
    }
)
edited_url = result["images"][0]["url"]
```

## Anti-Patterns

- Passing a local file path as `image_url` — fal.ai requires a URL; always call `fal_client.upload_file(path)` first
- Hard-coding a model slug without checking fal.ai/models — model IDs are versioned and change; verify before shipping
- Ignoring output URL expiry — download and store the result if persistence beyond the session is needed
- Confusing this with text-to-image generation — this skill is specifically for editing an existing input image
