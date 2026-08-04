---
name: impeccable-audit
description: Frontend visual design quality auditor. Applies Impeccable's 27 deterministic anti-pattern rules + 7-domain design principles to catch AI-generated UI fingerprints, accessibility violations, and visual quality issues. Use when reviewing, polishing, or critiquing any UI component, page, or design system code.
metadata:
  model: sonnet
source: https://github.com/pbakaus/impeccable
---

## Use this skill when

- Reviewing or auditing frontend UI code (React, Vue, Svelte, HTML/CSS)
- About to write or has just written UI components
- User asks for design critique, polish, or visual quality review
- Catching "AI-generated look" anti-patterns before shipping

## Do not use this skill when

- Reviewing backend or non-visual code
- Reviewing software architecture (use `/kiro:validate-design` instead)
- Checking spec-to-implementation alignment (use `/kiro:validate-impl`)

---

## Audit Domains

Run through all 7 domains. Flag every violation — no silent passes.

### 1. Typography

**Deterministic rules:**
- Body font size ≥ 14px (16px preferred)
- Body line-height ≥ 1.5 (1.6 preferred)
- Maximum 2 font families on any page
- No system fonts (`-apple-system`, `Segoe UI`) as display/accent — body use is fine
- No all-caps body text blocks
- Heading hierarchy must be logical (h1 → h2 → h3, no skips)
- Display fonts: prefer italic serif; body: clean sans-serif

**LLM critique:** Does the type scale create clear visual hierarchy? Is display text used only at true display size?

---

### 2. Color & Contrast

**Deterministic rules:**
- Color contrast ≥ 4.5:1 for normal text (WCAG AA)
- Color contrast ≥ 3:1 for large text / UI components
- No gray text on colored backgrounds (always fails contrast)
- Maximum 1 accent color (≤10% of screen real estate)
- No pure white (`#ffffff`) backgrounds — use warm off-white (e.g. `#fafaf8`, `#f9f6f1`)
- No multiple competing accent colors

**LLM critique:** Is the palette harmonious? Does color guide attention correctly?

---

### 3. Spatial Design

**Deterministic rules:**
- No nested cards (card inside card creates visual claustrophobia)
- No identical card grids (3-column grids of same-size cards = AI fingerprint)
- Shadow opacity ≤ 0.15 (flat surfaces; heavy shadows = dated)
- Border radius ≤ 8px for containers/cards (sharp, editorial; not pill-shaped)
- Consistent spacing scale (4px/8px grid — avoid arbitrary values like 13px, 17px)

**LLM critique:** Does negative space breathe? Does layout density match content importance?

---

### 4. Motion Design

**Deterministic rules:**
- No `ease-in` or `ease-out` easing — use `cubic-bezier` or `ease-in-out`
- Micro-interaction duration: 100–200ms (hover, focus states)
- Page transitions: 200–350ms
- No animation duration > 400ms for micro-interactions
- Hover transitions ≤ 200ms (sluggish = poor feel)
- `prefers-reduced-motion` must be respected

**LLM critique:** Does motion reinforce the user action? Does it feel responsive or laggy?

---

### 5. Interaction Design

**Deterministic rules:**
- All interactive elements must have visible focus states (`:focus-visible`)
- Icon-only buttons must have `aria-label` or `title`
- No missing hover states on clickable elements
- Loading states required for async operations
- Empty states required for list/table components
- Error messages must be specific (not "An error occurred")

**LLM critique:** Is interaction feedback immediate? Are all states (hover, active, disabled, loading, empty, error) designed?

---

### 6. Responsive Design

**Deterministic rules:**
- No fixed widths that break at mobile (< 375px)
- Touch targets ≥ 44×44px on mobile
- No horizontal scroll on mobile viewport
- Font sizes must not be fixed px on mobile (use rem or clamp)

**LLM critique:** Do breakpoints feel natural? Does the layout adapt gracefully or just shrink?

---

### 7. UX Writing

**Deterministic rules:**
- No filler text ("Lorem ipsum") in any component
- Button labels must be verbs ("Save", not "Submit Form Button")
- Error messages must tell user what to do, not just what failed
- Empty state copy must guide the user to the next action

**LLM critique:** Is microcopy clear and friendly? Does it match the product's tone?

---

## AI Design Fingerprints (Always Flag)

These patterns reliably mark AI-generated UIs. Flag any present:

| Pattern | Code signature | Why it's a problem |
|---|---|---|
| Gradient text | `background-clip: text; -webkit-background-clip: text` | Overused AI aesthetic, poor readability |
| Glassmorphism | `backdrop-filter: blur(Xpx)` + semi-transparent bg | Dated, accessibility issues |
| Colored left border | `border-left: 4px solid var(--accent)` | AI "card accent" pattern — visual noise |
| Gradient hero/card bg | `background: linear-gradient(...)` on full sections | Dated, competes with content |
| Nested cards | `<Card>` inside `<Card>` | Claustrophobic, spatial hierarchy collapse |
| Identical card grid | 3-col grid, same height, same padding, same structure | Template look — zero design intention |
| Pure white bg | `background: #ffffff` or `background: white` | Harsh, clinical, not editorial |

---

## Output Format

```
## Design Audit: [Component/File Name]

### AI Fingerprints Found
[List each fingerprint with file:line reference, or "None detected"]

### Deterministic Violations
[List each violation as: ❌ Rule — Location — Fix]

### LLM Observations
[2-4 sentences on overall visual quality, hierarchy, and feel]

### Verdict
PASS / NEEDS WORK / BLOCK
[One sentence justification]

### Recommended Fixes
[Prioritized list — critical first]
```

Flag everything. Do not soften findings. A "PASS" means zero violations, not "mostly fine."
