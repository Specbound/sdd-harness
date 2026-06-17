---
name: ui-skills
description: Use BEFORE any UI/frontend build, redesign, or review to route to the smallest useful set (1-3, never more) of the harness's UI skills by category, stack, and intent.
source: https://github.com/ibelick/ui-skills (https://www.ui-skills.com/)
risk: safe
metadata:
  adapted_from: ibelick/ui-skills "UI Skills Root"
  version: "2.0.0"
---

# UI Skills — Build Router

You are the routing layer for UI work. This skill does NOT contain UI guidance itself — it
selects which of the harness's existing UI skills to load, and how many. Its job is to stop
the two failure modes that hurt UI tasks in a large skill library: the *wrong* skill firing,
and *too many* overlapping skills loading at once and rotting context.

## When to Activate

Use when the task is UI/frontend-shaped AND the right skill is ambiguous:
- "build / redesign / polish a page, component, dashboard, landing"
- "review this UI", "audit accessibility", "make it feel better", "fix the motion"
- any frontend work where 2+ UI skills below could plausibly fire

## When NOT to Activate

- Non-UI work (backend, data, infra) — return immediately, route nothing.
- The task already names one specific skill or surface unambiguously (e.g. "run wcag-audit-patterns") — just invoke it, skip routing.
- Pure logic/state with no interface concern.

## Protocol

1. Confirm the task is UI-related. If not → return, route nothing.
2. If the goal is unclear, ask ONE short question (surface? stack? build vs review?).
3. Identify the category from the map below.
4. Select the **smallest useful** skill set (selection rules below).
5. Invoke ONLY the selected skill(s) via `Skill("<name>")`.
6. Implement using that context. Do not pre-load skills "just in case."

## Selection Rules (context economy — the core discipline)

- **Prefer 1 skill.** One sharp skill beats three blurry ones.
- **Use 2** only when the task genuinely needs two distinct angles (e.g. build + a11y).
- **Use 3** only for broad review, full redesign, or multi-surface work.
- **Never load more than 3.** More than 3 overlapping UI skills rots context and degrades coherence.
- When two skills overlap, pick the more specific one for the named stack/surface.

## Category → Harness Skill Map

Route to these existing harness skills (invoke with `Skill(...)`). Do not duplicate them here.

| Category | Primary skill(s) | Use when |
|---|---|---|
| **Design taste / visual quality** | `ui-ux-pro-max`, `frontend-design`, `web-design-guidelines` | high-end look, layout, spacing, color, "make it feel premium" |
| **UX / interaction design** | `ui-ux-designer`, `frontend-developer` | flows, IA, interaction patterns, role-level design judgment |
| **React** | `react-best-practices`, `react-patterns`, `react-ui-patterns` | React component build/refactor |
| **Next.js** | `nextjs-best-practices`, `nextjs-app-router-patterns` | Next app/router work |
| **Vue / Nuxt** | `vue`, `angular` (per stack) | Vue/Angular stack work |
| **Styling system** | `tailwind-design-system`, `tailwind-patterns`, `radix-ui-design-system`, `theme-factory` | design tokens, Tailwind, component primitives, theming |
| **Mobile** | `mobile-design`, `react-native-architecture` | mobile/native UI |
| **Accessibility** | `wcag-audit-patterns`, `accessibility-compliance-accessibility-audit`, `screen-reader-testing` | a11y build or audit |
| **3D / canvas / shaders** | `threejs-skills`, `3d-web-experience`, `shader-programming-glsl`, `canvas-design`, `algorithmic-art` | WebGL, Three.js, generative/canvas |
| **Motion / scroll** | `scroll-experience`, `remotion-best-practices` | scroll-driven, video/motion |
| **Performance** | `frontend-performance`, `web-performance-optimization` | UI perf, Core Web Vitals |
| **Slides / presentation** | `frontend-slides` | slide decks, presentation UI |
| **Review / verify** | `frontend-code-quality`, `ui-visual-validator` | post-build UI review and visual validation |

## Worked Examples

- "Build a pricing page in Next + Tailwind, make it look premium" → `nextjs-best-practices` + `ui-ux-pro-max` (2 angles: stack + taste). Stop at 2.
- "Audit this component for accessibility" → `wcag-audit-patterns` only (1).
- "Full redesign review of our dashboard" → broad review: `ui-ux-pro-max` + `frontend-code-quality` + `wcag-audit-patterns` (3, the ceiling).
- "Add a Three.js hero animation" → `threejs-skills` only (1); add `frontend-performance` only if perf is raised.

## Notes

- This router supersedes the previous hollow `ui-skills` stub. It carries no UI rules of its own — all guidance lives in the mapped skills.
- Adapted from ibelick's "UI Skills Root" routing pattern; the original routes via a `ui-skills`
  CLI/registry. This version routes via the harness Skill tool instead — no CLI needed.
