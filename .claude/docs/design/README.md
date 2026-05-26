# Design Quality Reference

Reference documentation for visual design quality integrations in the SDD harness.

| Integration | Source | Description |
|---|---|---|
| [Impeccable](impeccable/impeccable.md) | [github.com/pbakaus/impeccable](https://github.com/pbakaus/impeccable) | 27 deterministic anti-pattern rules + 7-domain visual design quality system. Catches AI design fingerprints in frontend code (gradient text, glassmorphism, nested cards, contrast failures, stale easing). |

## How Design Quality Fits in the Workflow

Design quality runs as a complementary layer alongside the spec validation pipeline:

```
spec-requirements → spec-design → /kiro:validate-design → spec-impl
                                         ↑
                              frontend-anti-patterns.md rules
                              (Impeccable's deterministic rules)

UI components → Write/Edit → impeccable-detect-hook (auto-scan)
                          → /impeccable-audit skill (on-demand review)
```

- **`/kiro:validate-design`** — software architecture review; references `frontend-anti-patterns.md` for UI deliverables
- **`/impeccable-audit`** skill — full 7-domain visual audit with PASS/NEEDS WORK/BLOCK verdict
- **`impeccable-detect-hook.sh`** — PostToolUse auto-scan on frontend file writes (requires `npm install -g impeccable`)
