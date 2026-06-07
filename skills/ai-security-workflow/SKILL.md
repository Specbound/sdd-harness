---
name: ai-security-workflow
description: 5-phase interactive security workflow for finding and fixing real vulnerabilities: threat-model → vuln-scan → triage → patch → close. Produces standardized artifacts that feed each subsequent phase.
---

## When to Activate

- User says "do a security pass", "security review", "find vulnerabilities", "security audit this codebase"
- User asks to run `/kiro:security-report` interactively
- Phase gate: starting any phase in the pipeline (user references "threat model", "triage findings", "patch vulns")

## Do Not Activate

- For one-off SAST tool questions (use `security-scanning-security-sast`)
- For compliance audits (use `security-compliance-compliance-check`)
- For a single-file code review (use `code-review`)
- For the daily automated safety scan (that runs headlessly via `security-report-runner.sh`)

---

## Phase 1: Threat Model

**Goal:** Understand what's worth attacking before writing a single line of scan config.

**Inputs:** Codebase, any existing docs  
**Output:** `THREAT_MODEL.md` at repo root

**Steps:**

1. Interview the user with these questions (ask all at once, wait for answers):
   - What assets does this system protect? (data, money, availability, reputation)
   - Who are realistic attackers? (external internet, authenticated users, internal employees, supply chain)
   - What are the highest-value entry points? (auth endpoints, file uploads, payment flows, admin APIs, third-party integrations)
   - What's the blast radius of a breach? (PII count, financial exposure, SLA impact)

2. Read the codebase structure — focus on: entry points, auth flows, data stores, third-party calls, file I/O.

3. Write `THREAT_MODEL.md`:
   ```markdown
   # Threat Model — <repo name>

   ## Assets
   - [asset]: [what happens if compromised]

   ## Attacker Profiles
   - [profile]: [motivation, access level, likely TTPs]

   ## Attack Surface (ranked by risk)
   | Area | Entry Points | Risk | Notes |
   |------|-------------|------|-------|

   ## Out of Scope
   - [explicitly excluded areas]
   ```

4. Show threat model to user. **Wait for approval before Phase 2.**

---

## Phase 2: Vuln Scan

**Goal:** Find real candidates — not tool noise — in the highest-risk areas from Phase 1.

**Inputs:** `THREAT_MODEL.md`  
**Output:** `VULN-FINDINGS.json`

**Steps:**

1. Read `THREAT_MODEL.md` attack surface table. Focus analysis on top-ranked areas only.

2. For each high-risk area, read the relevant source files and reason about:
   - **Injection:** SQL, command, template, LDAP, path traversal in user-controlled inputs
   - **Auth/Authz:** Missing checks, broken session handling, JWT/token issues, IDOR
   - **Secrets:** Hardcoded credentials, API keys in source, insecure env handling
   - **Deserialization:** Unsafe object loading from user input
   - **SSRF/RFI:** User-controlled URLs fed to HTTP clients or file loaders
   - **Logic flaws:** Race conditions, TOCTOU, integer overflow in business logic

3. Write `VULN-FINDINGS.json`:
   ```json
   {
     "scan_date": "YYYY-MM-DD",
     "threat_model_version": "1",
     "findings": [
       {
         "id": "F001",
         "title": "SQL injection in user search",
         "severity": "critical|high|medium|low|info",
         "file": "path/to/file.py",
         "line": 42,
         "description": "...",
         "attack_vector": "HTTP GET /api/users?name=...",
         "impact": "...",
         "confidence": "high|medium|low"
       }
     ]
   }
   ```

4. Show findings summary (table: ID, title, severity, file:line). **Wait for user to proceed to Phase 3.**

---

## Phase 3: Triage

**Goal:** Verify findings are real, remove duplicates, rank by exploitability.

**Inputs:** `VULN-FINDINGS.json`  
**Output:** `TRIAGE.json`

**Steps:**

1. For each finding in `VULN-FINDINGS.json`:
   - Re-read the code at the reported location
   - Check: is the vulnerable path actually reachable from an attacker-controlled entry point?
   - Check: are there any mitigations in place (WAF rule, upstream sanitization, auth guard)?
   - Classify: `confirmed` / `false-positive` / `needs-more-info`

2. Deduplicate: if two findings are the same root cause in different callsites, merge them.

3. Rank by exploitability score (1-10): reachability × impact × ease of exploitation.

4. Write `TRIAGE.json`:
   ```json
   {
     "triage_date": "YYYY-MM-DD",
     "items": [
       {
         "finding_id": "F001",
         "status": "confirmed|false-positive|needs-more-info",
         "exploitability_score": 8,
         "reachable": true,
         "mitigations_present": false,
         "priority": "P0|P1|P2|P3",
         "notes": "..."
       }
     ]
   }
   ```

5. Show triage table sorted by exploitability. **Wait for user to confirm what to patch.**

---

## Phase 4: Patch

**Goal:** Generate verified fixes for confirmed findings, highest priority first.

**Inputs:** `TRIAGE.json`, `VULN-FINDINGS.json`, source files  
**Output:** Fixed code + `PATCHES/` directory

**Steps:**

1. For each `confirmed` finding (in priority order):

   a. Read the vulnerable code
   
   b. Generate a minimal fix — prefer the least invasive change that eliminates the vulnerability:
      - SQL injection → parameterized query
      - Command injection → allowlist + no shell=True
      - Path traversal → `os.path.realpath` + prefix check
      - Hardcoded secret → env var reference
      - Missing auth check → decorator/middleware addition

   c. Write the fix directly to the source file.
   
   d. Write a patch record to `PATCHES/<finding-id>.md`:
      ```markdown
      # Patch: <finding-id> — <title>
      
      **Severity:** <severity>  
      **File:** <path>:<line>
      
      ## What was wrong
      [description]
      
      ## Fix applied
      [what changed and why]
      
      ## Verification
      - [ ] Vulnerable code path no longer reachable
      - [ ] Existing tests still pass
      - [ ] No regression in related functionality
      ```

2. After each patch, note any assumptions or remaining risk in the patch record.

3. Show patch summary. **Wait for user review before Phase 5.**

---

## Phase 5: Close

**Goal:** Document outcomes, mark deferred items, update threat model.

**Inputs:** `TRIAGE.json`, `PATCHES/`  
**Output:** Updated `THREAT_MODEL.md`, `SECURITY-REPORT.md`

**Steps:**

1. Write `SECURITY-REPORT.md` at repo root:
   ```markdown
   # Security Report — <date>

   ## Summary
   - Total findings: N
   - Fixed (this session): N
   - Deferred: N
   - False positives: N

   ## Fixed
   | Finding | Severity | Fix Summary |
   
   ## Deferred (with rationale)
   | Finding | Severity | Why deferred | Owner | Target date |

   ## Recommendations
   [Any systemic issues that need longer-term attention]
   ```

2. Update `THREAT_MODEL.md`: add a `## History` section noting the review date and outcomes.

3. If any deferred P0/P1 items exist, create GitHub issues for them (ask user for permission first).

4. Confirm with user: "Security workflow complete. N issues fixed, M deferred. Report at SECURITY-REPORT.md."

---

## Artifact Reference

| Artifact | Phase produced | Next phase consumes |
|----------|---------------|---------------------|
| `THREAT_MODEL.md` | 1 | 2 (focus areas), 5 (history) |
| `VULN-FINDINGS.json` | 2 | 3 (triage input) |
| `TRIAGE.json` | 3 | 4 (patch targets) |
| `PATCHES/<id>.md` | 4 | 5 (close record) |
| `SECURITY-REPORT.md` | 5 | — |

## Resume a Paused Workflow

If artifacts already exist, start from the right phase:
- `THREAT_MODEL.md` exists, no findings → Phase 2
- `VULN-FINDINGS.json` exists, no triage → Phase 3
- `TRIAGE.json` exists, patches missing → Phase 4
- Patches exist, no report → Phase 5
