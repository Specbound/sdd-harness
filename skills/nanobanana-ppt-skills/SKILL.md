---
name: nanobanana-ppt-skills
description: Use when asked to turn a document or outline into a styled PPT image deck (and optionally a transition video) via Google's Gemini image model (nicknamed "Nano Banana") and Kling AI. Not a slide-text tool — it renders each slide as a generated image.
risk: safe
source: https://github.com/op7418/NanoBanana-PPT-Skills
---

# NanoBanana PPT Skills

## When to Use

Trigger when the user wants a visually styled slide deck generated as images (not a `.pptx` with editable text) from a document, outline, or set of talking points — especially "tech product," "business presentation," or "data report" style decks. Also covers the optional step of generating AI transition videos between slides and exporting a full interactive/video PPT. Not for editable Office-format slides — output is PNG/JPEG per slide plus optional MP4.

## Prerequisites

- Python 3.8+
- `GEMINI_API_KEY` (required) — image generation via Gemini 3 Pro Image Preview ("Nano Banana Pro")
- `KLING_ACCESS_KEY` / `KLING_SECRET_KEY` (optional) — only needed for the transition-video pipeline

## Install (as a Claude Code Skill)

```bash
git clone https://github.com/op7418/NanoBanana-PPT-Skills.git ~/.claude/skills/ppt-generator
cd ~/.claude/skills/ppt-generator
python3 -m venv venv && source venv/bin/activate
pip install google-genai pillow python-dotenv
cp .env.example .env   # fill in GEMINI_API_KEY (+ KLING_* if using video)
python3 generate_ppt.py --help   # verify install
```

`.env` resolution order: skill directory → nearest parent with `.git`/`.env` → `~/.env` → process environment. Once installed, invoke with `/ppt-generator-pro` or by describing the deck in natural language; Claude drives content planning and calls the scripts below.

## Usage: generate slide images

1. Write a content plan (`my_slides_plan.json`):

```json
{
  "title": "AI Product Design Guide",
  "total_slides": 3,
  "slides": [
    {"slide_number": 1, "page_type": "cover", "content": "Title: AI Product Design Guide\nSubtitle: Building user-centered intelligent experiences"},
    {"slide_number": 2, "page_type": "content", "content": "Core Principles\n- Simple and intuitive\n- Fast response\n- Transparent and controllable"},
    {"slide_number": 3, "page_type": "data", "content": "User satisfaction\nBefore: 65%\nAfter: 92%\nLift: +27%"}
  ]
}
```

`page_type` is one of `cover`, `content`, `data` — the style templates lay each out differently.

2. Render:

```bash
python3 generate_ppt.py --plan my_slides_plan.json --style styles/gradient-glass.md --resolution 2K
```

Built-in styles: `gradient-glass.md` (frosted-glass, neon gradients, Apple-Keynote-minimal — tech/business) and `vector-illustration.md` (flat, warm retro palette, outlined shapes — education/creative). Custom styles can be added under `styles/`. Resolution: 2K or 4K; ~30s/page at 2K.

3. Open `outputs/TIMESTAMP/index.html` to view the rendered deck.

## Usage: transition video (optional, requires Kling keys)

1. Generate the slide images as above.
2. Ask Claude to analyze the rendered images and write per-transition prompts to `outputs/TIMESTAMP/transition_prompts.json` (this step needs Claude in the loop — it's not scriptable alone).
3. Render transitions and the interactive player:

```bash
python3 generate_ppt_video.py --slides-dir outputs/TIMESTAMP/images --output-dir outputs/TIMESTAMP_video --prompts-file outputs/TIMESTAMP/transition_prompts.json
```

4. Open `outputs/TIMESTAMP_video/video_index.html` — arrow-key advance plays the transition then holds the static slide (~2s) before the next transition. `full_ppt_video.mp4` in the same directory is the complete stitched video.

## Anti-Patterns

- Treating this as an editable-slides tool — output is rendered images/video; there is no way to tweak text after generation without re-rendering that slide
- Skipping the transition-prompt step and calling `generate_ppt_video.py` directly — it requires `transition_prompts.json`, which only Claude's image analysis step produces
- Requesting video output without `KLING_ACCESS_KEY`/`KLING_SECRET_KEY` set — image generation works without them, video does not

## Verification Note

Command syntax, `.env` resolution order, and the JSON plan schema are drawn directly from the upstream README's documented usage sections. `page_type` layout differences and exact style-file authoring format weren't independently rendered this session.
