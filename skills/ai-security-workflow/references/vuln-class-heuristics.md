# Vuln-Class Review Heuristics & False-Positive Discipline

Whitebox, tool-agnostic reasoning heuristics distilled from the Strix pentest
skill library. Used by `ai-security-workflow`:
- **Phase 2 (Vuln Scan)** → the "what to look for" column per class.
- **Phase 3 (Triage)** → the "prove the negative" validation gate + false-positive catalog.

This is source-reasoning knowledge only. It deliberately excludes live-exploitation
tradecraft (proxy interception, browser payloads, transport fuzzing) — that presumes
a running target and a sandbox the harness does not have.

---

## The False-Positive Discipline (apply in Phase 3 to EVERY finding)

A finding is not "confirmed" until you have reasoned through all three gates. If you
cannot satisfy gate 1, it is `needs-more-info`, not `confirmed`.

1. **Reachability** — Trace an unbroken path from an attacker-controlled entry point
   (HTTP param, header, uploaded file, queue message, webhook body) to the sink. If any
   hop requires a trust boundary the attacker can't cross, downgrade to false-positive.
2. **Binding** — For access-control findings, prove the resource is NOT bound to the
   caller. An endpoint that looks like IDOR but re-derives the owner from the session is
   safe. Compare the vulnerable request against the owner's own request.
3. **Prove the negative** — State what the *corrected* request looks like and confirm the
   code path would reject it. If you can't articulate the rejection, you haven't confirmed
   the vuln — you've pattern-matched a shape.

**Silent-enforcement trap:** an empty array / 404 / null for another user's resource is
often enforcement working, not exposure. Verify against the owner's view before flagging.

---

## Per-Class Heuristics

### IDOR / Broken Object-Level Authorization
- **Look for:** object references (`/orders/{id}`, `?user_id=`, GUIDs) used to fetch/mutate
  without an ownership check bound to the authenticated principal.
- **Non-obvious:** batch/bulk endpoints often validate only the *first* element of an array
  and trust the rest. Check every element is authorized, not just `items[0]`.
- **Prove negative:** swap the id to another tenant's — does the query re-scope by
  `WHERE owner = session.user`? If yes → false-positive.
- **FP catalog:** IDs that are random+unguessable are defense-in-depth, not authorization —
  still flag, but lower severity if a real authz check also exists.

### Broken Function-Level Authorization / Privilege Escalation
- **Look for:** admin/privileged routes gated only by UI hiding or a client-sent role flag.
- **Non-obvious:** role checks at a top-level gateway but NOT re-checked at the handler;
  mass-assignment of a `role`/`is_admin` field through an update endpoint.
- **Prove negative:** confirm the server re-derives privilege from server-side session, not
  from any request-supplied value.

### SQL / NoSQL / Command / LDAP Injection
- **Look for:** user input concatenated into a query/command string; `shell=True`; ORM
  `.raw()`/`.extra()`; template-built queries.
- **Non-obvious:** second-order injection — input stored safely, then later read and
  concatenated into a query without re-escaping. Parameterization at the *first* write does
  not protect the *later* read.
- **Prove negative:** is the sink a parameterized/prepared statement with the input as a
  bound value (not string-built)? Bound → false-positive.
- **FP catalog:** allowlisted enum inputs, integer-cast inputs before the sink.

### SSRF (Server-Side Request Forgery)
- **Look for:** user-controlled URL/host/port fed to an HTTP client, image fetcher, webhook
  sender, PDF/screenshot renderer, or file loader.
- **Non-obvious:** redirect-following clients bypass allowlists (allowlisted host 302s to
  `169.254.169.254`); DNS rebinding; `file://`/`gopher://` scheme abuse.
- **Prove negative:** confirm the URL is validated *after* DNS resolution and redirects are
  disabled or re-validated, and the scheme is allowlisted.

### SSTI (Server-Side Template Injection)
- **Look for:** user input rendered *as* a template (not passed as a template variable) —
  `render_template_string(user_input)`, Jinja/Handlebars/Freemarker fed attacker text.
- **Prove negative:** input passed as a *context value* to a static template is safe; input
  used as the template *source* is the vuln.

### XXE / Unsafe Deserialization
- **Look for:** XML parsers with external entities enabled; `pickle.loads`, `yaml.load`
  (non-safe), Java/PHP native deserialization on attacker bytes.
- **Prove negative:** parser configured to disable DTD/external entities; deserializer is a
  safe/typed loader → false-positive.

### GraphQL-Specific
- **Non-obvious:** authorization must bind at the **resolver** boundary, not just the
  top-level query gate — a nested field resolver can leak data the top gate approved the
  parent for. Introspection enabled + field-level authz gaps = enumeration.
- **Look for:** unbounded query depth/aliasing (DoS), batching that multiplies an
  unauthorized resolver.

### Race Conditions / TOCTOU
- **Look for:** check-then-act on shared state without a lock/transaction — balance checks,
  coupon redemption, one-time tokens, file existence checks before write.
- **Non-obvious:** the exploit window is between validate and commit; single-request logic
  looks correct. Ask "what if two of these run concurrently?"
- **Prove negative:** atomic DB constraint / `SELECT ... FOR UPDATE` / idempotency key
  present → false-positive.

### Secrets & Auth Handling
- **Look for:** hardcoded credentials/API keys/tokens in source; JWTs with `alg:none` or
  unverified signature; session fixation; missing rotation.
- **FP catalog:** obvious test/placeholder values, public keys, example configs — verify
  before flagging a "secret."

### Path Traversal / File Upload
- **Look for:** user-controlled path segments joined to a base dir; upload filenames used
  verbatim; content-type trusted from the client.
- **Prove negative:** `realpath` + prefix-containment check after normalization → safe.
  Extension allowlist AND content sniffing → safe.

---

## Scope Note for Whitebox Passes

Prioritize cheap static reasoning first (grep for sinks, read the auth middleware once)
before deep manual review of any single finding. Rank the attack surface by
reachability × impact before spending review budget — a low-reachability critical often
ranks below a high-reachability high.
