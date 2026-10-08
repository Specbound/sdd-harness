---
name: devops-infra
description: Infrastructure & delivery: Terraform/IaC, Kubernetes, Docker, CI/CD, cloud (AWS/GCP/Vercel), GitOps, service mesh, cost. Use for infra design, pipelines, or deployment.
---

# devops-infra — domain router

This is a routing skill for the **devops-infra** domain. It holds no technique itself — it lists the sub-skills in this domain so you can load the right one(s).

**How to use:** scan the table, then READ the SKILL.md at each path that genuinely helps the task with the Read tool. **Load as many as the task needs — not just one.** A task that spans sub-skills (e.g. build + test, or debug + fix infra) should pull every relevant row. Skip the rest.


| sub-skill | what it covers | path |
|---|---|---|
| `aws-cost-cleanup` | Automated cleanup of unused AWS resources to reduce costs | `~/.claude/skill-library/aws-cost-cleanup/SKILL.md` |
| `aws-cost-optimizer` | Comprehensive AWS cost analysis and optimization recommendations using AWS CLI and Cost Explorer | `~/.claude/skill-library/aws-cost-optimizer/SKILL.md` |
| `azd-deployment` | Deploy containerized applications to Azure Container Apps using Azure Developer CLI (azd). Use when setting up azd projects, writing azure.yaml configuration, c | `~/.claude/skill-library/azd-deployment/SKILL.md` |
| `bazel-build-optimization` | Optimize Bazel builds for large-scale monorepos. Use when configuring Bazel, implementing remote execution, or optimizing build performance for enterprise codeb | `~/.claude/skill-library/bazel-build-optimization/SKILL.md` |
| `cloud-architect` | Expert cloud architect specializing in AWS/Azure/GCP multi-cloud | `~/.claude/skill-library/cloud-architect/SKILL.md` |
| `cloud-devops` | Cloud infrastructure and DevOps workflow covering AWS, Azure, GCP, Kubernetes, Terraform, CI/CD, monitoring, and cloud-native development. | `~/.claude/skill-library/cloud-devops/SKILL.md` |
| `cost-optimization` | Optimize cloud costs through resource rightsizing, tagging strategies, reserved instances, and spending analysis. Use when reducing cloud expenses, analyzing in | `~/.claude/skill-library/cost-optimization/SKILL.md` |
| `deployment-pipeline-design` | Design and operate multi-stage CI/CD pipelines: approval gates, deployment strategies (rolling/blue-green/canary/feature-flags), rollback procedures, and platfo | `~/.claude/skill-library/deployment-pipeline-design/SKILL.md` |
| `docker-expert` | Docker containerization expert with deep knowledge of multi-stage builds, image optimization, container security, Docker Compose orchestration, and production d | `~/.claude/skill-library/docker-expert/SKILL.md` |
| `environment-setup-guide` | Guide developers through setting up development environments with proper tools, dependencies, and configurations | `~/.claude/skill-library/environment-setup-guide/SKILL.md` |
| `expo-deployment` | Deploy Expo apps to production | `~/.claude/skill-library/expo-deployment/SKILL.md` |
| `github-actions-templates` | Create production-ready GitHub Actions workflows for automated testing, building, and deploying applications. Use when setting up CI/CD with GitHub Actions, aut | `~/.claude/skill-library/github-actions-templates/SKILL.md` |
| `gitlab-ci-patterns` | Build GitLab CI/CD pipelines with multi-stage workflows, caching, and distributed runners for scalable automation. Use when implementing GitLab CI/CD, optimizin | `~/.claude/skill-library/gitlab-ci-patterns/SKILL.md` |
| `gitops-workflow` | Implement GitOps workflows with ArgoCD and Flux for automated, declarative Kubernetes deployments with continuous reconciliation. Use when implementing GitOps p | `~/.claude/skill-library/gitops-workflow/SKILL.md` |
| `helm-chart-scaffolding` | Design, organize, and manage Helm charts for templating and packaging Kubernetes applications with reusable configurations. Use when creating Helm charts, packa | `~/.claude/skill-library/helm-chart-scaffolding/SKILL.md` |
| `hybrid-cloud-architect` | Expert hybrid cloud architect specializing in complex multi-cloud | `~/.claude/skill-library/hybrid-cloud-architect/SKILL.md` |
| `hybrid-cloud-networking` | Configure secure, high-performance connectivity between on-premises infrastructure and cloud platforms using VPN and dedicated connections. Use when building hy | `~/.claude/skill-library/hybrid-cloud-networking/SKILL.md` |
| `istio-traffic-management` | Configure Istio traffic management including routing, load balancing, circuit breakers, and canary deployments. Use when implementing service mesh traffic polic | `~/.claude/skill-library/istio-traffic-management/SKILL.md` |
| `kubernetes-architect` | Kubernetes platform design (multi-cluster, GitOps, service mesh, multi-tenancy) and production-ready manifest authoring (Deployments, Services, ConfigMaps, Secr | `~/.claude/skill-library/kubernetes-architect/SKILL.md` |
| `linkerd-patterns` | Implement Linkerd service mesh patterns for lightweight, security-focused service mesh deployments. Use when setting up Linkerd, configuring traffic policies, o | `~/.claude/skill-library/linkerd-patterns/SKILL.md` |
| `monorepo-architect` | Expert in monorepo architecture, build systems, and dependency management at scale. Masters Nx, Turborepo, Bazel, and Lerna for efficient multi-project developm | `~/.claude/skill-library/monorepo-architect/SKILL.md` |
| `monorepo-management` | Master monorepo management with Turborepo, Nx, and pnpm workspaces to build efficient, scalable multi-package repositories with optimized builds and dependency  | `~/.claude/skill-library/monorepo-management/SKILL.md` |
| `mtls-configuration` | Configure mutual TLS (mTLS) for zero-trust service-to-service communication. Use when implementing zero-trust networking, certificate management, or securing in | `~/.claude/skill-library/mtls-configuration/SKILL.md` |
| `multi-cloud-architecture` | Design multi-cloud architectures using a decision framework to select and integrate services across AWS, Azure, and GCP. Use when building multi-cloud systems,  | `~/.claude/skill-library/multi-cloud-architecture/SKILL.md` |
| `network-engineer` | Expert network engineer specializing in modern cloud networking, | `~/.claude/skill-library/network-engineer/SKILL.md` |
| `nx-workspace-patterns` | Configure and optimize Nx monorepo workspaces. Use when setting up Nx, configuring project boundaries, optimizing build caching, or implementing affected comman | `~/.claude/skill-library/nx-workspace-patterns/SKILL.md` |
| `server-management` | Server management principles and decision-making. Process management, monitoring strategy, and scaling decisions. Teaches thinking, not commands. | `~/.claude/skill-library/server-management/SKILL.md` |
| `service-mesh-expert` | Expert service mesh architect specializing in Istio, Linkerd, and cloud-native networking patterns. Masters traffic management, security policies, observability | `~/.claude/skill-library/service-mesh-expert/SKILL.md` |
| `terraform-specialist` | Terraform/OpenTofu patterns for module design, state management, multi-environment deployments, testing (native tests, Terratest), CI/CD, and security scanning. | `~/.claude/skill-library/terraform-specialist/SKILL.md` |
| `turborepo-caching` | Configure Turborepo for efficient monorepo builds with local and remote caching. Use when setting up Turborepo, optimizing build pipelines, or implementing dist | `~/.claude/skill-library/turborepo-caching/SKILL.md` |
| `vercel-deploy-claimable` | Deploy applications and websites to Vercel. Use this skill when the user requests deployment actions such as 'Deploy my app', 'Deploy this to production', 'Crea | `~/.claude/skill-library/vercel-deploy-claimable/SKILL.md` |
| `vercel-deployment` | Expert knowledge for deploying to Vercel with Next.js Use when: vercel, deploy, deployment, hosting, production. | `~/.claude/skill-library/vercel-deployment/SKILL.md` |

_32 sub-skills. If none fit, the task likely belongs to another domain router._
