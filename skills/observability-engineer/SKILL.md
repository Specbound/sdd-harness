---
name: observability-engineer
description: "Build production monitoring: metrics (Prometheus), distributed tracing (OpenTelemetry), structured logging, Grafana dashboards, and alert routing. Use when instrumenting services, designing a monitoring stack, or investigating alert noise/reliability regressions — not for SLO target-setting itself."
---

Observability engineering: metrics, distributed tracing, log aggregation, dashboards, and alerting for production systems.

## Use this skill when
- Designing or extending a monitoring/logging/tracing stack
- Instrumenting services with metrics or traces, or building Grafana dashboards
- Setting up alert rules and routing (Alertmanager, PagerDuty, Slack)
- Investigating alert noise, missing signal, or a production reliability regression

## Do not use this skill when
- You only need a single ad-hoc dashboard query
- You need SLI/SLO target-setting or error-budget policy — see `slo-implementation`
- You cannot access metrics, logs, or tracing data for the system in question

## The Three Pillars
Metrics (aggregate, cheap, best for alerting) · Logs (discrete events, detailed, expensive at scale) · Traces (per-request flow across services, best for latency root-cause). Correlate all three via shared labels (`service`, `trace_id`) — a dashboard spike should let you jump straight to the traces and logs for that window.

## Prometheus Setup
```yaml
global: { scrape_interval: 15s, evaluation_interval: 15s }
external_labels: { cluster: production, region: us-east-1 }
rule_files: ["alerts/*.yml", "recording_rules/*.yml"]
scrape_configs:
  - job_name: application
    kubernetes_sd_configs: [{role: pod}]
    relabel_configs:
      - { source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape], action: keep, regex: "true" }
```

## Metrics Instrumentation
- **Counter** — monotonic (e.g. `http_requests_total`)
- **Histogram** — bucketed (e.g. `http_request_duration_seconds`) — needed for `histogram_quantile` percentile queries
- **Gauge** — point-in-time value (e.g. queue depth, connection pool size)

```typescript
const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5],
});
// middleware: start = Date.now(); on res 'finish' -> observe((Date.now()-start)/1000, labels)
```
**Cardinality is the #1 cost/stability risk**: never label with raw user IDs, unbounded paths, or request IDs — bound every label's value set.

## Distributed Tracing (OpenTelemetry)
```typescript
new NodeSDK({
  resource: new Resource({ [SemanticResourceAttributes.SERVICE_NAME]: serviceName }),
  traceExporter: jaegerExporter,
  spanProcessor: new BatchSpanProcessor(jaegerExporter),
  instrumentations: [getNodeAutoInstrumentations()],
}).start();
```
Route through an OTel Collector rather than exporting straight to one backend — lets you swap Jaeger/Tempo/DataDog without re-instrumenting every service. Tune sampling (head or tail-based) once trace volume gets expensive; tail sampling can keep 100% of error/slow traces while dropping routine ones.

## Structured Logging
One JSON object per line: `@timestamp`, `level`, `service`, `version`, `message`, plus `trace_id`/`span_id` for cross-referencing with traces. Scrub secrets/PII at the logger call site, not downstream.

Pipeline: tail → parse (json) → enrich (k8s metadata, cluster/env) → ship. Loki is cheaper at scale (indexes labels only, greps content at query time) vs. ELK (full-text indexed, pricier but richer search).

## Dashboards (Golden Signals)
Every service dashboard needs: **Request Rate**, **Error Rate**, **Latency** (p50/p95/p99 via `histogram_quantile(0.95, sum(rate(..._bucket[5m])) by (le))`), **Saturation** (CPU/memory/queue depth). Build dashboards as code (Grafana JSON model, or Terraform `grafana_dashboard`) — hand-edits in the UI don't survive a rebuild.

## Alerting
Alert on symptoms (error rate, latency breach), not raw causes (CPU%) — causes belong in the linked runbook, not the page itself.
```yaml
- alert: HighErrorRate
  expr: sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (service)
        / sum(rate(http_requests_total[5m])) by (service) > 0.05
  for: 5m
  labels: { severity: critical }
  annotations: { summary: "High error rate on {{ $labels.service }}" }
```
Route by severity: `critical` → PagerDuty, `warning` → Slack. Group alerts by `alertname, cluster, service` (`group_wait`/`group_interval`/`repeat_interval`) to prevent storms from one incident paging N times.

## Infrastructure as Code
One Terraform module per stack component (`module "prometheus"`, `"grafana"`, `"alertmanager"`) parameterized by `storage_size`/`retention_days`/env; provision dashboards and alert rules via GitOps so they survive a cluster rebuild instead of living only in a UI.

## Cost & Noise Reduction
- Retention tiers (hot/warm/cold) and downsampling once volume outgrows a single Prometheus/log-store instance.
- Correlate signals before paging — don't fire three separate alerts (CPU, error rate, latency) for one incident; tune thresholds from observed false-positive rate, not guesswork.
- Every alert needs a runbook link; an alert nobody acts on should be deleted or demoted to a dashboard panel.

## Reference Files
- `resources/implementation-playbook.md` — full `prometheus.yml`, TS metrics/tracing/dashboard-as-code, Fluentd config, Python structured-logger, Alertmanager routing config, Terraform modules

## Related Skills
- `slo-implementation` — SLI/SLO target-setting, error-budget policy, burn-rate alerting
- `kubernetes-architect` — cluster-level monitoring integration
- `incident-responder` — on-call response once an alert fires
