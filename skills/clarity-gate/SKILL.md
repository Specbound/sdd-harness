---
name: clarity-gate
description: Pre-ingestion check that forces claims in a document to be marked as fact, estimate, or hypothesis before it enters a RAG knowledge base or is handed to another model. Use when asked to clarity-gate a document, check it for hallucination risk, review it for equivocation, or confirm another model can read it safely.
source: "https://github.com/frmoretto/clarity-gate"
upstream_version: "2.1.3"
risk: safe
---

# Clarity Gate

**The question this answers:** if another model reads this document, will it mistake an
assumption for a fact?

**What it does not answer:** whether the claims are true. This checks *form*, not truth. A
model can hallucinate a fact into a document and then pass the gate by attaching a source
marker to the false claim. Human verification is required before declaring a document
clean; the gate alone is not sufficient and must never be reported as if it were.

## When to use

- Before a document is ingested into a RAG index or vector store.
- Before handing documentation from one model session to another.
- After writing a spec, state doc, or methodology description that contains projections,
  estimates, or benchmark numbers.
- Before publishing claims that have not been validated.

## Detection vs enforcement

Hedge detectors (UnScientify, HedgeHunter / CoNLL-2010) answer "does this text contain
uncertainty markers?" This skill answers the opposite question: "should this claim carry an
uncertainty marker, and does it?" A document full of confident, unhedged, unsourced claims
scores perfectly on a detector and fails here.

## The 9 points

Work through all nine. Points 1-4 are the core; 5-7 catch data problems; 8-9 decide what
gets routed to a human.

**1. Hypothesis vs fact.** Every claim marked validated or hypothetical.
Fails: "Our architecture outperforms competitors." Passes: same claim plus "[benchmark data
in Table 3]". Fix by adding `PROJECTED:`, `HYPOTHESIS:`, `UNTESTED:`, `(estimated)`, `~`.

**2. Uncertainty markers on forward-looking statements.**
Fails: "Revenue will be $50M by Q4." Passes: "Revenue is **projected** to be $50M by Q4."
Fix with projected / estimated / expected / designed to / intended to.

**3. Assumption visibility.** Implicit conditions that change the reading must be written down.
Fails: "The system scales linearly." Passes: "...linearly [assuming <1000 concurrent users]."
Fix with bracketed conditions.

**4. Authoritative-looking unvalidated data.** Tables of precise percentages with checkmarks
read as measured even when nothing was measured. Red flag: specific numbers (89%, 95%, 100%)
with no source. Fix by tagging each number `(est.)` or `(guess)` and heading the table
`PROJECTED VALUES - NOT MEASURED`.

**5. Data consistency.** Conflicting numbers, dates, or facts across sections. Red flag:
"500 users" in one place, "750 users" in another. Reconcile, or state the discrepancy and why.

**6. Implicit causation.** Plausible but unproven cause claims. Red flag: "Shorter prompts
improve response quality." Reframe as an explicit, labelled hypothesis.

**7. Future state written as present.** Red flag: "The system processes 10,000 requests per
second" about a system not yet built. Rewrite as "is designed to process" or "TARGET:".

**8. Temporal coherence.** Three sub-checks: document date against today's date; internal
chronology (v1.1.0 must not predate v1.0.0); freshness of any "current" / "now" / "today"
claim. Fix by updating dates or adding "as of [date]".

**9. Externally verifiable claims.** Specific numbers a reader could fact-check get routed,
not guessed at. Typical cases: pricing ("~$0.005 per call" — API prices move), statistics,
rates and ratios, and competitor claims ("no competitor offers Y"). Four allowed responses:
attach a dated source, add an uncertainty marker, route to a human or an external search, or
generalise the claim ("low cost" rather than a figure).

## Routing

```
claim extracted --> is there a source of truth?
     yes --> Tier 1: automated consistency check --> pass / block
     no  --> Tier 2: two-round human review --> Round A --> Round B --> approve / reject
```

**Tier 1** covers internal consistency only: figure against text, abstract against body,
table against surrounding text, and numeric agreement. Any external check is a connector the
user supplies (finance system, commit history, CRM).

**Tier 2** is mandatory and has two distinct rounds, which are often collapsed by mistake:
- **Round A — derived data confirmation.** The source was found during the session; the
  human confirms your *interpretation* of it, not its truth.
- **Round B — true verification.** No source was found, or the claim rests on the human's
  own data or on an extrapolation. The human supplies the fact.

Collapsing B into A is the main failure mode: it produces a document labelled reviewed whose
unsourced claims were never actually checked by anyone.

## Claim IDs

Stable IDs let a claim be tracked across revisions. Algorithm: strip and collapse whitespace
in the claim text, join to its location with a pipe, SHA-256, take the first 8 hex
characters, prefix `claim-`.

```bash
printf '%s' "Base price is $99/mo|api-pricing/1" | shasum -a 256 | cut -c1-8
# 75fb137a  -> claim-75fb137a
```

Both upstream test vectors were reproduced with this one-liner on 2026-10-23:
`Base price is $99/mo|api-pricing/1` gives `75fb137a`, and
`The API supports GraphQL|features/1` gives `eb357742`. Upstream ships a `claim_id.py` for
this; that script is **not** installed with this skill, and the shell line above removes the
need for it.

## Output state fields

A gated document carries its verdict in frontmatter:

```yaml
clarity-gate-version: 2.1
processed-date: 2026-01-12
processed-by: Claude + Human Review
clarity-status: CLEAR        # or UNCLEAR while any point is unresolved
hitl-status: REVIEWED        # or PENDING
hitl-pending-count: 0
points-passed: 1-9
```

The two status fields are coupled: a document cannot be `REVIEWED` while `clarity-status` is
`UNCLEAR`, and `hitl-pending-count` must be 0 before `hitl-status: REVIEWED`. If claims exist,
the body needs a `## HITL Verification Record` section with one row per tracked claim.

Report findings in three severities: **critical** (will cause a downstream hallucination),
**warning** (could cause equivocation), **temporal** (date or freshness problem).

## Not included in this install

This skill directory contains `SKILL.md` only. The upstream project also ships the format
specification, the full validation-code tables (`E-ST10`, `W-HC01`, `E-TB01`-`E-TB07` and
others), `claim_id.py`, and `document_hash.py` with its canonicalization rules (frontmatter
hash-line removal, trailing-whitespace strip, newline collapse, UTF-8 NFC, CRLF and BOM
handling). Those codes are only meaningful against the spec file, so they are deliberately
not reproduced here. Fetch them from the upstream repository when a document has to validate
against the formal spec rather than just pass semantic review.
