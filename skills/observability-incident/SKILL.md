---
name: observability-incident
description: Production reliability: metrics/tracing/logging, Prometheus/Grafana/OTel, SLOs, incident response, postmortems, performance profiling. Use when instrumenting, alerting, or handling incidents.
---

# observability-incident — domain router

This is a routing skill for the **observability-incident** domain. It holds no technique itself — it lists the sub-skills in this domain so you can load the right one(s).

**How to use:** scan the table, then READ the SKILL.md at each path that genuinely helps the task with the Read tool. **Load as many as the task needs — not just one.** A task that spans sub-skills (e.g. build + test, or debug + fix infra) should pull every relevant row. Skip the rest.


| sub-skill | what it covers | path |
|---|---|---|
| `active-observability` | Surface unknown patterns in agent trace collections via facet-based analysis — batch-LLM-summarize traces, cluster summaries, report topic groups. Use when you  | `~/.claude/skill-library/active-observability/SKILL.md` |
| `api-testing-observability-api-mock` | You are an API mocking expert specializing in realistic mock services for development, testing, and demos. Design mocks that simulate real API behavior and enab | `~/.claude/skill-library/api-testing-observability-api-mock/SKILL.md` |
| `application-performance-performance-optimization` | Optimize end-to-end application performance with profiling, observability, and backend/frontend tuning. Use when coordinating performance optimization across th | `~/.claude/skill-library/application-performance-performance-optimization/SKILL.md` |
| `distributed-tracing` | Implement distributed tracing with Jaeger and Tempo to track requests across microservices and identify performance bottlenecks. Use when debugging microservice | `~/.claude/skill-library/distributed-tracing/SKILL.md` |
| `frontend-slides` | Create stunning, animation-rich HTML presentations from scratch or by converting PowerPoint files. Use when the user wants to build a presentation, convert a PP | `~/.claude/skill-library/frontend-slides/SKILL.md` |
| `grafana-dashboards` | Create and manage production Grafana dashboards for real-time visualization of system and application metrics. Use when building monitoring dashboards, visualiz | `~/.claude/skill-library/grafana-dashboards/SKILL.md` |
| `incident-responder` | Lead production incident response: severity triage, incident command, observability-driven investigation, mitigation by symptom, rollback, and blameless postmor | `~/.claude/skill-library/incident-responder/SKILL.md` |
| `observability-engineer` | Build production monitoring: metrics (Prometheus), distributed tracing (OpenTelemetry), structured logging, Grafana dashboards, and alert routing. Use when inst | `~/.claude/skill-library/observability-engineer/SKILL.md` |
| `observe-whatsapp` | Observe and troubleshoot WhatsApp in Kapso: debug message delivery, inspect webhook deliveries/retries, triage API errors, and run health checks. Use when inves | `~/.claude/skill-library/observe-whatsapp/SKILL.md` |
| `on-call-handoff-patterns` | Master on-call shift handoffs with context transfer, escalation procedures, and documentation. Use when transitioning on-call responsibilities, documenting shif | `~/.claude/skill-library/on-call-handoff-patterns/SKILL.md` |
| `performance-engineer` | Expert performance engineer specializing in modern observability, | `~/.claude/skill-library/performance-engineer/SKILL.md` |
| `performance-profiling` | Performance profiling principles. Measurement, analysis, and optimization techniques. | `~/.claude/skill-library/performance-profiling/SKILL.md` |
| `postmortem-writing` | Write effective blameless postmortems with root cause analysis, timelines, and action items. Use when conducting incident reviews, writing postmortem documents, | `~/.claude/skill-library/postmortem-writing/SKILL.md` |
| `prometheus-configuration` | Set up Prometheus for comprehensive metric collection, storage, and monitoring of infrastructure and applications. Use when implementing metrics collection, set | `~/.claude/skill-library/prometheus-configuration/SKILL.md` |
| `service-mesh-observability` | Implement comprehensive observability for service meshes including distributed tracing, metrics, and visualization. Use when setting up mesh monitoring, debuggi | `~/.claude/skill-library/service-mesh-observability/SKILL.md` |
| `slo-implementation` | Define SLIs/SLOs with error budgets, Prometheus burn-rate alerting, and SLO dashboards. Use when setting reliability targets, implementing SRE error-budget poli | `~/.claude/skill-library/slo-implementation/SKILL.md` |
| `web-performance-optimization` | Optimize website and web application performance including loading speed, Core Web Vitals, bundle size, caching strategies, and runtime performance | `~/.claude/skill-library/web-performance-optimization/SKILL.md` |

_17 sub-skills. If none fit, the task likely belongs to another domain router._
