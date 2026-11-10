---
name: context7-auto-research
description: "Fetch current library/framework docs and code snippets from the Context7 API with curl — no API key needed. Use when a library's API surface, config, or version behaviour may be stale."
risk: unknown
source: community (BenedictKing/context7-auto-research, re-derived)
---

# context7-auto-research

Context7 indexes library docs and returns ranked snippets. Two GET endpoints, both
usable **without an API key**.

## Node is not installed here

Upstream drives this through `node .claude/skills/context7-auto-research/context7-api.cjs`.
`command -v node`, `npx`, `bun` all return nothing on this machine and the `.cjs` is not
installed. That path is dead; use `curl` directly. Base URL, query params and the auth
header below were read out of the upstream `context7-api.cjs`, then confirmed by calling
the live API.

## Step 1 — resolve the library ID

```bash
curl -s "https://context7.com/api/v2/libs/search?libraryName=react&query=hooks"
```

Returns `results[]`, each with `id` (e.g. `/reactjs/react.dev`), `title`, `description`,
`trustScore`, `totalSnippets`, `lastUpdateDate`, `versions`. Pick by `trustScore` and
whether `title` matches the library actually in use — name collisions are common.

## Step 2 — fetch docs for that ID

```bash
# type=txt — prose + code, best for reading
curl -s "https://context7.com/api/v2/context?libraryId=/reactjs/react.dev&query=useEffect+cleanup&type=txt"

# type=json — codeSnippets[] with codeTitle/codeDescription/codeLanguage/codeList/rank
curl -s "https://context7.com/api/v2/context?libraryId=/reactjs/react.dev&query=useEffect+cleanup&type=json"
```

Use `type=txt` unless you are post-processing. `type=json` buries the same content one
level deeper for no gain when the consumer is a reader.

URL-encode the query (`+` or `%20` for spaces). `libraryId` keeps its leading slash.

## API key: optional, and a wrong one is worse than none

| Auth | Result |
|---|---|
| no header | **200**, real results — verified on both endpoints |
| `Authorization: Bearer <valid ctx7sk-… key>` | 200, higher rate limit |
| `Authorization: Bearer <invalid>` | **401** `{"error":"invalid_api_key","message":"… API keys should start with 'ctx7sk' prefix."}` |

So do not send `CONTEXT7_API_KEY` unless it is set and valid — upstream's runner sends an
empty `Authorization` header when the var is unset, which is the one shape that can only
hurt. Omit the flag instead. Keys come from `https://context7.com/dashboard`.

Anonymous rate limit is published in response headers: `ratelimit-limit: 200`,
`ratelimit-remaining`, `ratelimit-reset` (unix seconds). Check `ratelimit-remaining`
with `curl -D -` before a batch of lookups.

## When to reach for this vs. not

- **Use it** for a library's current API surface, config keys, migration steps, or
  anything where "which version" changes the answer.
- **Skip it** for language/stdlib questions, for a library vendored in this repo (read
  the source), and for conceptual questions — it returns snippets, not explanations.
- One `/context` call per question. Resolving the ID again for a follow-up on the same
  library is a wasted round trip; reuse the `id` from step 1.

## Verified / not verified

Both endpoints were called live and returned 200 anonymously; the 401 body above is a
real response to a deliberately invalid key. Not verified: behaviour under a valid key,
and the rate limit for authenticated callers.
