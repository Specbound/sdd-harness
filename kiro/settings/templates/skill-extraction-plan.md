# Skill Extraction Plan: {{REPO_NAME}}

**Generated**: {{TIMESTAMP}}
**Source**: {{REPO_URL_OR_PATH}}

---

## Repository Summary

- **Type**: {{REPO_TYPE}} (library / framework / CLI tool / web app / data pipeline / ML project / agent system)
- **Primary Language**: {{LANGUAGE}}
- **Key Dependencies**: {{KEY_DEPS}}
- **Structure**: {{STRUCTURE_SUMMARY}}
- **Documentation Quality**: {{DOC_QUALITY}} (none / minimal / moderate / comprehensive)

## Candidate Skills

{{CANDIDATE_COUNT}} candidates identified (threshold: score >= 6/12).

| Rank | Name | Source Module | Score | Risk | Rationale |
|------|------|--------------|-------|------|-----------|
| {{RANK}} | {{SKILL_NAME}} | {{SOURCE_PATH}} | {{SCORE}}/12 | {{RISK}} | {{ONE_LINE_RATIONALE}} |

### Candidate Details

#### {{RANK}}. {{SKILL_NAME}} (Score: {{SCORE}}/12)

- **Source**: `{{SOURCE_PATH}}`
- **Scoring Breakdown**:
  - Recurrence: {{0-3}} — {{reason}}
  - Code Quality: {{0-3}} — {{reason}}
  - Domain Expertise: {{0-3}} — {{reason}}
  - Generalizability: {{0-3}} — {{reason}}
  - Modifiers: {{list applied modifiers}}
- **What it teaches**: {{DESCRIPTION}}
- **Risk level**: {{safe / unknown / caution}}
- **Existing overlap**: {{none / partial with SKILL_NAME}}
- **Recommended action**: {{extract / skip / merge with existing}}

_Repeat for each candidate._

## Relationship Map

Connections between extracted candidates and existing skills:

- {{SKILL_A}} → requires → {{SKILL_B}}
- {{SKILL_A}} → extends → {{EXISTING_SKILL}}
- {{SKILL_A}} → subset-of → {{EXISTING_SKILL}}

## Recommendations

- {{Key recommendations about which candidates to prioritize}}
- {{Any candidates that should be merged into a single skill}}
- {{Suggestions for skill naming to fit the existing ecosystem}}

## Next Step

Review this plan, remove or edit candidates you don't want, then run:
```
/kiro:skill-extract <path-to-this-plan>
```
