---
name: deployment-pipeline-design
description: "Design and operate multi-stage CI/CD pipelines: approval gates, deployment strategies (rolling/blue-green/canary/feature-flags), rollback procedures, and platform-specific release decision-making. Use when architecting a deployment workflow, choosing a release strategy, or writing a runbook."
---

CI/CD pipeline architecture: stage design, approval gates, deployment strategies, rollback, and platform-specific release decisions.

## Use this skill when
- Designing CI/CD pipeline architecture or multi-environment promotion
- Choosing between rolling, blue-green, canary, or feature-flag deployment strategies
- Implementing approval gates, quality gates, or rollback automation
- Writing or reviewing a production deployment runbook

## Do not use this skill when
- The task is unrelated to deployment pipelines or release process
- You need CI/CD tool syntax reference only — see `github-actions-templates` / `gitlab-ci-patterns`
- You need Kubernetes manifest authoring — see `kubernetes-architect`

## Platform Selection

```
What are you deploying?
├── Static site / JAMstack    → Vercel, Netlify, Cloudflare Pages (git push, auto-deploy)
├── Simple web app, managed   → Railway, Render, Fly.io (git push or CLI)
├── Simple web app, control   → VPS + PM2/Docker (SSH + manual steps)
├── Microservices             → Container orchestration (kubectl apply)
└── Serverless                → Edge functions, Lambda
```
Each platform has a different deploy *and* rollback method — pick the pipeline design to match, don't force one shape onto all of them.

## Standard Pipeline Flow

```
Source → Build → Test → Staging Deploy → Integration Tests → Approval Gate → Production Deploy → Verify → (Rollback on failure)
```

### Pre-Deployment Checklist
- [ ] All tests passing, code reviewed
- [ ] Production build successful, no warnings
- [ ] Env vars / secrets verified for target environment
- [ ] DB migrations ready and backward-compatible
- [ ] Rollback plan documented, backup/previous-revision available
- [ ] Monitoring ready, team notified

### The 4 Verification Categories
| Category | What to Check |
|---|---|
| Code Quality | Tests passing, linting clean, reviewed |
| Build | Production build works, no warnings |
| Environment | Env vars set, secrets current |
| Safety | Backup done, rollback plan ready |

## Approval Gate Patterns

**Manual approval (GitHub Actions):**
```yaml
production-deploy:
  needs: staging-deploy
  environment: { name: production, url: https://app.example.com }
  runs-on: ubuntu-latest
  steps: [{ name: Deploy, run: ./deploy.sh }]
```

**Time-delayed (GitLab CI):**
```yaml
deploy:production:
  stage: deploy
  script: [deploy.sh production]
  when: delayed
  start_in: 30 minutes
  only: [main]
```

**Multi-approver (Azure Pipelines):** use a `ManualValidation@0` task in `preDeploy` with `notifyUsers` pointed at the approving group, plus `instructions` naming what to review (e.g. staging metrics) before approving.

## Deployment Strategies

| Strategy | Characteristics | Best for |
|---|---|---|
| **Rolling** | Gradual instance replacement, zero downtime, easy rollback | Most applications (default choice) |
| **Blue-Green** | Instant switchover, easy rollback, 2x infra cost temporarily | High-risk changes |
| **Canary** | Gradual traffic shift, real-user testing, needs mesh/LB support | Risk mitigation on uncertain changes |
| **Feature Flags** | Deploy without releasing, instant toggle, granular control | A/B testing, decoupling deploy from release |

```yaml
# Rolling (K8s)
strategy: { type: RollingUpdate, rollingUpdate: { maxSurge: 2, maxUnavailable: 1 } }

# Canary (Argo Rollouts)
strategy:
  canary:
    steps:
    - setWeight: 10
    - pause: {duration: 5m}
    - setWeight: 50
    - pause: {duration: 5m}
    - setWeight: 100
```
Blue-green via labels: deploy green alongside blue, test it, flip the Service selector label, keep blue standing by for instant rollback.

### Selection Principles
| Scenario | Strategy |
|---|---|
| Standard release | Rolling |
| High-risk change | Blue-green (easy rollback) |
| Need real-traffic validation | Canary |

## Multi-Stage Pipeline Example
```yaml
jobs:
  build:   { steps: [checkout, make build, docker build, docker push] }
  test:    { needs: build, steps: [make test, trivy image scan] }
  deploy-staging:      { needs: test, environment: staging, steps: [kubectl apply -f k8s/staging/] }
  integration-test:    { needs: deploy-staging, steps: [npm run test:e2e] }
  deploy-production:   { needs: integration-test, environment: production,
                          steps: [kubectl apply -f k8s/production/, kubectl argo rollouts promote my-app] }
  verify:  { needs: deploy-production, steps: [curl -f https://app.example.com/health, notify-slack] }
```

## Rollback

**Automated** — health-check loop after rollout, auto-undo on failure:
```yaml
- run: kubectl rollout status deployment/my-app
- id: health
  run: |
    for i in {1..10}; do curl -sf https://app.example.com/health && exit 0; sleep 10; done
    exit 1
- if: failure()
  run: kubectl rollout undo deployment/my-app
```

**Manual:** `kubectl rollout history deployment/my-app` → `kubectl rollout undo deployment/my-app [--to-revision=N]`

### When to Rollback
| Symptom | Action |
|---|---|
| Service down | Rollback immediately |
| Critical errors | Rollback |
| Performance >50% degraded | Consider rollback |
| Minor issues | Fix forward if quick |

**Rollback principles:** speed over perfection (rollback first, debug later) · one rollback, not multiple compounding changes · communicate to team · post-mortem once stable.

## Post-Deployment Verification
| Window | Action |
|---|---|
| First 5 min | Active monitoring |
| 15 min | Confirm stable |
| 1 hour | Final verification |
| Next day | Review metrics |

Check: health endpoint, error logs (no new errors), key user flows, response-time performance. Example automated gate:
```bash
ERROR_RATE=$(curl -s "$PROM_URL/api/v1/query?query=rate(http_errors_total[5m])" | jq '.data.result[0].value[1]')
(( $(echo "$ERROR_RATE > 0.01" | bc -l) )) && echo "Error rate too high" && exit 1
```

## Pipeline Metrics (DORA)
Deployment Frequency · Lead Time for Changes · Change Failure Rate · MTTR (Mean Time to Recovery) · Pipeline Success Rate · Average Pipeline Duration.

## Emergency Procedures
1. **Assess** the symptom → 2. **Quick fix** (restart) if unclear → 3. **Rollback** if restart doesn't help → 4. **Investigate** after stable.

Investigation order: logs (errors/exceptions) → resources (disk/memory) → network (DNS/firewall) → dependencies (DB/APIs).

## Security & Compliance in the Pipeline
- Supply chain: SLSA provenance, Sigstore image signing, SBOM generation.
- Scanning: SAST/dependency scanning pre-merge; container scanning (trivy/Checkov) pre-deploy; DAST against staging.
- Secrets: pull from a secret store (Vault, etc.) at deploy time — never bake into images or pipeline YAML.
- Pre-deploy config validation (schema checks, secret-pattern scanning in config files) is a legitimate gate on the Build/Test stage but is its own concern — see a config-validation skill for schema/encryption/migration implementation details.

## Anti-Patterns
| Don't | Do |
|---|---|
| Deploy on Friday | Deploy early in the week |
| Rush deployment | Follow the process |
| Skip staging | Always test first |
| Deploy without backup | Backup before deploy |
| Walk away after deploy | Monitor for 15+ min |
| Multiple changes at once | One change at a time |

## Pipeline Best Practices
Fail fast (quick tests first) · parallelize independent jobs · cache dependencies · manage build artifacts · keep environment parity · deployment windows · auto-rollback on failure · document every pipeline stage · small frequent deploys over big-bang releases.

## Related Skills
- `github-actions-templates`, `gitlab-ci-patterns` — tool-specific CI/CD implementation
- `secrets-management` — secret store integration
- `kubernetes-architect` — manifest and probe/health-check authoring
