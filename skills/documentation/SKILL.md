---
name: documentation
description: Write and generate documentation — READMEs, API references (OpenAPI/REST/GraphQL), long-form architecture manuals, code walkthroughs for onboarding, and step-by-step tutorials. Use when documenting a project, an API, a system's architecture, or explaining/teaching existing code.
---

## When to use
Creating or updating a README, API docs, an architecture/system manual, onboarding walkthroughs that explain existing code, or hands-on tutorials. Pick the matching section below — each sub-area has its own structure and templates in `resources/templates.md`.

**Don't use for:** ad-hoc one-off explanations with no artifact to produce, or wikis/knowledge-base sites specifically (use the wiki skill — it covers page structure, navigation, and publishing).

## Universal principles
- **Docs-as-code**: keep documentation next to the code it describes, generate from source where possible (docstrings → API reference), and review docs on every change that touches the surface it describes — stale docs are worse than none.
- **Examples first, scannable structure**: headers/tables/lists over paragraphs; show a working example before explaining theory; progressive detail (simple → complex).
- **Real data, not `foo`/`bar`**: example payloads, env vars, and commands should be things a reader can actually run.
- Never invent behavior the code doesn't have — if you're unsure what something does, say so or read the code again rather than guessing.

## README

**Before writing, explore the codebase**: identify the language/framework (package.json, go.mod, requirements.txt, Gemfile...), entry points, config/env files (`.env.example`), database/migration setup, and deployment config. Only ask the user questions you can't answer from the repo (what the project is for, credentials, business context).

Detect the deployment target from what's present: `Dockerfile`/`docker-compose.yml` → Docker, `fly.toml` → Fly.io, `render.yaml` → Render, `Procfile` → Heroku-like, `vercel.json`/`.vercel/` → Vercel, `netlify.toml` → Netlify, `k8s/`/`*.tf` → Kubernetes/Terraform. No config found → default to a Docker-based guide.

**Section order:**
1. Title + 2-3 sentence overview + key features
2. Tech stack (language, framework, DB, deploy target)
3. Prerequisites (what must already be installed)
4. Getting started — every command from clone to running locally, nothing assumed
5. Architecture overview — directory structure, request lifecycle, data flow, key components
6. Environment variables — required vs. optional, in a table, with where to get each value
7. Available scripts/commands (table)
8. Testing — how to run, test structure, one example test
9. Deployment — tailored to the detected platform, with rollback steps if the tool supports it
10. Troubleshooting — common errors as "Error / Solution" pairs

Template: `resources/templates.md#readme`.

## API documentation

**Per-endpoint, document:** method + path, auth requirement, path/query/header params with types and required/optional, request body schema, every response status (success and all error codes) with example payloads, and a code example in at least curl + one language SDK.

**Recommended doc site structure:** Introduction (base URL, version) → Authentication → Quick Start → Endpoints (grouped by resource) → Data Models → Error Handling reference → Rate Limiting → Changelog → SDKs/Postman/OpenAPI spec.

**Auth documentation:** show the full token-acquisition flow (e.g. `POST /auth/login` → token + expiry + refresh token), the exact header format (`Authorization: Bearer <token>`), and what happens on expiry (refresh endpoint). For OAuth2/OIDC, document the flow type used, scopes, and redirect handling — don't just say "OAuth2 supported."

**Do:** be consistent across endpoints, document every error code, show realistic data, state parameter constraints (min/max, format), version the API in the URL, link related endpoints, provide a Postman collection or OpenAPI spec.
**Don't:** skip error cases, use vague descriptions ("gets data"), leave examples untested, let docs drift from code without a regeneration step.

**OpenAPI** is the default spec format (3.1+); generate interactive docs from it (Swagger UI/Redoc) rather than hand-maintaining a parallel description. For event-driven/webhook APIs, use AsyncAPI instead and document payload examples + signature verification. For GraphQL, document by query/mutation with variables + response + possible error extensions, not by REST-style endpoint.

Template: `resources/templates.md#api-endpoint` and `#openapi-skeleton`.

## Architecture / system documentation (long-form)

For a manual meant to onboard new engineers or serve as the system's definitive technical reference:
1. **Discovery** — map components, dependencies, data flows, and the design decisions behind them (not just what exists, but why).
2. **Structure** — a chapter hierarchy with progressive disclosure: executive summary → architecture overview → design decisions/rationale → core components (one deep-dive per module) → data models → integration points (APIs/events/external deps) → deployment architecture → performance characteristics → security model → appendix (glossary, references).
3. **Write** top-down: overview before implementation detail, concrete examples from the actual codebase (not generic ones), and a troubleshooting/common-pitfalls section near the end.

Use `file_path:line_number` links into the real source so claims are checkable. This format runs long (10–100+ pages) by design — it's a reference manual, not a quick read.

## Explaining code / onboarding walkthroughs

Use progressive disclosure: **overview** (what it does, key concepts, one-sentence purpose) → **step-by-step** (one section per function/stage, in execution order) → **deep dive** (only for the genuinely non-obvious concepts: async flows, decorators, generators, recursion). Reach for an analogy on the first pass of an unfamiliar concept (e.g. "a generator is a ticket dispenser — one value at a time, not all printed upfront"), then show the real code.

Visualize when a diagram answers a question text can't: a Mermaid `flowchart` for call/data flow, a `classDiagram` for relationships between types, or a traced call stack for recursion. Don't diagram something a two-line sentence already explains.

Call out pitfalls as "Problem → Why it's bad → Better approach", each with a before/after snippet — this is more useful than a text warning.

## Tutorials

**Structure:** opening (what you'll learn, prerequisites, time estimate, preview of the end result) → progressive sections (concept intro with analogy → minimal working example → guided walkthrough → variations → self-directed challenge → troubleshooting) → closing (summary, next steps, further resources).

**Principles:** show the code, then explain it — not the reverse. Each step must run and produce visible output before moving on. Include at least one intentional failure and how to debug it. Exercise types to mix in: fill-in-the-blank, debug-the-broken-code, extend-the-working-example, build-from-spec.

**Before shipping a tutorial, check:** can a beginner follow it without getting stuck, is every code block complete and runnable, are errors anticipated rather than discovered by the reader, does difficulty increase one step at a time.

## Resources
- `resources/templates.md` — README skeleton, API endpoint template, OpenAPI skeleton, changelog (Keep a Changelog), ADR template, llms.txt template.
