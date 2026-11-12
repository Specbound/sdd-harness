---
name: security-audit
description: "Full-spectrum security audit: OWASP Top 10 review, SAST/dependency/secrets scanning, risk prioritization, and a pre-deployment checklist. Use when auditing an app/API for vulnerabilities, triaging scanner output, or signing off a security-sensitive release."
---

# Security Audit

## When to Use

- Auditing a web app, API, or service for vulnerabilities
- Triaging SAST/dependency/secrets scanner output and prioritizing fixes
- Running a structured pen-test or pre-deployment security review
- Hardening an app against OWASP Top 10 classes of bugs

Do not use for: formal compliance certification (needs legal/audit sign-off), or intrusive testing without written authorization.

## Mindset

| Principle | Application |
|-----------|-------------|
| Assume Breach | Design as if attacker already inside |
| Zero Trust | Never trust, always verify |
| Defense in Depth | Multiple layers, no single point of failure |
| Least Privilege | Minimum required access only |
| Fail Secure | On error, deny access — never fail open |

Before scanning, answer: What are we protecting (assets)? Who would attack (threat actors)? How (attack vectors)? What's the impact (business risk)?

## Workflow

1. **Recon** — map attack surface: entry points (APIs, forms, uploads), data flows, trust boundaries, where auth/authz is actually checked.
2. **Scan** — run SAST + dependency + secrets scanners (see tool tables below). Generate an SBOM for supply-chain visibility.
3. **Manual test** — walk the OWASP Top 10 checklist against the real code, not just scanner output; scanners miss business-logic flaws.
4. **Prioritize** — score findings by CVSS + EPSS + asset value + exposure (decision tree below).
5. **Fix & validate** — parameterized queries, output encoding, auth checks, etc.; re-scan; confirm no regression.
6. **Report** — structured findings (below) with severity, reproduction, business impact, and concrete remediation.

## OWASP Top 10 Checklist

- [ ] **A01 Broken Access Control** — authz on every protected route, deny-by-default, no IDOR (object refs checked against requester), CORS not wildcard
- [ ] **A02 Cryptographic Failures** — passwords hashed (bcrypt/argon2, cost 12+), TLS 1.2+ everywhere, no secrets in code/logs, encryption at rest
- [ ] **A03 Injection** — parameterized queries only, input validated, output encoded for XSS, no `eval`/dynamic code exec
- [ ] **A04 Insecure Design** — threat model exists, security requirements defined, business logic abuse cases tested
- [ ] **A05 Security Misconfiguration** — unused features disabled, errors sanitized, security headers set, no default creds
- [ ] **A06 Vulnerable Components** — dependencies current, no known CVEs, unused deps removed
- [ ] **A07 Authentication Failures** — MFA available, session invalidated on logout, timeout enforced, brute-force protected
- [ ] **A08 Integrity Failures** — dependency integrity verified (lockfiles committed), CI/CD pipeline secured, signed updates
- [ ] **A09 Logging Failures** — security events logged, logs protected, no sensitive data logged, alerting configured
- [ ] **A10 SSRF / Exceptional Conditions** — URL allow-list for outbound calls, network segmentation, no catch-all exception handlers that fail open

2025 shift to be aware of: SSRF folded into A01, new **Supply Chain** (deps/CI-CD/build integrity) and **Exceptional Conditions** (fail-open states) categories, root-cause focus over symptom patching.

## Risk Prioritization

```
Is it actively exploited (EPSS > 0.5)?
├── YES → CRITICAL: immediate action
└── NO → check CVSS
         ├── ≥ 9.0            → HIGH
         ├── 7.0–8.9          → weigh against asset value/exposure
         └── < 7.0            → schedule for later
```

Severity classification for findings: **Critical** = RCE/auth bypass/mass data exposure. **High** = data exposure/privilege escalation. **Medium** = limited scope, needs conditions. **Low** = informational/best-practice.

## SAST — Tool Quick Reference

| Language | Tool | Command |
|----------|------|---------|
| Python | Bandit | `bandit -r . -ll -ii -f json` |
| JS/TS | ESLint Security | `eslint . --ext .js,.ts -f json` (plugin `security/recommended`) |
| Multi | Semgrep | `semgrep --config=auto --json` / `--config=p/owasp-top-ten` |
| Java | SpotBugs | `mvn spotbugs:check` |
| Ruby | Brakeman | `brakeman -o report.json -f json` |
| Go | gosec | `gosec -fmt=json -out=gosec.json ./...` |
| Rust | clippy | `cargo clippy -- -W clippy::unwrap_used` |

Run Semgrep first (multi-language baseline), then the language-specific tool. Combine ≥2 tools — each catches different classes. Tune false positives with exclusions, not by disabling rules wholesale.

**Vulnerable → Secure patterns to check for:**
- SQL: string-built queries → parameterized queries / ORM
- XSS: raw `innerHTML`/`document.write` → `textContent`, framework auto-escaping, or `DOMPurify.sanitize()`
- Secrets: hardcoded keys/passwords → `os.environ.get(...)` / secret manager
- Path traversal: user input straight into `open()` → `os.path.realpath()` + prefix check against an allow-listed dir
- Deserialization: `pickle.loads`/`yaml.load` on untrusted data → `json.loads` / `yaml.safe_load`
- Command injection: `shell=True` + concatenated input → array args (`subprocess.run([...])`) or `shlex.quote`
- Randomness: `random` for tokens/sessions → `secrets.token_hex` / `token_urlsafe`

## Dependency & Secrets Scanning

```bash
# Python
pip install safety pip-audit pip-licenses
# JavaScript
npm audit; npm install -g snyk npm-check-updates
# Go
go install golang.org/x/vuln/cmd/govulncheck@latest
# Rust
cargo install cargo-audit
```

- Generate an SBOM (CycloneDX/SPDX) for supply-chain visibility and license compliance.
- Prioritize by CVSS + exploit availability; auto-update patch versions only, major versions need manual review + full test suite.
- Pin versions, commit lockfiles, verify package checksums; use private registries for critical deps where possible.
- Secrets to grep for: `api_key`/`apikey`, `token`/`bearer`/`jwt`, `password`/`secret`, cloud creds (`AKIA...`, `AWS_`/`AZURE_`/`GCP_` prefixes), `-----BEGIN ... PRIVATE KEY-----`.

## Pre-Deployment Checklist

Before any production deploy:

- [ ] No hardcoded secrets — all in env vars / secret manager, `.env*` gitignored
- [ ] All user input validated against a schema (allow-list, not deny-list)
- [ ] File uploads restricted by size, MIME type, and extension
- [ ] All queries parameterized; no string-built SQL
- [ ] Tokens in httpOnly/Secure/SameSite cookies, not `localStorage`
- [ ] Authorization checked before every sensitive operation (not just authentication)
- [ ] Row Level Security / equivalent enabled on multi-tenant tables
- [ ] User-supplied HTML sanitized; CSP header configured
- [ ] CSRF tokens on state-changing requests; SameSite=Strict cookies
- [ ] Rate limiting on all endpoints, stricter on expensive ones (search, auth)
- [ ] Errors return generic messages to clients; stack traces only in server logs
- [ ] No sensitive data (passwords, tokens, full card numbers) in logs
- [ ] `npm audit` / equivalent clean; lockfiles committed; Dependabot-equivalent enabled
- [ ] HTTPS enforced; security headers set (see below)

## Security Headers

```
Content-Security-Policy: default-src 'self'; script-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=()
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Scan without mapping attack surface first | Recon, then scan |
| Alert on every CVE | Prioritize by exploitability + asset value |
| Ignore recurring false positives | Maintain a verified baseline |
| Fix symptoms only | Address root cause |
| Scan once before deploy | Continuous scanning (CI/CD + schedule) |
| Trust third-party deps blindly | Verify integrity, pin, audit |

## Reporting

Each finding should answer: **What** (clear description) · **Where** (file/line or endpoint) · **Why** (root cause) · **Impact** (business consequence) · **How to fix** (specific remediation). Use the severity classification above; include CVSS/EPSS where available.

## Related Skills

For deep dives beyond this audit pass: `sql-injection-testing`, `xss-html-injection`, `broken-authentication`, `idor-testing`, `file-path-traversal`, `api-security-best-practices`, `pentest-checklist`, `pentest-commands`.
