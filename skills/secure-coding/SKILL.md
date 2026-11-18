---
name: secure-coding
description: "Secure coding patterns for backend, frontend, and mobile: input validation, auth, CSRF/SSRF, XSS prevention, WebView/storage/cert-pinning. Use when writing or reviewing code touching user input, auth, API endpoints, or DOM rendering — not for auditing an existing system (see security-audit)."
---

# Secure Coding

Writing secure code, not auditing it — for audits, threat modeling, and scanning, use `security-audit`.

## When to Use

- Implementing or reviewing auth, API endpoints, or any code that touches user input
- Rendering user-controlled content in the DOM (React/Vue/Angular/vanilla JS)
- Writing mobile code that touches WebViews, local storage, or network calls

## Backend

### Input & Injection
- Validate with an allowlist schema (e.g. Zod), not a blacklist. Reject unknown fields.
- SQL/NoSQL: parameterized queries / ORM only — never string-build a query with user input.
- Command execution: array args (`subprocess.run([...])`), never `shell=True` + concatenation.
- File paths from user input: resolve with `os.path.realpath()` and verify the result still starts with the allowed base dir.
- Deserialization: `json.loads`/`yaml.safe_load` — never `pickle.loads`/`yaml.load` on untrusted data.

### Auth & Sessions
- Hash passwords with bcrypt/argon2 (cost 12+). Never roll your own.
- JWT: verify signature + expiration server-side; short-lived access tokens + rotating refresh tokens.
- Store tokens in httpOnly + Secure + SameSite=Strict cookies, not `localStorage` (XSS-readable).
- Authorization check on every sensitive operation — authentication alone is not authorization:
  ```ts
  if (requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' })
  ```
- Enable Row Level Security (or equivalent) on any multi-tenant table.

### CSRF / SSRF
- CSRF: anti-CSRF token on state-changing requests + `SameSite=Strict` cookies; validate Origin/Referer on non-GET.
- SSRF: allowlist outbound destinations; validate/resolve URLs server-side before fetching; block internal/metadata IP ranges (169.254.169.254, RFC1918).

### Headers, Secrets, Errors
```
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
```
- Secrets from env vars / a secrets manager — never hardcoded; verify presence at startup (`if (!apiKey) throw ...`).
- Errors returned to clients: generic message only. Full detail + stack trace goes to server logs, never the response body.
- Logs: never log passwords, tokens, full card numbers, or secrets — redact or log only non-sensitive identifiers (`userId`, `last4`).
- Rate-limit all endpoints; tighter limits on auth and search.

## Frontend

### XSS Prevention
| Vulnerable | Secure |
|---|---|
| `el.innerHTML = userInput` | `el.textContent = userInput`, or `DOMPurify.sanitize(userInput)` if HTML is required |
| `document.write(...)` | DOM APIs (`createElement`, `textContent`) |
| React `dangerouslySetInnerHTML={{__html: raw}}` | `dangerouslySetInnerHTML={{__html: DOMPurify.sanitize(raw)}}` |
| Vue `v-html="raw"` | `v-text` for plain text, or sanitize before binding |
| Angular `[innerHTML]` bypassing `DomSanitizer` | let Angular's built-in sanitizer run — don't bypass it |
| `location.href = userInput` | validate via `new URL(input)` and check `['http:','https:'].includes(protocol)` before navigating |

```ts
function sanitizeURL(url: string): string {
  try {
    const u = new URL(url)
    if (['http:', 'https:'].includes(u.protocol)) return u.href
  } catch {}
  return '#'
}
```

### CSP & Clickjacking
- Set CSP with nonces for inline scripts; avoid `unsafe-inline`/`unsafe-eval` where possible.
- `X-Frame-Options: DENY` or CSP `frame-ancestors 'none'` to stop clickjacking.
- External scripts/styles: use Subresource Integrity (SRI) hashes.
- Links to external sites: `rel="noopener noreferrer"` on `target="_blank"`.

### Redirects & Token Storage
- Open redirect: validate destination against an allowlist or map to fixed internal identifiers — don't redirect to a raw user-supplied URL.
- Auth tokens: httpOnly cookie, not `localStorage`/`sessionStorage` (any XSS reads those).
- Session timeout + multi-tab logout propagation via storage events.

## Mobile

### WebView
- JavaScript disabled by default; enable only for trusted, allowlisted origins.
- URL allowlist + HTTPS-only enforcement for anything the WebView loads.
- No local file-scheme access (`file://`) from loaded content; disable universal access from file URLs.
- Apply CSP inside the WebView content itself where the app controls it.

### Storage & Network
- Secrets/tokens in Keychain (iOS) / Keystore (Android), not plain SharedPreferences/UserDefaults or SQLite unencrypted.
- Certificate pinning for API calls; reject self-signed/untrusted chains.
- Exclude sensitive files from cloud backups (`NSURLIsExcludedFromBackupKey`, Android `android:allowBackup="false"` or `fullBackupContent` rules).
- Biometric auth (Touch ID/Face ID/BiometricPrompt) with a secure fallback, never as the sole gate on sensitive data.

### Hardening
- Root/jailbreak detection → degrade gracefully (don't just crash; decide what's actually blocked).
- Obfuscate release builds (ProGuard/R8, iOS symbol stripping); strip debug info and logging from production builds.
- Validate deep link parameters like any other untrusted input — scheme, host, and params all attacker-controlled.

## Quick XSS Scan Patterns

Grep for these before merging frontend code; each is a signal, not an automatic bug — check for sanitization nearby:

```
innerHTML, outerHTML, document.write, insertAdjacentHTML
dangerouslySetInnerHTML   (React)
v-html                    (Vue)
[innerHTML]               (Angular, if bypassing DomSanitizer)
location.href / window.open with unvalidated input
```
Presence of `DOMPurify` or `.sanitize(` nearby downgrades severity; absence is the finding.

```bash
eslint --plugin security .          # eslint-plugin-security
semgrep --config=p/xss --json       # XSS-specific ruleset
```

## Anti-Patterns

| Don't | Do |
|---|---|
| Trust client-side validation alone | Re-validate everything server-side |
| Disable a lint/security rule to unblock a merge | Fix the underlying pattern |
| Store tokens in `localStorage` | httpOnly cookie |
| Build CSP with `unsafe-inline` "for now" | Use nonces/hashes from the start |
| Ship WebView with JS + file access on by default | Both off unless a specific origin needs them |
| Catch-all exception handlers that swallow security errors | Fail closed; log and deny |
