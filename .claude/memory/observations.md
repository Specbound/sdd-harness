<!-- L0: Append-only session log — decisions, insights, friction, patterns -->

# Observations

<!-- Format: - YYYY-MM-DD [tag1, tag2]: observation text -->
<!-- Tags: spec, impl, design, debug, decision, friction, insight, pattern -->
<!-- Rules: append-only, max 5 new entries per /kiro:reflect, archive at 50 entries -->

- 2026-05-27 [judge]: Window 2026-05-26T00:00Z..2026-05-27T00:00Z — no session observations found. Fresh harness install with no prior activity. Charges: 0, Drains: 0. Score delta: 0.0. "No session history to evaluate — harness is newly initialized."
- 2026-05-27 [session-quality]: Score=3/5 — No session activity today; fresh harness with no commits or observable signals in the evaluation window.
- 2026-05-27 [keep-rate]: skipped — git log unavailable (RTK PreToolUse hook blocks Bash commands; cannot compute line-survival rate). No Claude-co-authored commits confirmed older than 7 days from available context.
- 2026-05-27 [skill, insight]: Extracted `frontend-performance` skill from Linear performance breakdown article. Covers local-first architecture, optimistic updates, bundle strategy (modulepreload, modern-browser targeting), animation rules (composited-only, ≤150ms), and granular MobX observables. Stored at `~/.claude/skills/frontend-performance/SKILL.md`.
- 2026-05-27 [revert]: git-revert — `python3 << 'PYEOF' with open('/Users/dansasha/Documents/sdd-harness/.claude/docs`
- 2026-05-28 [judge]: Window 2026-05-27T00:00Z..2026-05-28T00:00Z — skill extraction activity with no manual charges/drains. Auto-scored signals only. Charges: 0, Drains: 0. Score delta: 0.0.
- 2026-05-28 [session-quality]: Score=3/5 — No commits today; Judge found 0 charges/0 drains. Neutral baseline session.
- 2026-05-28 [keep-rate]: ~95% (8 Claude co-authored commits ≥7d old sampled; blame survival approx 2627/2395 lines, capped). Trend: high retention. No low-keep-rate flag.
- 2026-05-31 [judge]: Window 2026-05-30T00:00Z..2026-05-31T00:00Z — one commit (a53489e "updated skills"), no session observations in window. Charges: 0, Drains: 0, memory-gaps: 0. Score delta: 0.0. "Quiet maintenance-only day; skills bump committed with no observable charges or drains."
- 2026-05-31 [session-quality]: Score=3/5 — One constructive commit (a53489e: +skill-extraction SKILL.md, docs/ reorg into sources/, 121 insertions). No reverts, no file churn, no rework cycles. Judge found 0 charges/0 drains. Neutral-constructive maintenance day, no user-approval signals.
- 2026-05-31 [keep-rate]: 65.7% (2951 surviving / 4489 added; 14 Claude co-authored commits ≥7d old, blame-based on 18 surviving files). Trend: ▼ vs 05-28's ~95% rough estimate — but that was capped/approximate; this is rigorous blame survival. Moderate retention; below 80% charge threshold but expected given heavy memory/docs churn by design. No low-keep-rate alarm.
- 2026-05-31 [friction, routine-error]: trust_score.py uses PEP 604 `float | None` syntax (needs Python 3.10+), but `/usr/bin/python3` on this machine is 3.9.6 — the script crashes with TypeError before running. The nightly routine invokes bare `python3`, so unattended runs would silently fail the auto-score step. Today's run worked only because I fell back to python3.13. Fix: pin the routine/script shebang to python3.11+ or add `from __future__ import annotations`.
