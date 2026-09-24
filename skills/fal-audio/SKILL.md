---
name: fal-audio
description: Use when generating speech from text (TTS) or transcribing audio to text (STT) via fal.ai models. Covers fal-client setup, model selection, request/response patterns, and saving audio output.
source: "https://github.com/fal-ai-community/skills/blob/main/skills/claude.ai/fal-audio/SKILL.md"
risk: safe
---

# Fal Audio

## When to Use

Trigger when:
- Generating speech from a text string (TTS) for narration, accessibility, or demo purposes
- Transcribing an audio file or URL to text (STT/ASR)
- Chaining audio generation into a pipeline that already uses fal.ai

Do **not** use for real-time streaming audio or live call interception — fal.ai audio models are batch/async, not low-latency streaming.

## Setup

```bash
pip install fal-client
export FAL_KEY="your-fal-api-key"   # required; get from fal.ai dashboard
```

## TTS Pattern (text → audio file)

```python
import fal_client

result = fal_client.run(
    "fal-ai/kokoro",                # verify current model name at fal.ai/models
    arguments={
        "prompt": "Hello, world.",
        "voice": "af_sarah",        # voice IDs vary by model — check model card
    }
)
audio_url = result["audio"]["url"]  # download or pass to next pipeline step
```

## STT Pattern (audio file → transcript)

```python
result = fal_client.run(
    "fal-ai/whisper",               # verify current model name at fal.ai/models
    arguments={
        "audio_url": "https://example.com/speech.mp3",
        "task": "transcribe",       # or "translate" for non-English → English
    }
)
text = result["text"]
chunks = result.get("chunks", [])   # word-level timestamps when available
```

## Anti-Patterns

- Hard-coding model names without checking fal.ai/models first — model IDs are versioned and can change
- Passing local file paths directly — fal.ai requires a URL; upload to fal storage first with `fal_client.upload_file(path)`
- Ignoring `result["audio"]["url"]` expiry — fal.ai output URLs are temporary; download and store if persistence is needed
