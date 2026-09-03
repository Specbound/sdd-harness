---
name: error-handling-patterns
description: "Master error handling patterns across languages including exceptions, Result types, error propagation, and graceful degradation to build resilient applications. Use when implementing error handling..."
risk: unknown
source: community
---

# Error Handling Patterns

Build resilient applications with robust error handling strategies that gracefully handle failures and provide excellent debugging experiences.

## Use this skill when

- Implementing error handling in new features
- Designing error-resilient APIs
- Debugging production issues
- Improving application reliability
- Creating better error messages for users and developers
- Implementing retry and circuit breaker patterns
- Handling async/concurrent errors
- Building fault-tolerant distributed systems

## Do not use this skill when

- The task is unrelated to error handling patterns
- You need a different domain or tool outside this scope

## Instructions

- Clarify goals, constraints, and required inputs.
- Apply relevant best practices and validate outcomes.
- Provide actionable steps and verification.
- If detailed examples are required, open `resources/implementation-playbook.md`.

## Anti-Patterns to Avoid

### ❌ Trusting LLM output labels without semantic validation
LLM-generated semantic signals (finish_reason, tool_call_type) may be mislabeled independently of actual output content, causing false-positive error handlers and retry storms. Always validate signals against actual output structure before routing to error handlers. (source: 2026-07-29 ZORAAI-11493)

### ❌ Text scanning for error status classification
Setting error status by checking if report text contains "error"/"failed" keywords falsely fails diagnostic agents. Use structured status fields only. (source: 2026-08-25 [friction, insight, enforceable])

## Resources

- `resources/implementation-playbook.md` for detailed patterns and examples.
