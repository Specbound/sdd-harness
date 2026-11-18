---
name: dependency-upgrade
description: Audit, prioritize, and safely execute dependency/framework version upgrades — vulnerability and license scanning, compatibility checks, staged rollout, and rollback. Use when upgrading major versions, patching CVEs, or planning an incremental upgrade path.
---

## When to use
Upgrading framework/library major versions, patching security-vulnerable dependencies, resolving dependency conflicts, planning an incremental upgrade path, or auditing for license/supply-chain risk.

**Don't use for:** full platform/language rewrites (React→Vue, Python 2→3, REST→GraphQL) — that's a modernization project, see the legacy-modernization skill for the strangler-fig approach to that.

## 1. Discover and audit

| Ecosystem | Manifest | Outdated check | Vuln/license audit |
|---|---|---|---|
| npm/yarn | package.json, lockfile | `npm outdated`, `npx npm-check-updates` | `npm audit`, `npm ls <pkg>` for why-installed |
| Python | requirements.txt, pyproject.toml, Pipfile | `pip list --outdated` | `pip-audit`, `safety check` |
| Ruby | Gemfile.lock | `bundle outdated` | `bundle audit` |
| Java | pom.xml / build.gradle | `mvn versions:display-dependency-updates` | OSS Index / Sonatype |
| Go | go.mod | `go list -u -m all` | `govulncheck` |
| Rust | Cargo.toml | `cargo outdated` | `cargo audit` |

Classify every outdated dependency by semver jump (`MAJOR.MINOR.PATCH`: major = breaking, minor = additive, patch = fix) and check for typosquatting on anything newly added (Levenshtein distance ≤2 from a well-known package name is a red flag, not a coincidence).

## 2. Score and prioritize
```
priority_score = 100·is_security_fix + update_type_weight + age_bonus + min(releases_behind·2, 20)
  update_type_weight: major=20, minor=10, patch=5
  age_bonus: >365d stale=30, >180d=20, >90d=10
severity_risk = cvss_base + 1.5·exploit_available + 1.2·publicly_disclosed
```
Security fixes always jump the queue regardless of score. Batch the rest: **security** (immediate, full test run) → **patch** (grouped, smoke test) → **minor** (incremental, regression test) → **major** (one at a time, full test pass + migration guide).

**License check:** flag any new dependency whose license is incompatible with the project's (e.g. GPL-3.0 pulled into an MIT project) or on a restricted list (AGPL-3.0 and similar copyleft) — this is a legal blocker, not a style nit.

## 3. Plan the upgrade
- Read the changelog/MIGRATION.md between current and target version before touching code.
- **One major version at a time** — never skip versions or batch multiple majors in one change.
- For a big jump, find safe intermediate stopping points: last patch of each minor, versions with a long stability window, versions just before a breaking change — stage through those instead of jumping straight to latest.
- Build a compatibility matrix for interdependent packages before upgrading any of them (e.g. react/react-dom/react-router/@testing-library versions must move together).

## 4. Execute, per dependency/version step
```bash
npm install <pkg>@<version>   # one package, one version bump
npm test && npm run build     # must pass before the next step
```
- Check for and run codemods first (`npx react-codemod ...`, `ng update ...`, framework CLIs often ship one).
- Angular: `ng update @angular/core@<v> --dry-run` → fix → `ng update @angular/cli`. React: codemods for lifecycle renames, then `npm run build && npm test -- --coverage`. Vue 2→3: `npx @vue/migration-tool`, watch for Composition API / multi-root / Teleport changes.
- Update peer dependencies alongside; `npm install --legacy-peer-deps` or `--force` only as a last resort, not a default.

## 5. Test before calling it done
Capture a baseline (unit, integration, e2e, perf, bundle size) **before** the upgrade, then re-run the same suite after and diff the two — a plain "tests pass" isn't enough evidence that behavior didn't shift. Add a visual-regression/snapshot pass for UI-heavy upgrades. Smoke-test the critical user paths manually even when automated coverage is high.

## 6. Automate the routine cases
```yaml
# renovate.json — auto-merge safe, flag risky
packageRules:
  - matchUpdateTypes: [minor, patch]
    automerge: true
  - matchUpdateTypes: [major]
    automerge: false
    labels: [major-update]
```
Dependabot works the same way via `.github/dependabot.yml` (`schedule.interval`, `open-pull-requests-limit`). Let automation handle patch/minor; keep majors on a human-reviewed PR.

## 7. Rollback plan
Tag before starting (`git tag pre-upgrade-$(date +%Y%m%d)`), work on a branch, and script the revert:
```bash
mv package.json.backup package.json && mv package-lock.json.backup package-lock.json
rm -rf node_modules && npm ci && npm test
```
If tests fail post-upgrade and the fix isn't obvious in a few minutes, revert first and debug on the branch — don't leave the main branch broken while investigating.

## Checklist
**Pre:** current versions reviewed, changelogs read, feature branch + tag created, baseline test run captured.
**During:** one dependency/version at a time, peer deps resolved, tests green after each step, bundle-size delta checked.
**Post:** full regression + perf pass, docs/CHANGELOG updated, staged rollout monitored before prod, lockfile committed.

## Common pitfalls
Upgrading everything at once (can't tell what broke) · skipping tests between steps · ignoring peer-dependency warnings · forgetting to commit the lockfile · skipping major versions to "save time" · no rollback plan before starting · treating `npm audit fix --force` as safe without a test run after.
