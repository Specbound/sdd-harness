---
name: imagen
description: "Generate a PNG from a text prompt via Google Gemini. Use for requests to create an image, icon, logo, avatar, or illustration. Needs GEMINI_API_KEY."
source: "https://github.com/sanjay3290/ai-skills/tree/main/skills/imagen"
risk: safe
---

# Imagen — generate images with Gemini

Text prompt in, PNG file on disk out. Cross-platform (Windows, macOS, Linux).

## Prerequisite

`GEMINI_API_KEY` must be set. If it is not, stop and ask the user for it — do not
proceed and do not write the key into any file in the repo.

```bash
[ -n "$GEMINI_API_KEY" ] && echo "key present" || echo "GEMINI_API_KEY missing"
```

## Generate

There is no helper script in this skill directory — call the REST API directly.
Earlier versions of this skill documented `python scripts/generate_image.py`;
that file has never existed here, so every one of those commands failed. Use the
call below instead.

```bash
MODEL=gemini-2.5-flash-image   # verify against https://ai.google.dev/gemini-api/docs/image-generation
OUT=./generated.png

curl -s "https://generativelanguage.googleapis.com/v1beta/models/$MODEL:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"A futuristic city skyline at sunset"}]}]}' \
  > /tmp/imagen-response.json

jq -r '.candidates[0].content.parts[] | select(.inlineData) | .inlineData.data' \
  /tmp/imagen-response.json | base64 -d > "$OUT"
```

Keep the raw response in a file rather than piping straight to `base64` — when the
call fails you need to read the JSON error, and a pipe will have discarded it.
On macOS before 10.13 use `base64 -D` instead of `-d`.

Model names in this API family change often and preview names expire. Confirm the
current image-capable model from the docs link above before the first call in a
session; if the request returns 404 on the model, that is why.

## Reading the response

Success returns `candidates[].content.parts[]`, where the image part carries
`inlineData.data` (base64) and `inlineData.mimeType` (`image/png`). Text-only
parts can appear alongside it — skip any part without `inlineData`.

Failure returns a JSON `error` object. Check it before assuming an empty file is
an API problem:

- `401` / `403` — key missing, invalid, or not enabled for this API
- `404` — model name wrong or retired (see above)
- `400` with a safety block — the prompt was refused; rephrase rather than retry
- `429` — rate limited; back off before retrying

## After generating

Report the written path, and confirm the file is non-empty (`wc -c`) before
telling the user it worked — a zero-byte PNG means the parse found no
`inlineData` part, not that generation succeeded.

Put assets where the project already keeps them (`./assets/`, `./public/`,
`./static/`) rather than the repo root. Generated images are binaries; ask before
committing one.

## Typical requests

| User asks for | Prompt shape |
|---|---|
| Hero / landing image | Subject + mood + style, no text in image ("abstract tech, deep blue, no lettering") |
| App icon or logo | "minimalist app icon, flat, centered, solid background" — ask for the target px size |
| Docs diagram | Describe the boxes and arrows explicitly; for anything load-bearing prefer `mermaid-expert` over a generated raster |
| Placeholder avatar | "neutral placeholder avatar, soft gradient, no face" |

Image models render text unreliably. For a diagram whose labels must be correct,
generate SVG/Mermaid instead of calling this skill.
