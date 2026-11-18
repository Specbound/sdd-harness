---
name: tavily-web
description: Tavily REST API for web search, URL extract, crawl, map and research. Use when you need current web results, page text, or a site's page list.
risk: unknown
source: community
---

# tavily-web

## What actually runs on this machine

Upstream drives Tavily through `node .claude/skills/tavily-web/tavily-api.cjs`.
That path does **not** work here and was dropped rather than copied:

- `node` — absent (`command -v node` → nothing)
- `npx` — absent, so the upstream `npx skills add -g BenedictKing/tavily-web` install line cannot run
- `tavily-api.cjs` — never installed; this skill directory holds `SKILL.md` only

`curl` is present, and Tavily is a plain JSON REST API, so every call below is
runnable as-is. Set `TAVILY_API_KEY` in the environment first.

## Endpoints

Base `https://api.tavily.com`. All are `POST`, all take `Authorization: Bearer $TAVILY_API_KEY`
and `Content-Type: application/json`.

| Path | Use it for |
|---|---|
| `/search` | find pages and sources for a query |
| `/extract` | pull text out of URLs you already have |
| `/crawl` | walk a site following an instruction, returning page text |
| `/map` | list a site's pages without fetching their text |
| `/research` | structured output shaped by an `output_schema` you supply |

Pick by intent: a question needs `/search`, a URL in hand needs `/extract`,
"what pages exist" needs `/map`, "read the whole section" needs `/crawl`.

## Search

```bash
curl -s https://api.tavily.com/search \
  -H "Authorization: Bearer $TAVILY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"who is Leo Messi?","topic":"general","search_depth":"basic","max_results":5,"include_answer":false,"include_raw_content":false}'
```

Other fields upstream documents on `/search`: `auto_parameters`, `chunks_per_source`,
`time_range`, `start_date`, `end_date`, `include_images`, `include_image_descriptions`,
`include_favicon`, `include_domains`, `exclude_domains`, `country`, `include_usage`.

## Extract

```bash
curl -s https://api.tavily.com/extract \
  -H "Authorization: Bearer $TAVILY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"urls":"https://en.wikipedia.org/wiki/Artificial_intelligence","extract_depth":"basic","format":"markdown","chunks_per_source":3}'
```

## Crawl and map

Both take `url`, `instructions`, `max_depth`, `max_breadth`, `limit`,
`select_paths`, `select_domains`, `exclude_paths`, `exclude_domains`,
`allow_external`, `timeout`. `/crawl` adds `extract_depth`, `format`,
`include_images`, `include_favicon` — `/map` has no body fields, which is the
difference between them.

Start at `max_depth: 1` and raise it. Depth and breadth multiply, and the cost
is per page fetched.

## Research

`/research` takes `input`, `model` (`"auto"`), `stream`, `citation_format`
(`"numbered"`), and a JSON-Schema `output_schema` with `properties` and
`required`. Use it when you want fields back rather than a page list.

## When a call fails

A missing or wrong key returns HTTP 401 with exactly:

```json
{"detail":{"error":"Unauthorized: missing or invalid API key."}}
```

That body means the key, not the payload. Fix `TAVILY_API_KEY` before touching
the JSON.

## Provenance

Endpoint paths, base URL and the `Authorization: Bearer` header were read out
of upstream's `tavily-api.cjs` (`API_BASE`, `ENDPOINT_BY_COMMAND`, the request
headers). Payload field names come from upstream's own `SKILL.md` examples.
The 401 body above was produced by an actual request to `/search` with an
invalid key. No authenticated call was made — there is no API key here, so no
response shape below the auth layer has been checked.
