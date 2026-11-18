---
name: cloud-sdks
description: Vendor SDK references: Azure SDK (all languages), AWS, M365 agents, DBOS durable workflows, Firebase. Use when picking a cloud client/SDK or debugging its auth/retry/pagination.
---

# cloud-sdks — domain router

This is a routing skill for the **cloud-sdks** domain. It holds no technique itself — it lists the sub-skills in this domain so you can load the right one(s).

**How to use:** scan the table, then READ the SKILL.md at each path that genuinely helps the task with the Read tool. **Load as many as the task needs — not just one.** A task that spans sub-skills (e.g. build + test, or debug + fix infra) should pull every relevant row. Skip the rest.


| sub-skill | what it covers | path |
|---|---|---|
| `aws-serverless` | Specialized skill for building production-ready serverless applications on AWS. Covers Lambda functions, API Gateway, DynamoDB, SQS/SNS event-driven patterns, S | `~/.claude/skill-library/aws-serverless/SKILL.md` |
| `aws-skills` | AWS development with infrastructure automation and cloud architecture patterns | `~/.claude/skill-library/aws-skills/SKILL.md` |
| `azure-sdk` | Azure SDK reference across Python, TS, .NET, Java, Rust: package/client names, DefaultAzureCredential auth, retry/pagination/LRO for Storage, Cosmos DB, Key Vau | `~/.claude/skill-library/azure-sdk/SKILL.md` |
| `dbos` | Build reliable, fault-tolerant applications with DBOS durable workflows in Python, Go, or TypeScript. Use when adding DBOS to code, writing workflows/steps, usi | `~/.claude/skill-library/dbos/SKILL.md` |
| `firebase` | Firebase gives you a complete backend in minutes - auth, database, storage, functions, hosting. But the ease of setup hides real complexity. Security rules are  | `~/.claude/skill-library/firebase/SKILL.md` |
| `gcp-cloud-run` | Specialized skill for building production-ready serverless applications on GCP. Covers Cloud Run services (containerized), Cloud Run Functions (event-driven), c | `~/.claude/skill-library/gcp-cloud-run/SKILL.md` |
| `m365-agents` | Build multichannel Teams/M365/Copilot Studio agents with the Microsoft 365 Agents SDK (.NET, Python, TypeScript) — AgentApplication routing, hosting, auth, stre | `~/.claude/skill-library/m365-agents/SKILL.md` |

_7 sub-skills. If none fit, the task likely belongs to another domain router._
