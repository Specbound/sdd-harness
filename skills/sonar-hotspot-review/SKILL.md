---
name: sonar-hotspot-review
description: "Fetches open SonarQube Security Hotspots AND Code Quality Issues, traces each back to its source in the repo, and produces a markdown triage report explaining which items require action and why. Also posts review comments to SonarQube."
source: personal
risk: safe
domain: security
category: analysis
version: 1.2.0
---

# SonarQube Security Hotspot & Issue Review

## Purpose

Retrieve all open Security Hotspots **and** Code Quality Issues from SonarQube, investigate each one in the codebase, and produce a triage report (`docs/security/sonar-hotspot-review.md`) that explains:
- What each item is flagging
- The actual code and its context
- Whether it is a **real risk** that needs fixing or a **false positive / accepted risk** with justification
- A recommended action (Fix / Accept / Investigate Further)

Post a short technical comment on each item in SonarQube after investigation.

## When to Use

- Team lead asks you to review SonarQube Hotspots or Issues
- Before a security review or audit
- When triaging Sonar results for a sprint or PR
- When onboarding new team members to the security posture of the repo

---

## Workflow

### Step 0 — Select Repository, Branch, and Context

**Before doing anything else**, determine the repository, branch, and whether a PR context applies:

1. **Which repository?** If the user specifies one, use it. Otherwise ask:
   - **engine** — `INT__aiq-zora-ai-engine` (SonarQube dashboard: `https://sonar.tools.deloitteinnovation.us/dashboard?id=INT__aiq-zora-ai-engine&codeScope=overall`)
   - **skills** — `INT__aiq-zora-agent-skills` (SonarQube dashboard: `https://sonar.tools.deloitteinnovation.us/dashboard?id=INT__aiq-zora-agent-skills&codeScope=overall`)

2. **PR or branch context?** Sonar scans branches, but CI may only post results on PRs:
   - If the user mentions a PR number, or if branch-context queries return no results, **use PR context** (`&pullRequest=${PR_NUMBER}`) instead of `&branch=${BRANCH}`.
   - To find the open PR number for the current git branch: `gh pr list --head $(git branch --show-current) --json number --jq '.[0].number'`
   - Always try PR context if branch context yields zero results.

3. **Which branch?** Default to development branches — do NOT default to `main`. Use this priority order:
   1. If the user explicitly specifies a branch, use that.
   2. Otherwise, **auto-detect**: query the SonarQube API for the project's branches and pick the first match from: `develop`, `dev`, `development`. If none exist, fall back to `main`.

   **Auto-detection API call:**
   ```bash
   curl -s -u "${TOKEN}:" \
     "${HOST}/api/project_branches/list?project=${PROJECT_KEY}" \
     | python3 -c "
   import sys, json
   data = json.load(sys.stdin)
   branches = [b['name'] for b in data.get('branches', [])]
   for candidate in ['develop', 'dev', 'development']:
       if candidate in branches:
           print(candidate)
           sys.exit(0)
   print('main')
   "
   ```

   Tell the user which branch/PR was selected so they can override if needed.

Use `${PROJECT_KEY}`, `${BRANCH}`, and `${PR_NUMBER}` (when applicable) throughout. When PR context is active, replace `&branch=${BRANCH}` with `&pullRequest=${PR_NUMBER}` in all API calls.

---

### Step 1 — Get SonarQube Credentials

Resolve the token and host in this priority order:

1. **MCP tools** — run `ToolSearch: "sonar hotspot"`. If Sonar MCP tools appear, use them and skip the REST API steps below.
2. **Environment variable** — check `$SONAR_TOKEN` and `$SONAR_HOST_URL`
3. **`.env` file** — `grep -i SONAR .env`
4. **VS Code MCP config** — `cat ~/.config/Code/User/mcp.json` (may contain `SONARQUBE_TOKEN` and `SONARQUBE_URL`)
5. **Ask the user** — "Please provide your SonarQube host URL and token."

For this project the known host is: `https://sonar.tools.deloitteinnovation.us`

Once you have the token, verify it works:
```bash
curl -s -u "${TOKEN}:" "${HOST}/api/system/status"
```

---

### Step 2 — Identify the Project Key

The project key was already determined in Step 0. Use the value selected by the user:

| Selection | Project Key |
|-----------|-------------|
| engine | `INT__aiq-zora-ai-engine` |
| skills | `INT__aiq-zora-agent-skills` |

If the user provided a different project, fall back to these discovery steps:
1. Check `sonar-project.properties` in the repo root
2. Check `.github/workflows/*.yml` for `sonar.projectKey` or `-Dsonar.projectKey`
3. Check `.env` or `.env.example` for `SONAR_PROJECT_KEY`
4. If not found, ask the user: "What is your SonarQube project key?"

---

### Step 3a — Fetch Open Security Hotspots

**If using MCP tools:** call the hotspot search tool with `status=TO_REVIEW`.

**If using REST API:**
```bash
curl -s -u "${TOKEN}:" \
  "${HOST}/api/hotspots/search?projectKey=${PROJECT_KEY}&branch=${BRANCH}&status=TO_REVIEW&ps=500" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('Total:', data.get('paging', {}).get('total', 'N/A'))
for h in data.get('hotspots', []):
    print('---')
    print('Key:', h.get('key'))
    print('File:', h.get('component'))
    print('Line:', h.get('line'))
    print('Rule:', h.get('ruleKey'))
    print('Message:', h.get('message'))
    print('Category:', h.get('securityCategory'))
    print('Probability:', h.get('vulnerabilityProbability'))
"
```

If using PR context: replace `&branch=${BRANCH}` with `&pullRequest=${PR_NUMBER}`.

If the project key returns "not found", search for it:
```bash
curl -s -u "${TOKEN}:" "${HOST}/api/components/search_projects?ps=500&q=<repo-name>" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); [print(p['key'],'|',p['name']) for p in d.get('components',[])]"
```

Store the raw hotspot list separately — you will process each item individually.

---

### Step 3b — Fetch Open Code Quality Issues

Fetch open Issues (Bugs, Vulnerabilities, Code Smells) in addition to Hotspots.

**If using REST API:**
```bash
curl -s -u "${TOKEN}:" \
  "${HOST}/api/issues/search?componentKeys=${PROJECT_KEY}&branch=${BRANCH}&statuses=OPEN,CONFIRMED&types=BUG,VULNERABILITY,CODE_SMELL&ps=500" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('Total:', data.get('paging', {}).get('total', 'N/A'))
for i in data.get('issues', []):
    print('---')
    print('Key:', i.get('key'))
    print('File:', i.get('component'))
    print('Line:', i.get('line'))
    print('Rule:', i.get('rule'))
    print('Message:', i.get('message'))
    print('Type:', i.get('type'))
    print('Severity:', i.get('severity'))
"
```

If using PR context: replace `&branch=${BRANCH}` with `&pullRequest=${PR_NUMBER}`.

> **Scope note:** On large projects the total issue count can be very high. When reviewing a specific PR or branch, prefer PR/branch context which limits results to new or changed code only. If the result set is large (>50), prioritize `BUG` and `VULNERABILITY` types first; triage `CODE_SMELL` issues that are in files touched by the current branch.

Store the raw issue list separately from hotspots.

---

### Step 4 — Investigate Each Item in the Repo

For **each hotspot AND each issue**, perform the following investigation:

#### 4a. Read the flagged code

Use the `Read` tool on the file at the flagged line. Read ±20 lines of context around it to understand the full scope.

#### 4b. Understand the surrounding context

Ask these questions by reading the code and related files:

1. **Exposure**: Is this code reachable from a public HTTP endpoint, or is it internal only (background job, admin route, CLI tool, unit test)?
2. **Data sensitivity**: Does it process user-supplied input, PII, credentials, or financial data?
3. **Existing mitigations**: Are there authentication decorators, input validation, rate limiting, or other controls already in place nearby?
4. **Intent**: Is the pattern intentional and safe for this use case (e.g. `random` used for a non-security purpose like shuffle, not token generation)?
5. **Scope**: Is this code even reachable in production, or is it a test/dev utility?
6. **For code quality issues (CODE_SMELL)**: Is the complexity/duplication a deliberate structural choice with a known plan to address it, or unintentional?

#### 4c. Classify the item

Assign one of these verdicts:

| Verdict | Meaning |
|---------|---------|
| **ACTION REQUIRED** | Genuine risk or quality problem, should be fixed now |
| **ACCEPTED RISK** | Known pattern, justified by context (internal use, existing controls, non-sensitive data) |
| **ACCEPTED — known structural debt** | Code quality issue (complexity, duplication) accepted with a planned refactor |
| **FALSE POSITIVE** | Sonar flagged something that is not actually a concern given context |
| **INVESTIGATE FURTHER** | Unclear — more domain knowledge needed |

---

### Step 5 — Write the Triage Report

Create (or overwrite) the file at: `docs/security/sonar-hotspot-review.md`

Use this exact structure:

```markdown
# SonarQube Issue Triage Report

**Generated:** YYYY-MM-DD
**Project:** <sonar-project-key>
**Pull Request / Branch:** #N — branch-name  (or just branch-name if no PR)
**Total issues reviewed:** N
**Summary:** X require action · Y accepted risk · Z false positives · W accepted complexity debt

---

## Summary Table

| # | File | Line | Rule | Category | Verdict |
|---|------|------|------|----------|---------|
| 1 | path/to/file.py | 42 | python:S2245 | Weak Cryptography | ACCEPTED RISK |
| 2 | path/to/file.py | 100 | python:S3776 | Cognitive Complexity | ACCEPTED — known structural debt |

---

## Detailed Findings

### Issue 1 — [Rule Name] in `path/to/file.py:42`

**SonarQube Rule:** `python:S2245` — Use of pseudorandom number generators
**Severity / Category:** Weak Cryptography
**Verdict:** ACCEPTED RISK

**Flagged code:**
```python
# line 42
result = random.shuffle(items)
```

**Context:**
This code shuffles a display list for UI randomization, not for any security-sensitive purpose (token generation, session IDs, cryptographic keys). The `random` module is appropriate here. The function is called only from the chart rendering layer and never handles credentials or PII.

**Why it is not a risk:**
- Not used for security-sensitive randomness (no tokens, no secrets)
- Internal rendering utility — not reachable from any public API
- No user-supplied input flows through this path

**Recommendation:** Accept. Add inline `# nosonar` comment with justification to suppress future flags.

---

## Action Items

| Priority | File | Line | What to do |
|----------|------|------|------------|
| HIGH | path/to/file.py | 100 | Replace `print()` with structured logger |
| LOW (deferred) | path/to/file.py | 472 | Follow-up: extract dispatch branches to reduce cognitive complexity |

---

## Notes

- Items marked ACCEPTED RISK should be reviewed again if the code's exposure level changes (e.g. if an internal route becomes public-facing)
- All ACTION REQUIRED items should be tracked in the issue tracker
```

---

### Step 6a — Post Comments on Security Hotspots

For **each hotspot** reviewed, post a short comment to its Activity tab. The comment must read like a human engineer wrote it — **never mention AI, automation, or that it was generated**.

The comment should be **2–4 sentences max** with this structure:
1. What the code does and why it's written this way (context)
2. Why the risk level is low/acceptable (or why it needs action)

**Do not include:** verdict labels (ACCEPTED RISK, FALSE POSITIVE), bullet lists, markdown headers, or any meta-commentary. Just plain, concise technical reasoning.

**API call:**
```bash
curl -s -X POST -u "${TOKEN}:" \
  "${HOST}/api/hotspots/add_comment" \
  -d "hotspot=${HOTSPOT_KEY}" \
  --data-urlencode "comment=${COMMENT_TEXT}"
```

If a comment fails (e.g. permissions error), log a warning and continue. Do not stop the workflow.

---

### Step 6b — Post Comments on Code Quality Issues

For **each issue** reviewed, post a short comment to its Activity tab using the Issues API.

Same comment format as Step 6a — 2–4 sentences, no verdict labels, no AI references.

**API call:**
```bash
curl -s -X POST -u "${TOKEN}:" \
  "${HOST}/api/issues/add_comment" \
  -d "issue=${ISSUE_KEY}" \
  --data-urlencode "text=${COMMENT_TEXT}"
```

Note the difference from hotspots: the parameter name is `issue` (not `hotspot`) and the comment body field is `text` (not `comment`).

If a comment fails, log a warning and continue.

---

### Step 7 — Output Summary to the User

After writing the file and posting comments, print a concise summary:

```
Sonar triage complete.

Report written to: docs/security/sonar-hotspot-review.md

Security Hotspots:
  ACTION REQUIRED      : N
  ACCEPTED RISK        : N
  FALSE POSITIVE       : N
  INVESTIGATE FURTHER  : N

Code Quality Issues:
  ACTION REQUIRED      : N
  ACCEPTED (debt)      : N
  FALSE POSITIVE       : N
  INVESTIGATE FURTHER  : N

Top priority items:
  1. [file:line] — [short reason]
  2. ...
```

---

## Key Analysis Heuristics

Use these to guide your verdicts:

### Likely ACCEPTED RISK (Security Hotspots)
- `random` / `Math.random()` used for non-security purposes (shuffling UI lists, sampling, test data generation)
- HTTP instead of HTTPS for internal service-to-service calls within a private network / k8s cluster
- `print()` / `console.log()` in dev utilities, CLI tools, or scripts — not in request handlers
- SQL queries built with string formatting when the values come from a controlled internal config, not user input
- Hardcoded credentials that are clearly placeholder/test values (e.g. `password = "test"` in a test file)

### Likely ACCEPTED — known structural debt (Code Quality Issues)
- High cognitive complexity (S3776) in a central dispatcher or router added intentionally to keep all routing logic in one traceable place during early development
- Duplication in test fixtures or generated code where deduplication would reduce readability
- Long methods in CLI or one-off scripts where linear readability is more important than abstraction

### Likely FALSE POSITIVE
- Sonar flags a deprecated API that is already being replaced in the same PR
- A cryptographic pattern flagged in test code that never runs in production
- An XSS pattern in server-side rendered content that is already escaped by the template engine

### Likely ACTION REQUIRED
- User-supplied data flows directly into a SQL query with no parameterization
- Credentials or secrets hardcoded in production source files (not test files)
- Sensitive data logged to stdout in a production request handler
- `random` used to generate session tokens, API keys, or security codes
- An endpoint that accepts file uploads without validating content type or size

---

## Output Location

Always write to: `docs/security/sonar-hotspot-review.md`

If the `docs/security/` directory does not exist, create it. Never output the report only to the terminal — always write the file.
