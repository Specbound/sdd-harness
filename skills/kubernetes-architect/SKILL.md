---
name: kubernetes-architect
description: "Kubernetes platform design (multi-cluster, GitOps, service mesh, multi-tenancy) and production-ready manifest authoring (Deployments, Services, ConfigMaps, Secrets, probes, security contexts). Use for K8s architecture decisions, GitOps pipelines, or generating/reviewing K8s YAML."
---

Kubernetes architect covering platform design (GitOps, service mesh, multi-tenancy, cost) and concrete manifest authoring.

## Use this skill when
- Designing Kubernetes platform architecture or multi-cluster/GitOps strategy
- Generating or reviewing Deployment/Service/ConfigMap/Secret/PVC manifests
- Planning service mesh, security (Pod Security Standards, network policies), or multi-tenancy
- Improving reliability, cost, or developer experience in K8s

## Do not use this skill when
- You only need a local dev cluster or single-node setup
- Troubleshooting application code with no platform/manifest changes
- Not using Kubernetes or container orchestration

## Platform Choices
- **Managed**: EKS, AKS, GKE — prefer unless air-gapped or regulatory constraints demand self-managed.
- **Self-managed**: kubeadm, kops, kubespray, bare-metal/air-gapped.
- **Enterprise**: OpenShift, Rancher, Tanzu — platform-specific policy/UX layered on vanilla K8s.
- **Multi-cluster**: Cluster API, fleet management, cross-cluster networking for federation/DR.

## GitOps

**OpenGitOps principles (CNCF):** declarative desired state, versioned & immutable in Git, pulled automatically by agents (not pushed by CI), continuously reconciled against actual state.

- Tools: ArgoCD, Flux v2 — choose one, don't mix for the same resources.
- Repo pattern: app-of-apps for fleet-wide rollout; mono-repo for small teams, multi-repo once team/env boundaries need separate access control.
- Progressive delivery: Argo Rollouts or Flagger for canary/blue-green/A-B; wire to service mesh traffic splitting, not just replica scaling.
- Secrets in Git: never plaintext — External Secrets Operator, Sealed Secrets, or Vault injection.

## Service Mesh

| Mesh | Strengths |
|---|---|
| Istio | Full traffic mgmt, security policy, multi-cluster mesh — highest complexity |
| Linkerd | Lightweight, automatic mTLS, low operational overhead |
| Cilium | eBPF networking + policy + load balancing, good at scale |
| Consul Connect | HashiCorp ecosystem integration |
| Gateway API | Next-gen ingress, protocol-aware routing (not a mesh itself) |

## Security
- **Pod Security Standards**: `restricted` for workloads, `baseline` minimum, migrate off `privileged`.
- **Supply chain**: SLSA provenance, Sigstore image signing, SBOM generation, admission-time verification.
- **Runtime**: Falco/Sysdig for threat detection; network policies for micro-segmentation; compliance via CIS benchmarks.
- **Policy as code**: OPA/Gatekeeper or Kyverno — enforce in CI (plan-time) and admission (apply-time), not just one.

## Deployment Manifest Essentials

Required: `apiVersion: apps/v1`, `kind: Deployment`, `metadata.name`. Use `replicas: 3+` for HA; `revisionHistoryLimit` controls rollback depth (0 disables rollback).

**Update strategy** — zero-downtime vs fast:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }   # zero-downtime
  # rollingUpdate: { maxSurge: 2, maxUnavailable: 1 } # faster, brief downtime possible
```

**Probes** — all three, distinct purposes:
```yaml
startupProbe:   { httpGet: {path: /health/startup, port: http}, periodSeconds: 10, failureThreshold: 30 }
livenessProbe:  { httpGet: {path: /health/live,    port: http}, periodSeconds: 10, failureThreshold: 3 }
readinessProbe: { httpGet: {path: /health/ready,   port: http}, periodSeconds: 5,  failureThreshold: 3 }
```
`startupProbe` gates the other two for slow-starting apps. `livenessProbe` restarts; `readinessProbe` controls Service endpoint membership.

**Resources & QoS**: setting `requests` + `limits` on every container → `Guaranteed` QoS (highest eviction priority). Only `requests` → `Burstable`. Neither → `BestEffort` (evicted first). Memory limits ~1.5-2x requests; CPU limits looser for bursty workloads.

**Security context** (pod + container level):
```yaml
spec:
  securityContext: { runAsNonRoot: true, runAsUser: 1000, fsGroup: 1000, seccompProfile: {type: RuntimeDefault} }
  containers:
  - securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities: { drop: [ALL] }
```

**Labels** (`app.kubernetes.io/{name,instance,version,component,part-of,managed-by}`) + anti-affinity/topology spread across zones for HA:
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm: {labelSelector: {matchLabels: {app: my-app}}, topologyKey: kubernetes.io/hostname}
```

Graceful shutdown: `terminationGracePeriodSeconds` + `preStop` lifecycle hook sized longer than the time it takes the Service to deregister the pod.

## Service Types

| Type | Use case |
|---|---|
| `ClusterIP` (default) | Internal-only: microservice-to-microservice, DBs |
| `NodePort` | Static port 30000-32767 on every node — rarely the right final answer |
| `LoadBalancer` | External access via cloud LB (annotate for NLB/internal-facing as needed) |

## ConfigMap / Secret
- ConfigMap: non-sensitive config only, one per component, version on change.
- Secret: `stringData` for plaintext-in-YAML convenience; never commit to Git un-sealed — use Sealed Secrets/External Secrets/Vault; set RBAC to limit `get`/`list` on secrets.

## Production Checklist
- [ ] Resource requests + limits set
- [ ] All three probe types configured
- [ ] Specific image tags (never `:latest`)
- [ ] Security context: non-root, read-only rootfs, capabilities dropped
- [ ] Replica count ≥ 3, pod anti-affinity / topology spread
- [ ] `maxUnavailable: 0` if zero-downtime required
- [ ] ConfigMaps/Secrets for all config, none hardcoded
- [ ] Standard `app.kubernetes.io/*` labels
- [ ] Graceful shutdown (`preStop` + `terminationGracePeriodSeconds`)
- [ ] `revisionHistoryLimit` set for rollback
- [ ] Dedicated ServiceAccount, minimal RBAC

## Validation
```bash
kubectl apply -f manifest.yaml --dry-run=client
kubectl apply -f manifest.yaml --dry-run=server
kubeval manifest.yaml
kube-score score manifest.yaml
kube-linter lint manifest.yaml
```

## Troubleshooting
- Pod not starting: `kubectl describe pod <pod>`, `kubectl get events --sort-by='.lastTimestamp'`.
- `ImagePullBackOff`: check image/tag, `imagePullSecrets`, registry credentials.
- `CrashLoopBackOff`: check logs, verify liveness probe isn't too aggressive, check resource limits.
- Service unreachable: `kubectl get endpoints <svc>` (empty = selector/label mismatch).

## Deployment Pipeline (phase checklist)
Container (`docker-expert`) → Manifests (this skill / `k8s-security-policies`) → Helm (`helm-chart-scaffolding`) → Service mesh (`istio-traffic-management`, `linkerd-patterns`) → Security (RBAC, NetworkPolicy, mTLS) → Observability (`prometheus-configuration`, `grafana-dashboards`) → GitOps deploy (`gitops-workflow`) + verify rollout.

## Scalability & Cost
- Autoscaling: HPA/VPA for resource-based scaling, KEDA for event-driven custom metrics.
- Cost: KubeCost/OpenCost for allocation visibility; right-size via request/limit audits before adding nodes; spot/reserved capacity for stateless workloads.

## Disaster Recovery
- Velero (or cloud-native equivalent) for backup/restore, cross-region replication.
- Define RTO/RPO targets before choosing active-active vs active-passive; test failover, don't just configure it.

## Reference Files
- `references/deployment-spec.md` — full Deployment field reference (probes, security context, scheduling, volumes, HA/sidecar/init-container patterns)
- `references/service-spec.md` — Service types, networking, service-discovery patterns in depth
- `assets/deployment-template.yaml`, `assets/service-template.yaml`, `assets/configmap-template.yaml` — copy-paste starting manifests
