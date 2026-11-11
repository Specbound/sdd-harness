---
name: exa-search
description: Exa REST API for semantic search, similar-page lookup, content fetch and answers. Use when you need meaning-based search rather than keywords.
risk: unknown
source: community
---

# exa-search

## What actually runs here

Upstream calls `node .claude/skills/exa-search/exa-api.cjs`. `node` and `npx`
are both absent on this machine and `exa-api.cjs` was never installed, so that
path is dead and is not reproduced below. `curl` works; Exa is plain JSON REST.
Set `EXA_API_KEY` first.

## Endpoints

Base `https://api.exa.ai`. All `POST`, header `x-api-key: $EXA_API_KEY`
(the service also accepts `Authorization: Bearer <key>`), `Content-Type: application/json`.

| Path | Use it for |
|---|---|
| `/search` | semantic search by meaning |
| `/contents` | full text for result ids you already have |
| `/findSimilar` | pages like a URL you give it |
| `/answer` | a direct answer plus its sources |
| `/research` | structured fields shaped by an `output_schema` |

Note the capital S in `/findSimilar`.

## Search

```bash
curl -s https://api.exa.ai/search \
  -H "x-api-key: $EXA_API_KEY" -H "Content-Type: application/json" \
  -d '{"query":"Latest research in LLMs","type":"auto","numResults":10,"category":"research paper","contents":{"text":true,"highlights":true,"summary":true}}'
```

`type`: `neural` (embeddings), `fast` (keyword), `auto` (default), `deep`.
`category`: `company`, `people`, `research paper`, `news`, `pdf`, `github`, `tweet`.
Also accepted: `includeDomains`, `excludeDomains`, `startPublishedDate`,
`endPublishedDate`, `includeText`, `excludeText`, `context`.

## Similar pages, contents, answer

`/findSimilar` takes `url`, `numResults`, `category`, the domain and date
filters above, and `contents`. `/contents` takes `ids` plus `text`,
`highlights`, `summary`. `/answer` takes `query`, `numResults`,
`includeDomains`, `excludeDomains`.

## Response shape

Every endpoint returns `requestId`, `results`, `costDollars`; `/search` adds
`searchType`, and `context` when requested — ask for `context` when the output
feeds a model, `text` when you want the page itself.

## When a call fails

Bad key returns HTTP 401 with `"tag":"INVALID_API_KEY"` and a message pointing
at `https://dashboard.exa.ai/api-keys`. The `tag` field is the thing to branch
on, not the message text.

## Provenance

Base URL, the five endpoint paths and the `x-api-key` header were read out of
upstream's `exa-api.cjs` (`API_BASE`, `ENDPOINT_BY_COMMAND`, request headers).
Field names come from upstream's `SKILL.md` examples. The 401 above is from a
real request to `/search` with an invalid key; that error text is also where
the `Authorization: Bearer` alternative comes from. No authenticated call was
made, so nothing below the auth layer has been checked here.
