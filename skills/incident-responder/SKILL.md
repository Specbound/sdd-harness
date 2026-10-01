---
name: incident-responder
description: "Lead production incident response: severity triage, incident command, observability-driven investigation, mitigation by symptom, rollback, and blameless postmortems. Use when an incident is active, building on-call runbooks, or running a postmortem."
---

Incident response: severity triage, incident command, investigation, mitigation by symptom, rollback, communication, and blameless postmortem.

## Use this skill when
- A production incident is active and needs triage, command structure, or mitigation
- Writing or reviewing a service-specific incident runbook
- Running a blameless postmortem or defining escalation policy

## Do not use this skill when
- Investigating a non-production bug with no active user impact — use a debugging skill instead
- You need SLI/SLO target definitions themselves — see `slo-implementation`
- You need observability tooling setup itself — see `observability-engineer`

## Severity Classification
| Severity | Impact | Ack SLA | Resolution SLA | Communication |
|---|---|---|---|---|
| P0 / SEV1 | Complete outage, data loss, security breach | < 15 min | < 1 hour | Every 15 min, exec notified |
| P1 / SEV2 | Major feature degraded, significant user impact | < 1 hour | < 4 hours | Hourly, status page |
| P2 / SEV3 | Minor functionality affected, limited impact | < 4 hours | < 24 hours | As needed, internal |
| P3 / SEV4 | Cosmetic, no user impact | Next business day | < 72 hours | Standard ticketing |

## First 5 Minutes
1. **Assess**: affected users/geography, business impact (revenue/SLA), blast radius, system scope.
2. **Set up command**: Incident Commander (single decision-maker) · Communications Lead (stakeholder updates) · Technical Lead (investigation) · open a dedicated war-room channel/call.
3. **Stabilize**: rollback assessment of recent deploys, feature-flag kill switches, circuit breakers, traffic throttling, scale resources. Post an initial status-page update.

## Investigation
**Observability-driven** (tooling setup lives in `observability-engineer`): distributed tracing for request-flow analysis, metrics correlation for pattern ID, log aggregation for error patterns, real-user monitoring for user-facing impact.

**SRE techniques**: error-budget burn-rate check (SLI/SLO violation — see `slo-implementation`) · change correlation against the deploy/config timeline · dependency/service-mesh mapping for upstream-downstream impact · cascading-failure analysis (circuit breaker states, retry storms, thundering herds).

**Root-cause pipeline**, run once the incident is mitigated: (1) capture the error signature and a minimal reproduction; (2) `git bisect run ./test_reproduction.sh` to find the introducing commit; (3) implement the minimal fix addressing the root cause, not the symptom, with a regression test covering the failure case; (4) verify with the full regression suite, a performance comparison against baseline, and a security scan before calling it done. Fix first, finish root-causing only after the service is stable.

## Mitigation by Symptom
| Symptom | Check | Typical fix |
|---|---|---|
| Service completely down | Pod status, recent deploy history, logs | `kubectl rollout undo deployment/<svc>`; scale up if resource-constrained |
| High latency | DB connection pool, slow queries (`pg_stat_activity`), dependency latency | Kill long-running queries; enable circuit breaker on the slow dependency |
| Partial failures (specific errors) | Error pattern frequency (`logs \| grep -i error \| sort \| uniq -c`), recent data changes | Feature flag to disable the broken path |
| Traffic surge | Request rate (`kubectl top pods`) | Scale horizontally; enable rate limiting; block abusive IPs if it's an attack |

```bash
# fast triage loop, applies to all four symptom rows above
kubectl get pods -n <ns> -l app=<svc>
kubectl logs -n <ns> -l app=<svc> --tail=100
kubectl rollout history deployment/<svc> -n <ns>
```

## Communication
Internal updates on the severity cadence above — technical detail for engineering, impact/ETA for execs. External: status-page updates, support-team briefing, proactive outreach to major affected customers, regulatory notification if compliance requires it.

**Escalation matrix** (adapt to your org): unresolved P0/SEV1 past SLA → engineering manager; suspected data breach → security team; material financial impact → finance/legal; customer-facing messaging needed → support lead.

Minimal update template: `Severity / Status / Impact / Actions taken / Next steps / ETA` — post that, don't improvise the wording under pressure.

## Resolution & Rollback
**Principles**: speed over perfection (rollback first, debug later) · one rollback, not stacked changes · communicate every action · validate before declaring resolved.

```bash
kubectl rollout undo deployment/<svc> -n <ns> [--to-revision=N]
```
Verify before announcing resolution: health endpoint green, error rate back to baseline, p99 latency acceptable, smoke test on critical user flows.

## Blameless Postmortem (within 48 hours)
- Detailed timeline with timestamps and the rationale behind each decision.
- Root cause via Five Whys / systems thinking — focus on contributing factors (process gaps, tooling, technical debt), never individuals.
- Action items with owners and deadlines; track completion, don't let them rot in a doc.
- Feed findings back into: new alerts or SLI adjustments, runbook updates, resilience hardening (circuit breakers, bulkheads, graceful degradation).

## Runbook Authoring
Structure: Overview & impact → Detection & alerts → Initial triage → Mitigation steps → Root-cause investigation → Resolution → Verification & rollback → Communication templates → Escalation matrix.

**Do**: keep runbooks updated after every incident · test them in game days · always include a rollback/escape hatch · write for "3 AM brain" (assume no context) · link dashboards directly from the doc.
**Don't**: skip verification steps · skip the postmortem · work a P0/SEV1 solo · bury the escalation path at the bottom.

## Related Skills
- `observability-engineer` — tracing/metrics/log tooling used during investigation
- `slo-implementation` — error-budget burn-rate checks and policy
- `deployment-pipeline-design` — rollback automation and deployment strategies
