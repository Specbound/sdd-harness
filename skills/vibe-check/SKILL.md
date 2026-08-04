---
name: vibe-check
description: "Run a vibe-check report on changed code. Audits diffs across 10 dimensions: blast radius, assumptions, threat model, auth, data flow, sensitive data, failure behavior, tests, maintainability, and deployability. Use when asked to vibe-check, review changes holistically, or audit a diff."
risk: safe
---

# Vibe Check

Produce a structured report across 10 quality dimensions for all code changed on the current branch.

## When to Use This Skill

Use this skill when:
- Asked to run a vibe-check
- Reviewing a diff or PR holistically
- Wanting a health summary before merging
- Auditing changed code for hidden risks

## Phase 1: Gather the Diff

1. Run: `git diff $(git merge-base HEAD main)...HEAD`
2. If truncated, read each changed file individually until every changed line is seen
3. List all modified files before proceeding

## Phase 2: Run All 10 Checks

Work through each check in order. For each one, collect findings before writing the report.

---

### Check 1 — Blast Radius (Explain the Diff Like the On-Call Engineer)

> "Summarize what changed, what behavior changed, and what could break."

Look for:
- Behavior changes (not just feature additions)
- Database migrations or schema changes
- Config or environment variable changes
- New dependencies or permissions introduced
- Any side effects on existing functionality

---

### Check 2 — Silent Assumptions

> "List assumptions about inputs, ordering, time, environment, and external services."

Look for:
- Fields assumed to always be present
- Assumed request/event ordering
- Hardcoded timeouts, limits, or environment values
- Assumed reliability of external APIs or services
- Anything that fails silently if the assumption is wrong

---

### Check 3 — Threat Model

> "Entry points, roles, assets, abuse cases, and mitigations."

Look for:
- Where untrusted data enters the system
- What assets are at risk (data, money, accounts)
- What user roles exist and if they're enforced
- Obvious abuse paths not yet mitigated

---

### Check 4 — Auth Coverage

> "Flag any route that lacks server-side enforcement."

Look for:
- Routes or handlers missing authentication checks
- Authorization gaps (authenticated but not authorized)
- Client-side-only access control
- Privilege escalation paths

---

### Check 5 — Untrusted Input to Sensitive Sinks

> "DB writes, shell, templates, deserialization, HTML output — show me the paths."

Trace data from:
- Sources: query params, request body, headers, webhooks, file uploads
- Sinks: SQL queries, shell commands, template rendering, HTML output, deserialization

---

### Check 6 — Sensitive Data Handling

> "Fields collected/stored/returned/logged; highlight over-collection and log leakage."

Look for:
- PII, passwords, tokens, API keys, or secrets
- Data logged or returned that shouldn't be
- Over-collection (collecting more than needed)
- Missing masking/redaction in logs or error messages

---

### Check 7 — Failure Behavior

> "Timeouts, retries/backoff, circuit breakers, idempotency — what happens when X is down?"

Look for:
- Missing or hardcoded timeouts on external calls
- Unbounded retries without backoff
- No circuit breaker for repeated failures
- Non-idempotent operations that could double-execute
- What happens if the queue, DB, or downstream API is unavailable

---

### Check 8 — Test Coverage

> "Happy path + top edge cases + one 'evil input' test per trust boundary."

Look for:
- Happy-path coverage for new behavior
- Edge cases: nulls, empty strings, unicode, large inputs
- Adversarial inputs at trust boundaries (user input, webhooks, file uploads)
- Gaps in existing tests that new code bypasses

---

### Check 9 — Maintainability Debt

> "Suggest reuse/refactors; identify new deps that could be removed."

Look for:
- Duplicated logic that could be extracted
- New dependencies that duplicate existing ones
- Inconsistent naming or style with the rest of the codebase
- Premature complexity or over-engineering
- Dead code introduced

---

### Check 10 — Deploy / Observe / Rollback Readiness

> "Required env vars validated, migrations safe, logs/metrics exist, and rollback steps documented."

Look for:
- New env vars with no validation or defaults
- Backwards-incompatible migrations (column drops, type changes, NOT NULL without defaults)
- Missing logs or metrics on new code paths
- No clear rollback path if this deploy goes bad

---

## Phase 3: Write the Report

Output a structured report with this format:

---

## Vibe Check Report

**Branch**: `<branch name>`
**Files changed**: `<count>`
**Overall vibe**: 🟢 Clean / 🟡 Needs Attention / 🔴 Do Not Ship

---

### 1. Blast Radius
**Summary**: <what changed and what behaviors shifted>
**Risks**: <list any breakage risks>

---

### 2. Silent Assumptions
**Findings**: <list untested assumptions, or "None found">

---

### 3. Threat Model
**Entry points**: <list>
**Assets at risk**: <list>
**Gaps**: <list mitigations missing, or "None found">

---

### 4. Auth Coverage
**Gaps**: <unprotected routes/handlers, or "All routes protected">

---

### 5. Input → Sink Paths
**Risky paths**: <source → sink with file:line, or "None found">

---

### 6. Sensitive Data
**Issues**: <over-collection, log leakage, or "None found">

---

### 7. Failure Behavior
**Issues**: <missing timeouts, retry risks, idempotency gaps, or "Adequately handled">

---

### 8. Test Coverage
**Gaps**: <missing tests by category, or "Adequate coverage">

---

### 9. Maintainability Debt
**Issues**: <duplication, bad deps, style drift, or "None found">

---

### 10. Deploy Readiness
**Blockers**: <missing env vars, unsafe migrations, no rollback path, or "Ready to deploy">

---

### Action Items

| Priority | Check | Issue | Suggested Fix |
|----------|-------|-------|---------------|
| 🔴 Critical | ... | ... | ... |
| 🟡 Medium | ... | ... | ... |
| 🟢 Low | ... | ... | ... |

---

**Do not make changes — report findings only. The developer decides what to address.**
