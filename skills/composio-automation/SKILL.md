---
name: composio-automation
description: "Automate any of 78+ SaaS apps (Slack, GitHub, Gmail, HubSpot, Stripe, Notion, Jira, Salesforce, and more) via Rube MCP (Composio) — messaging, CRM, project management, payments, docs, calendars. Use whenever a task needs a third-party API call through Composio's unified MCP toolkit."
---

# Composio Automation via Rube MCP

Rube MCP (Composio) exposes 78+ SaaS toolkits through one MCP server. Every toolkit follows
the same connect → discover → act pattern. This skill covers that shared workflow once, then
gives a per-app lookup table (tool-slug prefix + the gotcha most likely to bite).

## Setup

Add `https://rube.app/mcp` as an MCP server in your client config. No API keys needed.

## Connection Flow (identical for every app)

1. Confirm `RUBE_SEARCH_TOOLS` responds — Rube is reachable.
2. Call `RUBE_MANAGE_CONNECTIONS` with the target `toolkit` slug (lowercase app name, e.g.
   `slack`, `github`, `hubspot`).
3. If the connection is not ACTIVE, follow the returned OAuth link, then re-check status.
4. Call `RUBE_SEARCH_TOOLS` scoped to that toolkit before using any tool from it — toolkits
   update their schemas over time; never rely on a remembered shape.

## Tool Discovery & Naming

- Tool slugs follow `PREFIX_VERB_NOUN`, e.g. `SLACK_SEND_MESSAGE`, `GITHUB_CREATE_AN_ISSUE`.
  The per-app table below gives each toolkit's prefix.
- A few apps break the "prefix = app name" rule: ConvertKit tools are `KIT_*` (product
  rebranded to Kit), Cal.com tools are `CAL_*`, Discord bot ops are `DISCORDBOT_*` (vs.
  `DISCORD_*` for user-OAuth ops).
- Always resolve a human-readable name (channel, user, repo, contact, record) to its ID via a
  dedicated FIND/LIST/SEARCH/GET_SCHEMA tool before acting. Never guess or hand-construct an ID.
- If an expected action seems missing, re-run `RUBE_SEARCH_TOOLS` — some toolkits are
  intentionally partial (Make, HelpDesk) and gain tools over time.

## Common Patterns Across Apps

### Pagination
- Cursor-based is most common: follow `next_cursor` / `nextPageToken` / `after` until empty.
- Some apps are page-number based instead (GitHub, GitLab, Freshdesk: `page`/`per_page`).
- Set an explicit page-size limit — defaults are often too small for bulk work.
- De-duplicate by `id` across pages when writes can happen concurrently with reads.

### ID Resolution & Formats
- ID shapes vary a lot and are a top error source: numeric strings (ActiveCampaign,
  ConvertKit), typed-prefixed strings (`cus_`, `lead_`, `srv-`), 24-char hex (Webflow, Trello
  boards), UUIDs (SendGrid Marketing API, Microsoft Teams), GIDs (Asana), URNs (LinkedIn),
  full resource paths (`properties/123456` for Google Analytics). Check the table below before
  assuming a shape, and resolve via the app's own lookup tool rather than inferring one.

### Response Parsing
- Payloads are frequently nested: `response.data`, `response.data.data`, or
  `response.data.results[0].response.data` in wrapped/batch executions. Parse defensively —
  don't assume a top-level shape.
- A success status does not mean a non-empty result — check the actual `total`/`count`/
  `results` field, not just `ok: true` / HTTP 200.

### Rate Limits
- Nearly every toolkit enforces 429s. Default posture: exponential backoff, honor any
  `Retry-After` header, space out bulk operations, and prefer the app's native BATCH/BULK tool
  over N individual calls.

### Safety
- Require explicit user confirmation before: merges, deletes, sends (email/SMS/social posts),
  and any other irreversible action (repo/space deletion, publish, label deletion).
- Destructive tools rarely have an undo — confirm exact scope (which records, which channel)
  before calling them.

## Per-App Reference

| App | Prefix | Gotcha |
|---|---|---|
| ActiveCampaign | `ACTIVE_CAMPAIGN_` | Tag actions ('Add'/'Remove') are capitalized, subscribe actions are lowercase; automations can only be enrolled via API, not created |
| Airtable | `AIRTABLE_` | CREATE/UPDATE/DELETE_MULTIPLE_RECORDS capped at 10/request; field names are case-sensitive (422 UNKNOWN_FIELD_NAME) |
| Amplitude | `AMPLITUDE_` | Event timestamps must be ms (13-digit), not seconds; GET_USER_ACTIVITY needs Amplitude's internal ID, not your user_id |
| Asana | `ASANA_` | All IDs are GIDs (strings); nearly all operations are workspace-scoped |
| BambooHR | `BAMBOOHR_` | Responses carry PII (SSN etc.) — handle with care; GET_ALL_EMPLOYEES is cheaper than per-employee GET |
| Basecamp | `BASECAMP_` | Content is HTML only, never Markdown; updates replace the entire body, not a diff |
| Bitbucket | `BITBUCKET_` | Reviewer UUIDs need curly braces `{uuid}`; some `state` values contain spaces, e.g. `"on hold"` |
| Box | `BOX_` | `fields` param changes response shape; search needs `query` or `mdfilters` |
| Brevo | `BREVO_` | Sender emails must be verified in Brevo first or campaign creation/update fails |
| Cal.com | `CAL_` | Prefix is `CAL_`, not `CAL_COM_`; dates are ISO 8601 |
| Calendly | `CALENDLY_` | Use full URIs, never bare UUIDs; LIST_EVENTS requires exactly one scope (user/org/group) |
| Canva | `CANVA_` | Uploads/exports/autofills are async — poll job status, don't assume completion; download URLs expire |
| CircleCI | `CIRCLECI_` | Project slugs need a VCS prefix (`gh/`, `bb/`); pipeline/workflow IDs are UUIDs, job numbers are ints |
| ClickUp | `CLICKUP_` | `team_id` actually means Workspace ID; dates are Unix **ms**; status is case-sensitive and list-specific |
| Close | `CLOSE_` | IDs are typed-prefixed strings (`lead_`, `cont_`, `acti_`); custom fields referenced by API ID, not label |
| Coda | `CODA_` | Use RESOLVE_BROWSER_LINK to convert URLs to IDs; row values must match the column type |
| Confluence | `CONFLUENCE_` | Content must be XHTML storage format, not Markdown; updates need the exact next `version` number or conflict |
| ConvertKit (Kit) | `KIT_` | Product rebranded to Kit — tools use `KIT_` prefix, not `CONVERTKIT_`; IDs are numeric, not strings |
| Datadog | `DATADOG_` | Timestamps are Unix epoch **seconds** (not ms) on most endpoints |
| Discord | `DISCORD_` / `DISCORDBOT_` | Bot operations use `DISCORDBOT_`; user-OAuth ops use `DISCORD_`; respect Retry-After on 429 |
| DocuSign | `DOCUSIGN_` | 'delivered' means opened, not signed; all IDs are GUIDs — resolve via list/search, never hardcode |
| Dropbox | `DROPBOX_` | Paths must start with `/`, never end with `/`; creating a duplicate shared link returns 409 |
| Figma | `FIGMA_` | GET_FILE_JSON only supports Design files, not FigJam/Slides; node IDs use `-` in URLs but `:` in the API |
| Freshdesk | `FRESHDESK_` | status/priority/source are integer codes, not strings; search is capped at 300 results (10×30) |
| Freshservice | `FRESHSERVICE_` | status/priority/source are numeric codes; default ticket list only returns the last 30 days |
| GitHub | `GITHUB_` | Issue list includes PRs — check the `pull_request` field; verify mergeable status right before merging |
| GitLab | `GITLAB_` | `issue_iid` is project-scoped, don't confuse with global issue ID; `labels` replaces all labels (use add_labels/remove_labels) |
| Gmail | `GMAIL_` | Label ops need the label ID, not name; use `is:` for system states, `label:` only for custom labels |
| Google Analytics | `GOOGLE_ANALYTICS_` | Property IDs need the full `properties/123456` form, not a bare number |
| Google Calendar | `GOOGLECALENDAR_` | No natural-language dates; IANA timezones only; `event_duration_minutes` capped at 59 |
| Google Drive | `GOOGLEDRIVE_` | Upload requires internal S3 storage first; search has no wildcards — use `contains` |
| Google Sheets | `GOOGLESHEETS_` | Unbounded ranges can time out — always bound rows; all value payloads are 2D arrays |
| HelpDesk | `HELPDESK_` | Toolkit is currently read-only (list/read); tickets are siloed — no cross-silo search |
| HubSpot | `HUBSPOT_` | Search/filter needs internal property names, not display labels; batch cap is 100/op |
| Instagram | `INSTAGRAM_` | Media URLs must be public HTTPS; only Business/Creator accounts linked to a FB Page are supported |
| Intercom | `INTERCOM_` | Admin ID required for reply-as-admin/assign/close; replies aren't idempotent — track message IDs |
| Jira | `JIRA_` | Resolve custom field IDs via JIRA_GET_FIELDS before use; assignee needs an account ID, not a username |
| Klaviyo | `KLAVIYO_` | Response nested at `data.data[].attributes`; tag endpoints have tighter rate limits (3/s burst) |
| Linear | `LINEAR_` | Priority is an integer 0–4, not a string name; states/cycles are team-scoped |
| LinkedIn | `LINKEDIN_` | Use full URNs (`urn:li:person:...`), never bare IDs; strict daily posting rate limits |
| Mailchimp | `MAILCHIMP_` | Nested params use double-underscore (`settings__subject__line`); `subscriber_hash` = MD5 of lowercase email |
| Make | `MAKE_` | Toolkit is intentionally limited (ops/enums only, no scenario CRUD) — re-check RUBE_SEARCH_TOOLS periodically |
| Microsoft Teams | `MICROSOFT_TEAMS_` | Never guess IDs (mixed UUID/thread formats) — always resolve via list; 403 usually means missing Graph consent |
| Miro | `MIRO_` | Resolve board IDs via GET_BOARDS2 first; each item type has different required fields |
| Mixpanel | `MIXPANEL_` | Property refs use `properties["name"]` syntax; date ranges are inclusive on both ends |
| Monday.com | `MONDAY_` | `column_type` must be an exact snake_case enum; `column_values` replaces values, so merge manually |
| Notion | `NOTION_` | Pages/databases must be explicitly shared with the integration or they're invisible to it |
| OneDrive | `ONE_DRIVE_` | No KQL/wildcards in search, keywords only; never use web/sharing-link URLs as item IDs |
| Outlook | `OUTLOOK_` | SEARCH_MESSAGES needs an M365/Enterprise account; personal accounts have limited API access |
| Outlook Calendar | `OUTLOOK_CALENDAR_` | OData filters are strict (not all properties filterable, e.g. createdDateTime); attendee PATCH replaces the full list |
| PagerDuty | `PAGERDUTY_` | References need an explicit `type` field (`service_reference`, `user_reference`); incident status moves forward-only |
| Pipedrive | `PIPEDRIVE_` | `visible_to` is numeric (1/3/5); `done` on activities is int 0/1, not boolean |
| PostHog | `POSTHOG_` | System events use a `$` prefix, custom events must not; project ID required for nearly everything |
| Postmark | `POSTMARK_` | Tokens are per-server, not per-account; batch send capped at 500 messages |
| Reddit | `REDDIT_` | IDs need a fullname prefix (e.g. `t3_`); new accounts throttled to ~1 post/10min |
| Render | `RENDER_` | Service/deploy IDs are prefixed (`srv-`, `dep-`); deploys are async and don't auto-rollback on failure |
| Salesforce | `SALESFORCE_` | Use field API names, not labels; custom fields end in `__c`; IDs can be 15 or 18 chars |
| Segment | `SEGMENT_` | Every call needs `userId` or `anonymousId`; use ALIAS only once per identity merge |
| SendGrid | `SENDGRID_` | Don't mix legacy Contact DB IDs with Marketing API IDs; `send_at` on single sends only sets a UI default, doesn't schedule |
| Sentry | `SENTRY_` | Org/project are referenced by slug, not display name |
| Shopify | `SHOPIFY_` | REST capped at 2 req/s, GraphQL uses 1000 cost points/s — pick the right API for volume |
| Slack | `SLACK_` | SEND_MESSAGE needs channel ID + one of markdown_text/text/blocks; FETCH_CONVERSATION_HISTORY excludes thread replies |
| Square | `SQUARE_` | UPDATE_ORDER/CANCEL_INVOICE need the current `version` field or get 409; amounts are smallest currency unit |
| Stripe | `STRIPE_` | Amounts are smallest currency unit (cents), except zero-decimal currencies (JPY, KRW); IDs are typed-prefixed (`cus_`, `ch_`, `sub_`) |
| Supabase | `SUPABASE_` | Project ref is exactly 20 lowercase a-z chars; SQL needs Postgres array syntax `ARRAY[...]`, not JSON `[...]`; never expose service-role keys |
| Telegram | `TELEGRAM_` | Bot must be added to a group/channel first and can't DM-initiate; text messages capped at 4096 chars |
| TikTok | `TIKTOK_` | OAuth token needs `video.upload`/`video.publish` scopes explicitly; strict daily upload limits |
| Todoist | `TODOIST_` | Filter terms must reference real projects/labels or 400s; `completed` filter doesn't work on GET_ALL_TASKS |
| Trello | `TRELLO_` | Board ID must be 24-char hex or 8-char shortLink, not a URL slug; 300 req/10s per token |
| Twitter/X | `TWITTER_` | Post creation is not idempotent; rate limits vary drastically by access tier (free tier ~1,500 posts/month) |
| Vercel | `VERCEL_` | Secret env vars are write-only, can't be retrieved after creation; redeploy needed for env var changes to take effect |
| Webflow | `WEBFLOW_` | All IDs are 24-char hex (Mongo ObjectIds); CMS ops need field `slug`, not display name; PUBLISH_SITE deploys ALL staged changes |
| WhatsApp | `WHATSAPP_` | Phone numbers must be E.164; business-initiated messages outside the 24h window require paid templates |
| Wrike | `WRIKE_` | All IDs are opaque alphanumeric strings, never guess; DELETE_FOLDER/DELETE_SPACE are destructive — confirm before calling |
| YouTube | `YOUTUBE_` | Daily quota budget (10k units default) — upload costs 1600, search 100, list 1; prefer list over search |
| Zendesk | `ZENDESK_` | Tag updates REPLACE all tags — fetch current tags and merge first; tags are lowercase, underscore-separated |
| Zoho CRM | `ZOHO_` | Use API names, not display labels (`Last_Name`); picklist values are case-sensitive exact matches |
| Zoom | `ZOOM_` | Most recording/participant features need Pro plan+; webinar features need the add-on |

## When to Use

Use this skill whenever a task requires calling a third-party SaaS API through Rube/Composio
MCP, for any app above. Treat the table as a quick-start, not ground truth — always call
`RUBE_SEARCH_TOOLS` for the current schema before relying on a remembered tool signature.
