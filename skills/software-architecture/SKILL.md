---
name: software-architecture
description: "Architecture decision-making: context discovery, pattern-selection decision trees, trade-off/ADR documentation, and concrete Clean/Hexagonal/DDD implementation patterns plus code-quality conventions. Use when designing system architecture, choosing a pattern, or reviewing a design for architectural soundness."
---

Architecture decision framework (requirements → trade-offs → ADRs) plus concrete Clean/Hexagonal/DDD patterns and code-quality conventions.

## Use this skill when
- Designing new system architecture or evaluating a major design change
- Choosing between architectural patterns (monolith/microservices, DDD, CQRS, etc.)
- Documenting an architecture decision or reviewing one for soundness
- Setting code-quality/structure conventions for a codebase

## Do not use this skill when
- The change is a small, local refactor with no architectural impact
- You need database schema design specifically — see `database-design`
- You need deployment/CI pipeline design — see `deployment-pipeline-design`

## Core Principle
**"Simplicity is the ultimate sophistication."** Start simple, add complexity only when proven necessary — you can always add a pattern later, but removing one is much harder than adding it.

## Context Discovery (ask before proposing anything)
1. **Scale** — users (10 / 1K / 100K / 1M+), data volume, transaction rate
2. **Team** — solo vs. team, size, expertise, distributed vs. co-located
3. **Timeline** — MVP/prototype vs. long-term product, time-to-market pressure
4. **Domain** — CRUD-heavy vs. complex business logic, real-time needs, compliance
5. **Constraints** — budget, legacy integration, stack preferences

| | MVP | SaaS | Enterprise |
|---|---|---|---|
| Scale | <1K | 1K–100K | 100K+ |
| Team | Solo | 2–10 | 10+ |
| Timeline | Weeks | Months | Years |
| Architecture | Simple monolith | Modular monolith | Distributed |
| Patterns | Minimal | Selective | Full range |

## Pattern Selection Decision Tree
```
Data Access Complexity?
├─ HIGH (complex queries, testing needed) → Repository + Unit of Work
│    (only if data source will actually change — otherwise plain ORM)
└─ LOW (simple CRUD)                      → ORM direct (Prisma, Drizzle)

Business Rules Complexity?
├─ HIGH (domain logic varies by context) → DDD
│    (full DDD only with domain experts on the team; else partial — rich
│     entities, clear boundaries, skip full aggregates)
└─ LOW (mostly CRUD)                     → Transaction Script

Independent Scaling Needed?
├─ YES, AND clear domain boundaries AND team >10 AND different per-service
│    scaling needs (all three) → Microservices
│    (any one missing → Modular Monolith; extract services later when proven)
└─ NO → Modular Monolith

Real-time Requirements?
├─ HIGH, and eventual consistency acceptable → Event-Driven (Kafka/RabbitMQ/Redis)
└─ LOW, or consistency must be immediate    → Synchronous (REST/GraphQL)
```
Before adopting ANY pattern, answer: (1) what specific problem does it solve, (2) is there a simpler alternative, (3) can this be deferred until actually needed?

| Pattern | Anti-pattern | Simpler alternative |
|---|---|---|
| Microservices | Premature splitting | Start monolith, extract later |
| Clean/Hexagonal | Over-abstraction | Concrete first, interfaces later |
| Event Sourcing | Over-engineering | Append-only audit log |
| CQRS | Unnecessary complexity | Single model |
| Repository | YAGNI for simple CRUD | ORM direct access |

## Patterns Quick Reference
| Category | Low complexity | High complexity |
|---|---|---|
| Data access | Active Record (simple CRUD) | Repository/Unit of Work/Data Mapper (testing, multiple sources) |
| Domain logic | Transaction Script (procedural) | Domain Model / full DDD (complex rules, domain experts) |
| System topology | Modular Monolith (unclear boundaries, small team) | Microservices (proven independent scaling, large team) |
| Consistency | Synchronous REST/GraphQL | Event-Driven / CQRS / Saga (loose coupling, diverging read-write load) |

## Architecture by Scale (concrete trade-offs)
| Tier | Structure | Data layer | Domain model | Migration trigger |
|---|---|---|---|---|
| MVP (solo, <1K) | Monolith (Next.js full-stack) | Prisma direct, no abstraction | JWT auth, no Repository | Users >10K → extract payment service; team >3 → add Repository |
| SaaS (5-10 devs) | Modular monolith (NestJS) | Repository pattern | Partial DDD, rich entities | Team >10 → consider microservices; read perf issues → add CQRS |
| Enterprise (100K+) | Microservices + API gateway | Polyglot persistence | Full DDD, bounded contexts | Already distributed — add service mesh, distributed tracing, Kafka as scale demands |

## Trade-off Analysis & ADRs
Document every non-trivial decision:
```markdown
# ADR-[XXX]: [Decision Title]
## Status
Proposed | Accepted | Deprecated | Superseded by [ADR-YYY]
## Context
[Problem + constraints: team size, scale, timeline, budget]
## Decision
[What was chosen, specifically]
## Rationale
[Why — tied to constraints and requirements, not preference]
## Trade-offs
[What's given up — be honest]
## Consequences
- Positive: [benefits]
- Negative: [costs/risks]
- Mitigation: [how addressed]
## Revisit Trigger
[Condition that should reopen this decision]
```
Store as `docs/architecture/adr-NNN-title.md`, sequentially numbered, never deleted (superseded, not removed).

## Clean Architecture / Hexagonal / DDD
**Clean Architecture** — dependencies point inward only: Entities → Use Cases → Interface Adapters (controllers/gateways) → Frameworks & Drivers (UI/DB). Inner layers know nothing about outer ones; core is testable with zero framework/DB/UI dependencies.

**Hexagonal (Ports & Adapters)** — domain core depends only on interfaces (ports); adapters implement them:
```python
class OrderService:  # domain core — no infra imports
    def __init__(self, orders: OrderRepositoryPort, payments: PaymentGatewayPort):
        self.orders, self.payments = orders, payments

    async def place_order(self, order: Order) -> OrderResult:
        if not order.is_valid():
            return OrderResult(success=False, error="Invalid order")
        payment = await self.payments.charge(order.total, order.customer_id)
        if not payment.success:
            return OrderResult(success=False, error="Payment failed")
        return OrderResult(success=True, order=await self.orders.save(order))

class PaymentGatewayPort(ABC):
    @abstractmethod
    async def charge(self, amount: Money, customer: str) -> PaymentResult: ...
# StripePaymentAdapter / MockPaymentAdapter implement the port — swap freely for tests
```

**DDD tactical patterns**: Value Objects (immutable, `@dataclass(frozen=True)`, validate in `__post_init__`) · Entities (identity + mutable state + business-rule methods, not just data) · Aggregates (consistency boundary — enforce invariants in the root, reference other aggregates by ID only) · Repositories (persist/reconstitute aggregates, publish domain events on save).

**Common pitfalls**: anemic domain (entities with only data, no behavior) · framework coupling in business logic · fat controllers · repository leakage (exposing ORM objects past the boundary) · over-engineering Clean Architecture onto simple CRUD.

## Code Quality Standards
- Early returns over nested conditionals.
- Functions >50 lines or files >200 lines: split. If a decomposed piece isn't reused elsewhere, keep it in the same file; split into a new file only once it's genuinely shared or the file itself exceeds ~200 lines.
- Library-first: search for an existing library/service before writing custom code (e.g. `cockatiel` for retries, not a hand-rolled retry loop). Custom code is justified only for domain-unique logic, special-requirement hot paths, or when no library meets the need after real evaluation.
- Naming: no `utils`/`helpers`/`common`/`shared` dumping grounds — use domain-specific names (`OrderCalculator`, not `utils.js`).
- Separation of concerns: no business logic in UI components, no DB queries in controllers.
- Max nesting depth 3; typed error handling, no bare catches.

## Architecture Review Checklist
- [ ] Requirements and constraints clearly understood (not assumed)
- [ ] Each non-trivial decision has a documented trade-off / ADR
- [ ] Simpler alternative was considered and explicitly rejected, not skipped
- [ ] Team expertise matches the chosen patterns (full DDD needs domain experts on-team)
- [ ] Reliability, scalability, and security impact assessed (High/Medium/Low)
- [ ] No architectural anti-pattern from the table above present without justification
- [ ] Testability preserved: core logic testable without DB/UI/external services

## Broader Pattern Catalog (pointers, not exhaustive)
- **Distributed systems**: service mesh (Istio/Linkerd), event streaming (Kafka/Pulsar/NATS), Saga/Outbox for distributed transactions, circuit breaker/bulkhead/timeout for resilience.
- **Security architecture**: Zero Trust model, OAuth2/OIDC/JWT, encryption at rest and in transit, secrets via Vault/cloud KMS — defense in depth, not a single boundary.
- **Data architecture**: polyglot persistence, event sourcing + CQRS where read/write load actually diverges, database-per-service in microservices, eventual consistency patterns.
- **Documentation**: C4 model for system/container/component diagrams alongside ADRs.

## Related Skills
- `database-design` — schema design, migrations
- `kubernetes-architect` — platform/deployment topology for the chosen architecture
- `deployment-pipeline-design` — CI/CD for the resulting services
- `security-audit` — deeper security-architecture review
