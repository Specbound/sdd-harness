---
name: code-quality
description: Correctness & maintainability: TDD/testing, debugging, code review, refactoring, dependency upgrades, linting, test automation. Use when testing, debugging, reviewing, or cleaning up code.
---

# code-quality — domain router

This is a routing skill for the **code-quality** domain. It holds no technique itself — it lists the sub-skills in this domain so you can load the right one(s).

**How to use:** scan the table, then READ the SKILL.md at each path that genuinely helps the task with the Read tool. **Load as many as the task needs — not just one.** A task that spans sub-skills (e.g. build + test, or debug + fix infra) should pull every relevant row. Skip the rest.


| sub-skill | what it covers | path |
|---|---|---|
| `ab-test-setup` | Structured guide for setting up A/B tests with mandatory gates for hypothesis, metrics, and execution readiness. | `~/.claude/skill-library/ab-test-setup/SKILL.md` |
| `bats-testing-patterns` | Master Bash Automated Testing System (Bats) for comprehensive shell script testing. Use when writing tests for shell scripts, CI/CD pipelines, or requiring test | `~/.claude/skill-library/bats-testing-patterns/SKILL.md` |
| `code-reviewer` | Use when reviewing a pull request or diff, requesting review of your own work before merging, or responding to review feedback. Covers reviewer checklists and s | `~/.claude/skill-library/code-reviewer/SKILL.md` |
| `codebase-legibility` | Set up a codebase for optimal Claude Code work: CLAUDE.md hierarchy (root + subdirectory files), .claudeignore for noise exclusion, codebase map markdown, and p | `~/.claude/skill-library/codebase-legibility/SKILL.md` |
| `codex-review` | Professional code review with auto CHANGELOG generation, integrated with Codex AI | `~/.claude/skill-library/codex-review/SKILL.md` |
| `compiled-truth-pattern` | Structure for living knowledge documents and memory observations. Compiled synthesis at top (rewrite in place when evidence changes), append-only evidence at bo | `~/.claude/skill-library/compiled-truth-pattern/SKILL.md` |
| `dependency-upgrade` | Audit, prioritize, and safely execute dependency/framework version upgrades — vulnerability and license scanning, compatibility checks, staged rollout, and roll | `~/.claude/skill-library/dependency-upgrade/SKILL.md` |
| `e2e-testing` | End-to-end testing workflow with Playwright for browser automation, visual regression, cross-browser testing, and CI/CD integration. | `~/.claude/skill-library/e2e-testing/SKILL.md` |
| `e2e-testing-patterns` | Master end-to-end testing with Playwright and Cypress to build reliable test suites that catch bugs, improve confidence, and enable fast deployment. Use when im | `~/.claude/skill-library/e2e-testing-patterns/SKILL.md` |
| `error-handling-patterns` | Master error handling patterns across languages including exceptions, Result types, error propagation, and graceful degradation to build resilient applications. | `~/.claude/skill-library/error-handling-patterns/SKILL.md` |
| `find-bugs` | Find bugs, security vulnerabilities, and code quality issues in local branch changes. Use when asked to review changes, find bugs, security review, or audit cod | `~/.claude/skill-library/find-bugs/SKILL.md` |
| `fix-review` | Verify fix commits address audit findings without new bugs | `~/.claude/skill-library/fix-review/SKILL.md` |
| `impeccable-audit` | Frontend visual design quality auditor. Applies Impeccable's 27 deterministic anti-pattern rules + 7-domain design principles to catch AI-generated UI fingerpri | `~/.claude/skill-library/impeccable-audit/SKILL.md` |
| `kaizen` | Guide for continuous improvement, error proofing, and standardization. Use this skill when the user wants to improve code quality, refactor, or discuss process  | `~/.claude/skill-library/kaizen/SKILL.md` |
| `lint-and-validate` | Automatic quality control, linting, and static analysis procedures. Use after every code modification to ensure syntax correctness and project standards. Trigge | `~/.claude/skill-library/lint-and-validate/SKILL.md` |
| `playwright-skill` | Complete browser automation with Playwright. Auto-detects dev servers, writes clean test scripts to /tmp. Test pages, fill forms, take screenshots, check respon | `~/.claude/skill-library/playwright-skill/SKILL.md` |
| `production-code-audit` | Autonomously deep-scan entire codebase line-by-line, understand architecture and patterns, then systematically transform it to production-grade, corporate-level | `~/.claude/skill-library/production-code-audit/SKILL.md` |
| `proof-collaborative-review` | Use during SDD approval-gate phases to publish a markdown artifact to a live collaborative Proof document, wait for human review/adjustment, retrieve the final  | `~/.claude/skill-library/proof-collaborative-review/SKILL.md` |
| `pypict-skill` | Use when a test matrix has too many parameter combinations to test exhaustively — generate a pairwise (all-pairs) combinatorial test set with PICT instead of ha | `~/.claude/skill-library/pypict-skill/SKILL.md` |
| `python-testing-patterns` | Implement comprehensive testing strategies with pytest, fixtures, mocking, and test-driven development. Use when writing Python tests, setting up test suites, o | `~/.claude/skill-library/python-testing-patterns/SKILL.md` |
| `refactoring-safely` | Safely restructure code without changing behavior — small change/test/commit cycles, legacy modernization via strangler fig, and technical-debt triage. Use when | `~/.claude/skill-library/refactoring-safely/SKILL.md` |
| `repo-drift-review` | Weekly harness integrity sweep: checks MEMORY.md index vs files on disk, settings.json hooks vs scripts on disk, and doc links vs real paths. Auto-fixes mechani | `~/.claude/skill-library/repo-drift-review/SKILL.md` |
| `sharp-edges` | Identify error-prone APIs and dangerous configurations | `~/.claude/skill-library/sharp-edges/SKILL.md` |
| `shellcheck-configuration` | Master ShellCheck static analysis configuration and usage for shell script quality. Use when setting up linting infrastructure, fixing code issues, or ensuring  | `~/.claude/skill-library/shellcheck-configuration/SKILL.md` |
| `sonar-hotspot-review` | Fetches open SonarQube Security Hotspots AND Code Quality Issues, traces each back to its source in the repo, and produces a markdown triage report explaining w | `~/.claude/skill-library/sonar-hotspot-review/SKILL.md` |
| `systematic-debugging` | Use when encountering any bug, test failure, unexpected behavior, or production incident, before proposing fixes. Covers root-cause investigation, strategy sele | `~/.claude/skill-library/systematic-debugging/SKILL.md` |
| `test-automator` | Master AI-powered test automation with modern frameworks, | `~/.claude/skill-library/test-automator/SKILL.md` |
| `test-driven-development` | Use when implementing any feature or bugfix, before writing implementation code. Covers the red-green-refactor cycle, source-grounding tests in real code before | `~/.claude/skill-library/test-driven-development/SKILL.md` |
| `test-fixing` | Run tests and systematically fix all failing tests using smart error grouping. Use when user asks to fix failing tests, mentions test failures, runs test suite  | `~/.claude/skill-library/test-fixing/SKILL.md` |
| `testing-patterns` | Jest testing patterns, factory functions, mocking strategies, and TDD workflow. Use when writing unit tests, creating test factories, or following TDD red-green | `~/.claude/skill-library/testing-patterns/SKILL.md` |
| `testing-qa` | Comprehensive testing and QA workflow covering unit testing, integration testing, E2E testing, browser automation, and quality assurance. | `~/.claude/skill-library/testing-qa/SKILL.md` |
| `unit-testing-test-generate` | Generate comprehensive, maintainable unit tests across languages with strong coverage and edge case focus. | `~/.claude/skill-library/unit-testing-test-generate/SKILL.md` |
| `verification-before-completion` | Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output be | `~/.claude/skill-library/verification-before-completion/SKILL.md` |
| `webapp-testing` | Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functionality, debugging UI behavior, capturing br | `~/.claude/skill-library/webapp-testing/SKILL.md` |

_34 sub-skills. If none fit, the task likely belongs to another domain router._
