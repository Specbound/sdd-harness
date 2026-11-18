---
name: firecrawl-scraper
description: "Scrape a page to markdown, a screenshot, PDF text, or schema JSON via the Firecrawl API with curl. Use when a page needs JS rendering, clicking/scrolling, or main-content extraction."
risk: unknown
source: community (BenedictKing/firecrawl-scraper, re-derived)
---

# firecrawl-scraper

Firecrawl renders a page in a real browser and returns markdown, HTML, links, a
screenshot, or schema-shaped JSON.

## Node is not installed here

Upstream drives this through `node .claude/skills/firecrawl-scraper/firecrawl-api.cjs`.
`command -v node`, `npx`, `bun` all return nothing on this machine and the `.cjs` is not
installed. That path is dead; use `curl`. Base URL and endpoint paths below come from
`ENDPOINT_BY_COMMAND` in the upstream runner, then were called live.

## What works without an API key

Firecrawl runs a **keyless free tier**. Verified by calling each endpoint with no
`Authorization` header:

| Endpoint | Keyless | Evidence |
|---|---|---|
| `POST /v2/scrape` | **works (200)** | markdown, screenshot and json formats all returned data |
| `POST /v2/map` | 401 | `"This endpoint is not supported by the keyless free tier."` |
| `POST /v2/crawl` | 401 | same message |
| `POST /v2/batch/scrape` | 401 | same message |
| `POST /v2/extract` | 401 | same message |

**A wrong key is worse than no key**: `Authorization: Bearer <invalid>` on `/v2/scrape`
returns `401 {"success":false,"error":"Unauthorized: Invalid token"}`, where omitting the
header entirely returns 200. Only send the header when `FIRECRAWL_API_KEY` is set.

**Upstream documents one dead path.** Its SKILL.md and runner use `/v2/batch-scrape`,
which returns `404 {"code":"NOT_FOUND","error":"POST /v2/batch-scrape is not a Firecrawl
API endpoint."}`. The live path is `/v2/batch/scrape` (slash, not hyphen) — still
key-gated, but at least real.

## Scrape a page

```bash
curl -s -X POST https://api.firecrawl.dev/v2/scrape \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","formats":["markdown"],"onlyMainContent":true,"excludeTags":["nav","footer"],"timeout":30000}'
```

Response: `{"success":true,"data":{"markdown":"…","metadata":{"title","sourceURL","statusCode",…}}}`.

**Formats** — `"markdown"`, `"html"`, `"rawHtml"`, `"links"`, `"images"`, `"summary"`, plus
two object forms:

```jsonc
{"type":"screenshot","fullPage":true,"quality":85}
{"type":"json","prompt":"Extract product info","schema":{"type":"object","properties":{…},"required":[…]}}
```

A screenshot returns `data.screenshot` as a **signed, expiring Google Storage URL**, not
image bytes — download it in the same session or it goes stale.

## Interact with the page before scraping

```bash
curl -s -X POST https://api.firecrawl.dev/v2/scrape \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","formats":["markdown"],
       "actions":[{"type":"wait","milliseconds":2000},
                  {"type":"click","selector":"#load-more"},
                  {"type":"scroll","direction":"down","amount":500}]}'
```

Action types: `wait`, `click`, `write`, `press`, `scroll`, `screenshot`, `scrape`,
`executeJavascript`.

## Parse a PDF

```bash
-d '{"url":"https://example.com/doc.pdf","formats":["markdown"],"parsers":["pdf"]}'
```

## With a key: crawl and map

```bash
# whole site, depth- and path-filtered — returns a job id
curl -s -X POST https://api.firecrawl.dev/v2/crawl \
  -H "Authorization: Bearer $FIRECRAWL_API_KEY" -H "Content-Type: application/json" \
  -d '{"url":"https://docs.example.com","formats":["markdown"],"includePaths":["^/docs/.*"],"maxDiscoveryDepth":3,"limit":100}'

# poll it
curl -s "https://api.firecrawl.dev/v2/crawl/<id>" -H "Authorization: Bearer $FIRECRAWL_API_KEY"

# just the URL list — much cheaper than crawling
curl -s -X POST https://api.firecrawl.dev/v2/map \
  -H "Authorization: Bearer $FIRECRAWL_API_KEY" -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","search":"documentation","limit":5000}'
```

Crawl is asynchronous: it returns an id, and completion statuses are `completed` /
`complete` / `done` / `success` / `succeeded` / `finished`; failures are `failed` /
`error` / `cancelled` / `canceled`.

## When not to use it

Each scrape is a browser render — slow and metered. For a static page that `curl` already
returns readable HTML for, skip it. Reach for Firecrawl when the content is JS-rendered,
needs clicking/scrolling, is a PDF, or you want main-content extraction rather than the
whole DOM.

## Verified / not verified

`/v2/scrape` was called live, keyless, with markdown, screenshot and json formats — all
200. The 401 and 404 bodies above are real responses. Not verified: everything behind the
key (crawl, map, batch, extract response shapes), since no `FIRECRAWL_API_KEY` is present
here. Those are the upstream runner's claims.
