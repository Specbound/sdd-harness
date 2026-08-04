---
name: website-spec
description: Query and apply The Website Specification — authoritative web standards covering foundations, SEO, accessibility, security, agent readiness, performance, privacy, resilience, and internationalisation. Use for site audits, quality checks, or when a user asks what a good website should do.
source: https://specification.website
license: MIT
added: 2026-06-02
---

# Website Specification Skill

A live reference for 100+ platform-agnostic web standards, organized by category and status level. Access via the `specification-website` MCP server (registered at `https://mcp.specification.website/mcp`).

## When to activate

- User asks what their website should have, or asks for a site audit
- User asks about agent-readiness: `/llms.txt`, MCP discovery, A2A, structured data for AI
- User asks about web standards: HTTPS, CSP, HSTS, robots.txt, sitemaps, Open Graph, hreflang, etc.
- Code review touches HTML `<head>`, security headers, `robots.txt`, `sitemap.xml`, `manifest.json`, or `/.well-known/` endpoints
- User asks about structured data, JSON-LD, or SEO technical implementation
- User needs a compliance checklist for a deployed site

Do **not** activate for pure code bugs, server-side logic, or non-web-platform work.

## MCP Tools

All tools are on the `specification-website` MCP server.

| Tool | Use for |
|------|---------|
| `audit_url` | Analyze a live URL against the full spec — returns prioritized findings |
| `get_checklist` | Full flat checklist (all categories, all statuses) — use as an audit worksheet |
| `get_topic` | Full content for one topic (e.g. `"content-security-policy"`) |
| `list_topics` | List all available topic slugs |
| `search` | Find topics by keyword when you're not sure of the slug |

**Fallback:** If MCP is unavailable, fetch specs directly: `https://specification.website/<topic>.md` or the full text at `https://specification.website/llms-full.txt`.

## Audit Workflow

When running an audit (either `audit_url` or manual checklist review):

### Phase 1: Required items first
Items marked **required** represent platform-breaking omissions — things that cause indexing failures, security vulnerabilities, or broken user experiences. Always surface these first.

### Phase 2: Recommended items
Items marked **recommended** are modern best practice. Surface after required items are clean.

### Phase 3: Optional / context-dependent
Items marked **optional** depend on the site type, audience, or content. Present as enhancement opportunities, not gaps.

### Never
- Never treat **avoid** items as neutral — they are outdated or harmful patterns
- Never silently upgrade **recommended** to **required**
- Never present optional items as blockers

## Status Levels

| Status | Meaning |
|--------|---------|
| `required` | Platform breaks without it — missing this causes real failures |
| `recommended` | Current best practice, strong reasons to implement |
| `optional` | Context-dependent; may be right for some sites |
| `avoid` | Outdated, insecure, or harmful — don't recommend |

## Categories (10)

| Category | Covers |
|----------|--------|
| Foundations | doctype, lang, charset, viewport, Open Graph, favicons, feeds |
| SEO | robots.txt, sitemaps, URL structure, redirects, JSON-LD, IndexNow |
| Accessibility | WCAG color, alt text, keyboard nav, ARIA, focus, forms, captions |
| Security | HTTPS, HSTS, CSP, security.txt, SRI, cookie attributes, CAA |
| Well-Known URIs | `/.well-known/` endpoints (change-password, OpenID, app-site-association, etc.) |
| Agent Readiness | `/llms.txt`, MCP discovery, A2A agent cards, Agent Skills, DNS-AID, Web Bot Auth |
| Performance | Core Web Vitals, lazy load, cache headers, HTTP/2-3, Speculation Rules |
| Privacy | Privacy policy, cookie consent, GPC, analytics, data minimization |
| Resilience | 404/500 pages, offline support, service workers, monitoring |
| Internationalisation | hreflang, localized metadata, RTL, `lang` attributes, URL structure |

## Agent Readiness (key details)

The "Agent Readiness" category is the newest and least-covered elsewhere. Key items:

- **`/llms.txt`** — machine-readable site index for AI agents (title, description, links to important pages)
- **`/llms-full.txt`** — concatenated full-text version for LLM context ingestion
- **Markdown endpoints** — expose pages as `.md` via URL suffix or `Accept: text/markdown` header
- **MCP/tool discovery** — register an MCP server via `/.well-known/` so agents can discover your site's tools
- **A2A agent cards** — `/.well-known/agent.json` for Agent-to-Agent protocol compatibility
- **Agent Skills** — `/.well-known/agent-skills/index.json` with skills for consuming your content
- **DNS-AID** — DNS record that advertises AI-specific endpoints
- **Web Bot Auth** — authenticated access for verified AI crawlers
- **Stable URLs** — never redirect canonical URLs; stable identifiers are required for agent memory

## Citing sources

When presenting findings:
- Link to the canonical spec page: `https://specification.website/<topic>`
- Note the status level explicitly (required / recommended / optional / avoid)
- Cite the underlying standard where relevant (W3C, WCAG, RFC, MDN) — the spec pages link to these; use them, not the spec itself, for authoritative claims about the standard's requirements
