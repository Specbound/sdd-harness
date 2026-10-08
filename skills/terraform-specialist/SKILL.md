---
name: terraform-specialist
description: "Terraform/OpenTofu patterns for module design, state management, multi-environment deployments, testing (native tests, Terratest), CI/CD, and security scanning. Use when writing, structuring, reviewing, or testing Terraform/OpenTofu code, modules, or IaC pipelines."
---

Terraform/OpenTofu specialist for module design, state management, multi-cloud module libraries, testing strategy, and CI/CD automation.

## Use this skill when
- Creating or reviewing Terraform/OpenTofu configurations or reusable modules
- Choosing a testing approach (validate/plan, native tests, Terratest, policy as code)
- Structuring multi-environment deployments or multi-cloud module libraries
- Setting up state backends, locking, or recovering from state corruption
- Implementing CI/CD for infrastructure-as-code with security scanning

## Do not use this skill for
- A one-off manual infrastructure change with no stored/remote state
- Basic Terraform/OpenTofu syntax questions or provider-specific API reference
- A different IaC tool (Pulumi, CDK, Bicep) with no Terraform involvement

## Module & Directory Structure

**Hierarchy:** Resource → Resource Module → Infrastructure Module → Composition

| Type | When to Use | Scope |
|------|-------------|-------|
| **Resource Module** | Single logical group of connected resources | VPC + subnets, SG + rules |
| **Infrastructure Module** | Collection of resource modules for a purpose | Multiple resource modules in one region/account |
| **Composition** | Complete infrastructure | Spans multiple regions/accounts |

```
environments/        # Environment-specific configs: prod/, staging/, dev/
modules/              # Reusable modules: networking/, compute/, data/
examples/             # Module usage examples (also serve as integration tests): complete/, minimal/
```

For a **multi-cloud module library**, group by provider instead:
```
terraform-modules/
├── aws/{vpc,eks,rds,s3}/
├── azure/{vnet,aks,storage}/
└── gcp/{vpc,gke,cloud-sql}/
```

Standard module layout: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`, `examples/{minimal,complete}/`, `tests/*.tftest.hcl` (or `_test.go` for Terratest).

- Separate **environments** (prod, staging) from **modules** (reusable components)
- Use `examples/` as both documentation and integration test fixtures
- Keep modules small and focused (single responsibility)

## Naming Conventions

**Resources** — descriptive and contextual; use `"this"` only for singleton resources (module creates exactly one of that type):
```hcl
resource "aws_vpc" "this" {}             # ✅ module creates one VPC
resource "aws_subnet" "this" {}          # ❌ if creating multiple subnets — use descriptive names
```

**Variables** — prefix with context: `var.vpc_cidr_block` not `var.cidr`; `var.database_instance_class` not `var.instance_class`.

**Files:** `main.tf` (resources), `variables.tf`, `outputs.tf`, `versions.tf`, `data.tf` (optional).

## Testing Strategy

### Decision Matrix

| Situation | Approach | Tools | Cost |
|---|---|---|---|
| Quick syntax check | Static analysis | `terraform validate`, `fmt` | Free |
| Pre-commit validation | Static + lint | `validate`, `tflint`, `trivy`, `checkov` | Free |
| TF 1.6+, simple logic | Native test framework | built-in `terraform test` | Free-Low |
| Pre-1.6, or Go expertise | Integration testing | Terratest | Low-Med |
| Security/compliance focus | Policy as code | OPA, Sentinel | Free |
| Cost-sensitive workflow | Mock providers (1.7+) | native tests + mocking | Free |
| Multi-cloud, complex | Full integration | Terratest + real infra | Med-High |

Testing pyramid: static analysis (cheap, base) → integration tests in isolation (moderate) → end-to-end full-environment tests (expensive, top). Favor the base.

### Native Test Framework (1.6+) gotchas
- `command = plan` — fast, for input validation. `command = apply` — required for computed values and **set-type** blocks.
- Set-type blocks (S3 encryption rules, lifecycle transitions, IAM policy statements) cannot be indexed with `[0]` — use `for` expressions or `command = apply` to materialize.
- Before generating test code, validate the provider schema (search provider docs → get resource schema → identify block types).

### Terratest example
```go
func TestVPCModule(t *testing.T) {
    opts := &terraform.Options{TerraformDir: "../examples/complete"}
    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)
    assert.NotEmpty(t, terraform.Output(t, opts, "vpc_id"))
}
```

## Code Structure Standards

**Resource block ordering:** `count`/`for_each` first (blank line after) → other arguments → `tags` last real argument → `depends_on` → `lifecycle` at the very end.

**Variable block ordering:** `description` (always) → `type` → `default` → `validation` → `nullable`.

```hcl
variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
  nullable = false
}
```

## Count vs for_each

| Scenario | Use | Why |
|---|---|---|
| Boolean create/don't | `count = cond ? 1 : 0` | Simple on/off |
| Fixed numeric replication | `count = 3` | Identical resources |
| Items may be reordered/removed | `for_each = toset(list)` | Stable resource addresses |
| Reference by key | `for_each = map` | Named access |

`count` with list indexing recreates every subsequent resource when a middle item is removed; `for_each` only touches the removed item. Prefer `for_each` whenever addressing stability matters.

## Locals for Deletion Order

Use `try()` in locals to force correct dependency/deletion order when a resource depends on an optional association:
```hcl
locals {
  vpc_id = try(aws_vpc_ipv4_cidr_block_association.this[0].vpc_id, aws_vpc.this.id, "")
}
# downstream resources reference local.vpc_id, not aws_vpc.this.id directly,
# so Terraform deletes subnets before the CIDR association.
```

## State Management & Backends
- **Backends**: S3, Azure Storage, GCS, Terraform Cloud, Consul, etcd — pick one with native locking (DynamoDB for S3, native for Azure/GCS) and encryption at rest + in transit.
- **Operations**: `import`, `moved` blocks (1.1+, refactor without destroy/recreate), `state rm`, `state mv`, `refresh`.
- **Security**: never store secrets in plain variables; use Secrets Manager/Parameter Store/Vault; mark sensitive outputs `sensitive = true`; prefer write-only arguments (1.11+) so secrets never land in state.
- **Recovery**: keep automated state backups with point-in-time/versioned storage before any destructive `state` operation.

## Variables & Outputs
- Variables: always `description`, explicit `type`, sensible `default` where appropriate, `validation` for constraints, `sensitive = true` for secrets.
- Outputs: always `description`, `sensitive = true` where needed, prefer returning objects for related values.
- Cross-variable validation (1.9+): a variable's `validation` block can reference other variables.

## CI/CD Integration

1. **Validate** — format check + syntax + lint (`tflint`)
2. **Test** — native tests or Terratest
3. **Plan** — generate and review execution plan
4. **Apply** — execute with approvals for production

Cost optimization: mock providers for PR validation (free) → integration tests only on main branch → auto-cleanup to prevent orphaned resources → tag all test resources for spend tracking.

Security scanning: `trivy config .`, `checkov -d .`, tfsec/Terrascan. Policy as code: OPA, Sentinel. Never: hardcoded secrets, default VPC, skipped encryption, security groups open to `0.0.0.0/0`.

## Version Management

```hcl
version = "5.0.0"   # exact — avoid, inflexible
version = "~> 5.0"  # recommended — 5.0.x only
version = ">= 5.0"  # minimum — risky, breaking changes possible
```

| Component | Strategy | Example |
|---|---|---|
| Terraform | pin minor | `required_version = "~> 1.9"` |
| Providers | pin major | `version = "~> 5.0"` |
| Modules (prod) | pin exact | `version = "5.1.2"` |
| Modules (dev) | allow patch | `version = "~> 5.1"` |

Feature availability: `try()` (0.13+), `nullable = false` (1.1+), `moved` blocks (1.1+), `optional()` defaults (1.3+), native testing (1.6+), mock providers (1.7+), provider functions (1.8+), cross-variable validation (1.9+), write-only arguments (1.11+).

## Multi-Environment & GitOps
- Isolate via directory structure + separate state per environment, not just workspaces, once teams or blast radius diverge.
- Promote changes through branch-based GitOps: PR → plan (commented on PR) → merge → auto-apply with approval gate for prod.
- Keep variable precedence explicit: `-var-file` per environment over shared defaults.

## Governance (enterprise scale)
- RBAC / team-based access to state and apply permissions; service-catalog of approved modules for self-service infra.
- Compliance (SOC2, PCI-DSS, HIPAA): audit trails on every apply, drift detection as a scheduled job, not just on-demand.
- Cost: tag every resource; enforce budgets with policy as code rather than after-the-fact reporting.

## Reference
- `references/aws-modules.md` — AWS module patterns (VPC, EKS, RDS, S3, ALB, Lambda, Security Group) and AWS-specific best practices.
