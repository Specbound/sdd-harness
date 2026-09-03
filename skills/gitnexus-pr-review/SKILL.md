---
name: gitnexus-pr-review
description: "Use when the user wants to review a pull request, understand what a PR changes, assess risk of merging, or check for missing test coverage. Examples: \"Review this PR\", \"What does PR #42 change?\", \"Is this PR safe to merge?\""
---

# PR Review with GitNexus

## When to Use

- "Review this PR"
- "What does PR #42 change?"
- "Is this safe to merge?"
- "What's the blast radius of this PR?"
- "Are there missing tests for this PR?"
- Reviewing someone else's code changes before merge

## Workflow

```
1. gh pr diff <number>                                    → Get the raw diff
2. mcp__gitnexus__detect_changes({scope: "compare", base_ref: "main"})  → Map diff to affected flows
3. For each changed symbol:
   mcp__gitnexus__impact({target: "<symbol>", direction: "upstream"})    → Blast radius per change
4. mcp__gitnexus__context({name: "<key symbol>"})               → Understand callers/callees
5. READ gitnexus://repo/{name}/processes                   → Check affected execution flows
6. Summarize findings with risk assessment
```

> If "Index is stale" → run `npx gitnexus analyze` in terminal before reviewing.

## Checklist

```
- [ ] Fetch PR diff (gh pr diff or git diff base...head)
- [ ] mcp__gitnexus__detect_changes to map changes to affected execution flows
- [ ] mcp__gitnexus__impact on each non-trivial changed symbol
- [ ] Review d=1 items (WILL BREAK) — are callers updated?
- [ ] mcp__gitnexus__context on key changed symbols to understand full picture
- [ ] Check if affected processes have test coverage
- [ ] Assess overall risk level
- [ ] Write review summary with findings
```

## Review Dimensions

| Dimension | How GitNexus Helps |
| --- | --- |
| **Correctness** | `context` shows callers — are they all compatible with the change? |
| **Blast radius** | `impact` shows d=1/d=2/d=3 dependents — anything missed? |
| **Completeness** | `detect_changes` shows all affected flows — are they all handled? |
| **Test coverage** | `impact({includeTests: true})` shows which tests touch changed code |
| **Breaking changes** | d=1 upstream items that aren't updated in the PR = potential breakage |

## Risk Assessment

| Signal | Risk |
| --- | --- |
| Changes touch <3 symbols, 0-1 processes | LOW |
| Changes touch 3-10 symbols, 2-5 processes | MEDIUM |
| Changes touch >10 symbols or many processes | HIGH |
| Changes touch auth, payments, or data integrity code | CRITICAL |
| d=1 callers exist outside the PR diff | Potential breakage — flag it |

## Tools

**mcp__gitnexus__detect_changes** — map PR diff to affected execution flows:

```
mcp__gitnexus__detect_changes({scope: "compare", base_ref: "main"})

→ Changed: 8 symbols in 4 files
→ Affected processes: CheckoutFlow, RefundFlow, WebhookHandler
→ Risk: MEDIUM
```

**mcp__gitnexus__impact** — blast radius per changed symbol:

```
mcp__gitnexus__impact({target: "validatePayment", direction: "upstream"})

→ d=1 (WILL BREAK):
  - processCheckout (src/checkout.ts:42) [CALLS, 100%]
  - webhookHandler (src/webhooks.ts:15) [CALLS, 100%]

→ d=2 (LIKELY AFFECTED):
  - checkoutRouter (src/routes/checkout.ts:22) [CALLS, 95%]
```

**mcp__gitnexus__impact with tests** — check test coverage:

```
mcp__gitnexus__impact({target: "validatePayment", direction: "upstream", includeTests: true})

→ Tests that cover this symbol:
  - validatePayment.test.ts [direct]
  - checkout.integration.test.ts [via processCheckout]
```

**mcp__gitnexus__context** — understand a changed symbol's role:

```
mcp__gitnexus__context({name: "validatePayment"})

→ Incoming calls: processCheckout, webhookHandler
→ Outgoing calls: verifyCard, fetchRates
→ Processes: CheckoutFlow (step 3/7), RefundFlow (step 1/5)
```

## Example: "Review PR #42"

```
1. gh pr diff 42 > /tmp/pr42.diff
   → 4 files changed: payments.ts, checkout.ts, types.ts, utils.ts

2. mcp__gitnexus__detect_changes({scope: "compare", base_ref: "main"})
   → Changed symbols: validatePayment, PaymentInput, formatAmount
   → Affected processes: CheckoutFlow, RefundFlow
   → Risk: MEDIUM

3. mcp__gitnexus__impact({target: "validatePayment", direction: "upstream"})
   → d=1: processCheckout, webhookHandler (WILL BREAK)
   → webhookHandler is NOT in the PR diff — potential breakage!

4. mcp__gitnexus__impact({target: "PaymentInput", direction: "upstream"})
   → d=1: validatePayment (in PR), createPayment (NOT in PR)
   → createPayment uses the old PaymentInput shape — breaking change!

5. mcp__gitnexus__context({name: "formatAmount"})
   → Called by 12 functions — but change is backwards-compatible (added optional param)

6. Review summary:
   - MEDIUM risk — 3 changed symbols affect 2 execution flows
   - BUG: webhookHandler calls validatePayment but isn't updated for new signature
   - BUG: createPayment depends on PaymentInput type which changed
   - OK: formatAmount change is backwards-compatible
   - Tests: checkout.test.ts covers processCheckout path, but no webhook test
```

## Review Output Format

Structure your review as:

```markdown
## PR Review: <title>

**Risk: LOW / MEDIUM / HIGH / CRITICAL**

### Changes Summary
- <N> symbols changed across <M> files
- <P> execution flows affected

### Findings
1. **[severity]** Description of finding
   - Evidence from GitNexus tools
   - Affected callers/flows

### Missing Coverage
- Callers not updated in PR: ...
- Untested flows: ...

### Recommendation
APPROVE / REQUEST CHANGES / NEEDS DISCUSSION
```

## Structured Output Contract (review.json)

When invoked by an automated caller (e.g. `scripts/pr/log_review.sh`, or the
`review-pull-requests.yml` GitHub Action's read-only "review" job), ALSO write a
machine-readable `review.json` alongside the markdown review above, matching this
schema exactly:

```json
{
  "verdict": "APPROVE | REJECT",
  "body": {
    "overview": "1-3 sentence summary",
    "concerns": ["short bullet", "..."],
    "issue_count": 0,
    "recommendation": "APPROVE | REQUEST CHANGES | NEEDS DISCUSSION"
  },
  "comments": [
    {
      "path": "relative/file/path.ts",
      "line": 42,
      "side": "RIGHT",
      "start_line": 40,
      "start_side": "RIGHT",
      "body": "CRITICAL: description of the finding"
    }
  ]
}
```

Rules:
- Every `comments[].body` MUST start with one of exactly four prefixes:
  `CRITICAL:` / `IMPORTANT:` / `SUGGESTION:` / `NIT:`. No other severity labels.
- `line`/`side`/`start_line`/`start_side` are derived ONLY from the PR diff's
  `[OLD:n]`, `[NEW:n]`, or `[OLD:n,NEW:m]` line annotations — never guessed or
  computed from unannotated context. If a finding can't be pinned to an
  annotated diff line, drop it from `comments` and fold it into `body.concerns`
  instead.
- Any suggested fix mentioned in a comment must first be checked against the
  repo's real build/lint/test tooling (not asserted from reading alone) before
  it's proposed.
- After writing `review.json`, validate it: `python3 .claude/scripts/pr/validate_review_json.py <path>`.
  Fix and re-validate on any reported error.
- **This skill NEVER runs `gh pr review`, `gh pr comment`, or `gh api .../reviews`.**
  Writing `review.json` is the entire task — a separate, write-permission-scoped
  step (never this skill) is responsible for posting it. This split is a
  deliberate prompt-injection blast-radius mitigation: the process that reads
  untrusted PR content never holds credentials that can post.
