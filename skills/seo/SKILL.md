---
name: seo
description: Technical, on-page, and content SEO — audits, metadata, keyword/content strategy, featured snippets, internal linking, schema markup, and programmatic-page feasibility. Use for SEO audits, metadata fixes, content planning/refresh, structured data, or scaling templated pages.
---

# SEO

Evidence-based, scoped, and prioritized. Never claim guaranteed rankings; score
readiness, state assumptions, cite evidence for every finding.

## Diagnostic-First Workflow

For audits, schema decisions, and programmatic-page proposals, score 0-100
across weighted categories (start each at 100, subtract by severity: Critical
-15 to -30, High -10, Medium -5, Low -1 to -3; halve the deduction at Medium
confidence, quarter it at Low). Classify into bands (≥85 strong/excellent,
70-84 good/limited, 55-69 fair/high-risk, <55 do-not-proceed). A high score
with unresolved Critical issues is invalid — flag the inconsistency. State
what limits the score from being higher; don't replace findings with the number.

Before a full audit, clarify if missing: site type & primary goal (traffic/
leads/conversions), scope (full site vs. section, technical/on-page/content),
and data access (Search Console, analytics, known migrations/penalties). State
assumptions explicitly rather than blocking.

## Core Fundamentals

**E-E-A-T** — rank by signal strength: Experience (first-hand use, original
photos/data) > Expertise (credentials, depth) > Authoritativeness (citations,
backlinks from relevant sites) > Trust (accurate info, secure site, transparent
policies, author bios with real credentials). Weakest link often capped by Trust.

**Core Web Vitals** (field data, not lab): LCP < 2.5s, INP < 200ms, CLS < 0.1.
Contributors: server response time, image sizing/formats, JS execution cost,
CSS delivery, caching/CDN, font loading.

**Relative impact (high → low):** crawlability/indexation > content quality &
search-intent match > Core Web Vitals/mobile > title/meta tags > internal
linking/structure > schema markup > backlinks (slow to build, high value) >
minor on-page tweaks.

**AI-written content:** effective when it adds genuine research/data/expertise
and is edited for accuracy; risky when published unedited, generic, or at
volume with no E-E-A-T signal — Google targets low-value mass content, not the
authorship method itself.

## Technical & Crawlability Audit

- **Robots.txt**: no accidental blocking of important paths; sitemap referenced.
- **XML sitemap**: valid, only canonical/indexable URLs, submitted successfully.
- **Architecture**: key pages ≤3 clicks deep, no orphan pages, logical hierarchy.
- **Indexation**: coverage vs. expected pages; check for incorrect `noindex`,
  canonical conflicts, redirect chains/loops, soft 404s, unconsolidated duplicates.
- **Canonicalization**: self-referencing canonicals, HTTPS/www consistency,
  consistent trailing-slash rule.
- **Mobile**: responsive, correct viewport, no horizontal scroll, content parity
  with desktop (mobile-first indexing).
- **Security**: HTTPS everywhere, valid certs, no mixed content.
- **Large sites**: parameter handling, faceted-nav controls, crawlable
  pagination (not infinite-scroll-only), no session IDs in URLs.

## On-Page & Content Audit

- **Headings**: exactly one H1, logical H2/H3 hierarchy reflecting content structure.
- **Images**: descriptive filenames, accurate alt text, compressed, lazy-loaded.
- **Internal links**: descriptive anchor text, reinforce important pages, no
  broken links, balanced distribution — not all equity to the homepage.
- **Content**: satisfies search intent, sufficient depth, natural keyword use,
  doesn't compete with another internal page for the same query (see
  Cannibalization below).

**Keyword density** (guideline, not a hard rule): primary keyword 0.5-1.5% of
body text; generate 20-30 related/LSI variations from entity and
"People Also Ask" analysis rather than repeating the exact phrase. Flag
over-optimization: unnatural phrase repetition, keyword stuffing in alt text/
headers, exact-match anchor text overused in internal links.

**Freshness refresh priority:** High — rankings dropped, stats/examples >2yrs
old on a high-traffic declining page, seasonal content pre-season. Medium —
traffic flat 6mo+, a competitor recently updated a page outranking this one.
Refresh tactics: update stats/dates, add sections covering new sub-topics,
re-check internal/outbound links, expand thin sections, don't just change the
publish date without substantive changes (Google and users both notice).

## Content Strategy & Writing

**Topic clusters**: one pillar page (broad topic, links out) + supporting
articles (narrow sub-topics, link back to pillar) + FAQ/glossary/how-to/
comparison pages filling intent gaps. Plan a calendar by cluster, not by
random topic — finish a cluster before starting the next.

**Writing framework**: intro states the answer/value in 50-100 words (don't
bury the lede for SEO padding) → body in 2-3 sentence paragraphs with
sub-headers every 200-300 words → conclusion with a clear next step. Target
Grade 8-10 reading level unless the audience is specialist.

## Metadata

| Element | Limit | Rule |
|---|---|---|
| URL | <60 chars | lowercase, hyphens, primary keyword, no stop-word stuffing |
| Title tag | 50-60 chars | primary keyword in first 30 chars, unique per page, no auto-truncation |
| Meta description | 150-160 chars | includes a reason to click (benefit/CTA), unique, not auto-generated boilerplate |

Power words and a concrete benefit beat generic phrasing ("Compare 12
pricing plans" beats "Pricing Information"). Never duplicate titles or
descriptions across pages — treat as a cannibalization smell.

## Featured Snippets

Match format to query type: **Paragraph** (40-60 words, direct answer
immediately after a question-phrased H2/H3) for "what is"/"why" queries;
**List** (5-8 short items under a header) for "how to"/"best"/steps; **Table**
for comparisons/specs/pricing. Lead with the direct answer, then elaborate —
Google extracts the first qualifying block, not the most thorough one.

## Structure & Internal Linking

One H1 per page; H2 for major sections, H3 for subsections — headings must
mirror the actual content tree, not just keyword targets. Silo related content
together (cluster hub links to and from its spokes) to concentrate topical
relevance. Schema priority for structure: Organization/WebSite sitewide →
BreadcrumbList wherever breadcrumbs exist visually → page-type-specific schema
(see Schema Markup below).

## Keyword Cannibalization

**Detect**: two+ pages targeting the same primary keyword/intent — check for
overlapping titles/meta, near-duplicate content, or both ranking (weakly) for
the same query in Search Console.

**Prevent**: one page per distinct search intent, keyword-to-URL mapping
before writing, differentiate angle (comparison vs. tutorial vs. pricing) even
within a shared topic.

**Resolve**: merge the weaker page into the stronger + 301 redirect (most
common fix); rewrite one for a genuinely distinct intent; canonicalize to the
primary if both must stay live for non-SEO reasons (e.g. different CTAs).

## Schema Markup

Implement only when the eligibility score (Content-Schema Alignment 25,
Google Rich-Result Eligibility 25, Data Completeness 20, Technical Correctness
15, Maintenance Sustainability 10, Spam/Policy Risk 5) scores ≥70 — automatic
failure if the schema describes content not visibly shown on the page.

**Core rules**: schema must match visible content exactly; follow Google's
supported-type docs over the full schema.org spec (schema.org permits more
than Google rewards); minimal purposeful markup, not maximal; validate before
and after deploy.

| Type | Use for | Key constraint |
|---|---|---|
| Organization / WebSite+SearchAction | Sitewide brand/search box | One per site |
| Article / BlogPosting | Editorial content | Clear authorship required |
| Product | Real purchasable items | Must show price/availability/offers visibly |
| SoftwareApplication | SaaS/tools | — |
| FAQPage | Visible Q&A, not promo copy | No unmoderated user-generated content |
| HowTo | Genuine step-by-step instructions | Not marketing funnels |
| BreadcrumbList | Wherever breadcrumbs render | Must match visible nav |
| LocalBusiness | Real physical locations | — |
| Review / AggregateRating | Genuine reviews only | No self-serving ratings |
| Event | Real events, clear dates | Availability must be current |

Use `@graph` for multiple entities on one page: one primary entity, others
must relate logically, avoid conflicting definitions. Validate with Google
Rich Results Test, Schema.org Validator, and Search Console Enhancements —
common failures: missing required properties, mismatched/fabricated values,
wrong enum values, dates not in ISO 8601.

## Programmatic SEO (scaled page generation)

Score feasibility before building a template (Search Pattern Validity 20,
Unique Value per Page 25 — the single most important factor, Data
Availability & Quality 20, Search Intent Alignment 15, Competitive Feasibility
10, Operational Sustainability 10). Bands: ≥80 strong fit, 65-79 moderate,
50-64 high risk, <50 do not proceed.

**Core test**: "why does this page deserve to exist separately from every
other page in the set?" — if the only difference is a swapped noun, it fails.
Data defensibility, best to worst: proprietary > product-derived > user-
generated (moderated) > licensed > public/scraped. 100 genuinely useful pages
beat 10,000 thin ones — thin-content penalties apply to the whole template,
not just weak instances.

**Common playbooks**: location pages, comparison pages ("X vs Y"), integration
pages, glossary/definition pages, persona pages, directory/profile pages —
each needs a distinct data source and genuine per-page value, not just a
mail-merged headline.

**Quality gate before indexing**: sample pages pass the same eligibility bar
as hand-written content; kill switch criteria defined upfront (e.g. thin
engagement, manual-action risk, data staleness) so weak segments can be
de-indexed without a full rebuild.

## Output Format

State score + band, then findings as Issue → Category → Evidence → Severity →
Confidence → Why It Matters → Recommendation. Group the action plan: Critical
Blockers → High-Impact → Quick Wins → Longer-Term. Reference tools only as
evidence sources (Search Console, PageSpeed Insights, crawlers, log analysis)
— never report a tool's own "score" without interpreting what it shows.

For a quick automated pass on static HTML/JSX/TSX (missing title/meta
description/OG tags, multiple H1s, missing image alt), run
`python3 skills/seo/scripts/seo_checker.py <path>`.
