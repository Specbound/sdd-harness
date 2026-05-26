# SonarQube Security Hotspot Triage Report

**Generated:** 2026-03-30
**Project:** INT__aiq-zora-agent-skills
**Branch:** main
**Total hotspots reviewed:** 3
**Summary:** 0 require action - 2 accepted - 1 false positive - 0 need investigation

---

## Summary Table

| # | File | Line | Rule | Category | Verdict |
|---|------|------|------|----------|---------|
| 1 | constants.py | 264 | python:S5852 | DoS (ReDoS) | ACCEPTED RISK |
| 2 | skeletons.py | 82 | python:S5852 | DoS (ReDoS) | FALSE POSITIVE |
| 3 | skeletons.py | 512 | python:S5852 | DoS (ReDoS) | ACCEPTED RISK |

---

## Detailed Findings

### Hotspot 1 — ReDoS in `constants.py:264`

**SonarQube Rule:** `python:S5852` — Regular expressions vulnerable to polynomial runtime due to backtracking
**Security Category:** Denial of Service
**Vulnerability Probability:** Medium
**Verdict:** ACCEPTED RISK

**Flagged code:**
```python
# line 264
_EXTRACT_RE = re.compile(
    r"^EXTRACT\s*\(\s*\w+\s+FROM\s+(.+)\)$", re.IGNORECASE
)
```

**Context:**
This regex is used in `_unwrap_extract()` to detect whether a column argument is already wrapped in a SQL `EXTRACT(... FROM ...)` expression. The `(.+)` capture group at the end is what Sonar flags — in theory, backtracking between `(.+)` and the trailing `\)$` could cause polynomial time on adversarial input.

**Why the risk is low:**
- **Input source:** The `col` argument comes from the LLM-generated SQL template parameters (column names like `opportunity_close_date`), not from raw end-user HTTP input. The LLM output is schema-constrained and validated upstream.
- **Input size:** Column names are short strings (typically under 50 characters). ReDoS is only practically exploitable with long, crafted inputs (hundreds+ of characters).
- **Anchored pattern:** The regex is anchored with `^...$`, which limits the backtracking surface significantly compared to unanchored patterns.
- **Internal utility:** This function is called within the SQL generation pipeline, not on any public-facing endpoint.

**Recommendation:** Accept. The theoretical ReDoS risk is negligible given input constraints. If desired, the pattern could be tightened by replacing `(.+)` with `([^)]+)` to eliminate backtracking entirely, but this is a low-priority optimization.

---

### Hotspot 2 — ReDoS in `skeletons.py:82`

**SonarQube Rule:** `python:S5852` — Regular expressions vulnerable to polynomial runtime due to backtracking
**Security Category:** Denial of Service
**Vulnerability Probability:** Medium
**Verdict:** FALSE POSITIVE

**Flagged code:**
```python
# line 82
order_cols = [
    re.sub(r'\s+(ASC|DESC)\s*$', '', c.strip(), flags=re.IGNORECASE)
    for c in order_by.split(",")
]
```

**Context:**
This regex strips trailing `ASC` or `DESC` keywords from ORDER BY clause columns in `_auto_extend_group_by()`. The function ensures that ORDER BY columns are included in the GROUP BY clause to prevent PostgreSQL GroupingErrors.

**Why this is not a risk:**
- **No backtracking vulnerability:** The pattern `\s+(ASC|DESC)\s*$` is a simple alternation anchored at end-of-string. There are no nested quantifiers or overlapping groups that could cause exponential backtracking. The `\s+` and `\s*` quantifiers are separated by a fixed alternation — this is a linear-time match.
- **Input source:** The `order_by` value comes from the LLM template output (SQL column names with optional sort direction), not from raw user input.
- **Input size:** Individual ORDER BY terms are short SQL identifiers.

**Recommendation:** No action needed. This is a false positive — the regex has no backtracking vulnerability. Sonar likely flagged it heuristically due to the presence of `\s+` followed by `\s*`, but the fixed `(ASC|DESC)` alternation between them prevents any problematic backtracking.

---

### Hotspot 3 — ReDoS in `skeletons.py:512`

**SonarQube Rule:** `python:S5852` — Regular expressions vulnerable to polynomial runtime due to backtracking
**Security Category:** Denial of Service
**Vulnerability Probability:** Medium
**Verdict:** ACCEPTED RISK

**Flagged code:**
```python
# line 512
_ob_terms = [
    t for t in _ob_terms
    if re.sub(r"\s+(ASC|DESC)$", "", t, flags=re.IGNORECASE).strip() != grain_col
]
```

**Context:**
This regex is nearly identical to Hotspot 2 — it strips `ASC`/`DESC` from ORDER BY terms, this time in the `_skeleton_comparison()` function. The purpose is to remove the grain column from ORDER BY after pivoting, since the grain column no longer exists in the outer GROUP BY.

**Why the risk is low:**
- **Same pattern analysis as Hotspot 2:** `\s+(ASC|DESC)$` is a simple, linear-time pattern with no nested quantifiers. The backtracking risk is theoretical at best.
- **Input source:** Same LLM-generated SQL template parameters, not raw user input.
- **Difference from Hotspot 2:** This version uses `$` anchor without trailing `\s*`, making it even simpler. Sonar flags it for the same heuristic reason.

**Recommendation:** Accept. The regex is safe. The only difference from Hotspot 2 is that this uses `re.sub()` inline in a list comprehension rather than in a dedicated variable — functionally identical. No change needed.

---

## Action Items

| Priority | File | Line | What to do |
|----------|------|------|------------|
| LOW | constants.py | 264 | *Optional:* Replace `(.+)` with `([^)]+)` in `_EXTRACT_RE` to eliminate any theoretical backtracking. Not urgent. |

---

## Notes

- All three hotspots are the same rule (python:S5852 — ReDoS) and all relate to regex patterns used in internal SQL template generation utilities.
- None of these patterns process raw end-user input — they operate on LLM-generated, schema-constrained SQL fragments.
- The actual ReDoS risk across all three is negligible: inputs are short, patterns are anchored, and there are no nested quantifiers that would cause exponential blowup.
- Hotspots marked ACCEPTED RISK should be re-evaluated if the template tool is ever exposed to direct user input (e.g., a public API that accepts arbitrary SQL column names).
