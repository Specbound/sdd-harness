---
name: skill-seekers
description: Use when a docs site, GitHub repo, PDF, video, or local codebase needs to become a reusable AI skill/knowledge asset (for Claude, RAG, or another coding assistant) rather than being re-read from scratch each session. Wraps the `skill-seekers` CLI (18 source types, 22 export targets).
risk: safe
source: https://github.com/yusufkaraaslan/Skill_Seekers
---

# Skill Seekers

## When to Use

Trigger when the task is "turn this external source into a packaged skill" rather than "read this source once for the current task" — e.g. a team keeps referencing the same framework's docs, or a codebase needs a durable reference asset. Also covers scanning an existing project to auto-generate per-framework configs. Not for a one-off lookup — installing and running this CLI has more setup cost than just reading the source directly for a single question.

## Install

```bash
pip install skill-seekers   # Python 3.10+, Git required
```

## Core Workflow

```bash
# 1. Create a skill from any source
skill-seekers create https://docs.djangoproject.com/

# 2. Package it for your target platform
skill-seekers package output/django --target claude
# → output/django-claude.zip, ready to install into ~/.claude/skills/
```

Pick a non-default enhancement agent if needed:

```bash
skill-seekers create https://docs.djangoproject.com/ --agent kimi
skill-seekers create https://docs.djangoproject.com/ --agent-cmd "my-custom-agent run"
```

## Source Types (18, non-exhaustive examples)

```bash
skill-seekers create facebook/react              # GitHub repo
skill-seekers create ./my-project                # local codebase
skill-seekers create manual.pdf                  # PDF
skill-seekers create report.docx                 # Word
skill-seekers create book.epub                   # EPUB
skill-seekers create notebook.ipynb              # Jupyter
skill-seekers create openapi.yaml                # OpenAPI/Swagger
skill-seekers create presentation.pptx           # PowerPoint
skill-seekers create page.html                   # local HTML (file or dir)
skill-seekers create --video-url <youtube-url> --name mytutorial   # needs skill-seekers[video]
skill-seekers create --space-key TEAM --name wiki                  # Confluence
skill-seekers create --database-id ... --name docs                 # Notion
skill-seekers create --chat-export-path ./slack-export --name team-chat  # Slack/Discord export
```

## Project Auto-Scan

Point `scan` at a codebase and an AI agent reads its manifests/README/Dockerfile/CI plus sampled imports, then emits one config per detected framework:

```bash
skill-seekers scan ./my-react-app --out ./configs/scanned/
# → react.json, vite.json, tailwind.json, jest.json, my-react-app-codebase.json
skill-seekers create ./configs/scanned/react.json
```

If a detected framework has no existing preset, the agent generates a fresh config on the fly; you can optionally publish it back to the community config registry on exit.

## Anti-Patterns

- Running `create` on a source you'll only reference once — the setup/packaging round-trip costs more than a direct read for single-use lookups
- Assuming `package --target claude` is the only target — 22 export targets exist (RAG pipelines: LangChain/LlamaIndex/Pinecone; other assistants: Cursor/Windsurf/Cline); pick the target that matches where the skill will actually be consumed
- Re-running `scan` output configs without reviewing them — auto-generated configs for frameworks with no existing preset are agent-generated guesses, not curated presets

## Verification Note

Command syntax and source-type list are drawn directly from the upstream README's Quick Start and source-type sections. The `package`/`scan` output formats and the 22 export targets' exact requirements weren't independently exercised this session (no live run of the CLI).
