---
name: security-bluebook-builder
description: Use when a sensitive application (handles auth, payment, PII, or admin access) needs a single reference document covering its assets, threats, controls, and incident response — build a "Blue Book" rather than scattering this across separate docs.
source: "https://github.com/SHADOWPR0/security-bluebook-builder"
risk: unknown
---

# Security Bluebook Builder

> This skill's structure is inferred from the source name and description, not fetched from
> the upstream repository — the specific section names below are a reasonable security-review
> shape, not a verified match to the original tool's exact format. Correct this note if the
> upstream format differs once it's checked.

## When to Use

- Onboarding a new sensitive service and there's no existing security reference doc for it
- Before a security review or audit, to assemble what's currently scattered across tickets/Slack into one document
- Skip this for low-sensitivity internal tools with no auth, payment, or PII surface — the ceremony isn't worth it

## Workflow — 7-section Blue Book

1. **Asset inventory** — what this app touches: data classes (PII, payment, credentials), which are in scope, storage locations, retention.
2. **Threat model** — apply STRIDE per asset/data-flow:

   | Threat | Example for this asset | Mitigated by |
   |---|---|---|
   | Spoofing | Forged auth token | (control from section 3) |
   | Tampering | Modified request payload | |
   | Repudiation | No audit log for a sensitive action | |
   | Information disclosure | PII in logs or error messages | |
   | Denial of service | Unbounded query cost | |
   | Elevation of privilege | Missing authz check on an admin route | |

3. **Controls inventory** — for each threat row above, the actual control in place (auth mechanism, rate limiting, log redaction, etc.) with a pointer to where it's implemented, not just a description.
4. **Gaps** — threats with no control, or a control that's aspirational (documented but not implemented/tested). This is the section a reviewer reads first.
5. **Incident runbook** — for this specific app: who to page, what to check first, how to revoke access/rotate credentials, where the logs live.
6. **Deploy gate** — the minimum bar before this app can ship a change: which of the above must be re-checked (e.g. "any new admin route requires an authz-check entry in section 3").
7. **Review cadence** — when this document gets re-validated (a fixed schedule, or tied to a trigger like "new data class added").

## Anti-patterns

- Writing the threat model from a generic STRIDE template without naming this app's actual data flows — a Blue Book that could describe any app gives reviewers nothing to check against.
- Treating "documented" as "mitigated" in the controls inventory — flag aspirational controls in the Gaps section instead of listing them as done.
