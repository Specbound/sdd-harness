---
name: slo-implementation
description: "Define SLIs/SLOs with error budgets, Prometheus burn-rate alerting, and SLO dashboards. Use when setting reliability targets, implementing SRE error-budget policy, or building SLO-based (not raw-metric) alerts."
---

Framework for defining SLIs, SLOs, and error budgets, with concrete Prometheus/Grafana implementation.

## Use this skill when
- Defining service reliability targets and measuring user-perceived reliability
- Implementing error budgets and burn-rate alerting
- Building SLO dashboards or SLO-based (not raw-metric) alerts
- Running SLO review cadences or setting error-budget policy

## Do not use this skill when
- You only need raw metrics/dashboards with no reliability target — see `observability-engineer`
- The task is unrelated to service reliability targets

## SLI/SLO/SLA Hierarchy
```
SLA (contract w/ customers, often has financial penalty)
  ↓
SLO (internal reliability target, stricter than SLA)
  ↓
SLI (actual measurement)
```

## Service Tiers (sets default SLO targets)
| Tier | Availability | Latency p99 | Error rate | Examples |
|---|---|---|---|---|
| Critical | 99.95% | 100ms | 0.001 | payments, auth |
| Essential | 99.9% | 500ms | 0.01 | search, catalog |
| Standard | 99.5% | 1000ms | 0.05 | recommendations, analytics |
| Best-effort | 99.0% | 2000ms | 0.1 | batch, reporting |

## Defining SLIs
**Availability:**
```promql
sum(rate(http_requests_total{status!~"5.."}[28d])) / sum(rate(http_requests_total[28d]))
```
**Latency (requests under threshold):**
```promql
sum(rate(http_request_duration_seconds_bucket{le="0.5"}[28d])) / sum(rate(http_request_duration_seconds_count[28d]))
```
**Durability:** `storage_writes_successful_total / storage_writes_total`

Pick SLIs from the critical user journey, not whatever's easiest to measure — e.g. a "login" SLI should cover page load + credential POST + dashboard render as separate thresholds, not one blended number.

## Setting SLO Targets
| SLO % | Downtime/Month | Downtime/Year |
|---|---|---|
| 99% | 7.2 hours | 3.65 days |
| 99.9% | 43.2 min | 8.76 hours |
| 99.95% | 21.6 min | 4.38 hours |
| 99.99% | 4.32 min | 52.56 min |

Never target 100% — cost rises non-linearly as target approaches it, and it eliminates all room for planned risk (deploys, experiments).

```yaml
slos:
  - name: api_availability
    target: 99.9
    window: 28d
    sli: sum(rate(http_requests_total{status!~"5.."}[28d])) / sum(rate(http_requests_total[28d]))
```

## Error Budget
```
Error Budget = 1 - SLO Target
```
99.9% SLO → 0.1% budget = 43.2 min/month. Track remaining budget, not just current compliance.

**Error budget policy** (ties budget consumption to release velocity):
```yaml
error_budget_policy:
  - remaining_budget: 100%
    action: Normal development velocity
  - remaining_budget: 50%
    action: Consider postponing risky changes
  - remaining_budget: 10%
    action: Freeze non-critical changes
  - remaining_budget: 0%
    action: Feature freeze, focus on reliability
```

## Prometheus Recording Rules
```yaml
groups:
  - name: sli_rules
    interval: 30s
    rules:
      - record: sli:http_availability:ratio
        expr: sum(rate(http_requests_total{status!~"5.."}[28d])) / sum(rate(http_requests_total[28d]))
  - name: slo_rules
    interval: 5m
    rules:
      - record: slo:http_availability:compliance
        expr: sli:http_availability:ratio >= bool 0.999
      - record: slo:http_availability:error_budget_remaining
        expr: (sli:http_availability:ratio - 0.999) / (1 - 0.999) * 100
      - record: slo:http_availability:burn_rate_5m
        expr: |
          (1 - (sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))))
          / (1 - 0.999)
```
Precompute burn rate at each window you alert on (5m/1h/30m/6h) as separate recording rules — the alert rules below reference them directly instead of recomputing.

## Multi-Window Burn-Rate Alerting
A single-window burn-rate alert false-positives on brief blips. Require a short *and* a long window to agree:
```yaml
groups:
  - name: slo_alerts
    interval: 1m
    rules:
      # Fast burn: 14.4x rate -> consumes 2% of 28d budget in 1h
      - alert: SLOErrorBudgetBurnFast
        expr: slo:http_availability:burn_rate_1h > 14.4 and slo:http_availability:burn_rate_5m > 14.4
        for: 2m
        labels: { severity: critical }

      # Slow burn: 6x rate -> consumes 5% of budget in 6h
      - alert: SLOErrorBudgetBurnSlow
        expr: slo:http_availability:burn_rate_6h > 6 and slo:http_availability:burn_rate_30m > 6
        for: 15m
        labels: { severity: warning }

      - alert: SLOErrorBudgetExhausted
        expr: slo:http_availability:error_budget_remaining < 0
        for: 5m
        labels: { severity: critical }
```
Fast burn → page immediately. Slow burn → ticket, not page. The 14.4x/1h and 6x/6h thresholds come from Google's SRE workbook multi-window technique.

## SLO Dashboard
```
┌──────────────────────────────────────┐
│ SLO Compliance: 99.95% (Target 99.9%) │
│ Error Budget Remaining: 65% ████████░░ │
│ SLI Trend (28d)       [time series]   │
│ Burn Rate by Window   [burn rate]     │
└──────────────────────────────────────┘
```
```promql
# Days until budget exhausted at current burn rate
(slo:http_availability:error_budget_remaining / 100) * 28 / (1 - sli:http_availability:ratio) * (1 - 0.999)
```

## SLO Review Cadence
- **Weekly** — compliance, error-budget status, trend
- **Monthly** — SLO achievement, incident impact on budget
- **Quarterly** — target relevance, process/tooling adjustments

## Best Practices
Start with user-facing services first · use multiple SLIs per service (availability + latency, not just one) · set achievable targets (never 100%) · multi-window alerts to cut noise · document every SLO decision (target, owner, review date) · use burned budget for release-cadence prioritization, not just a dashboard number.

## Related Skills
- `observability-engineer` — metric collection, dashboarding, and alert-routing infrastructure this builds on
- `prometheus-configuration`, `grafana-dashboards` — tool-specific implementation
- `incident-responder` — error-budget-exhaustion response
