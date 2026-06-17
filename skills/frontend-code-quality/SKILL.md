---
name: frontend-code-quality
description: Use when writing or reviewing HTML, CSS, or JavaScript — per-file code quality rules covering semantic HTML, CSS structural patterns, and JS idiomatic style. Pair with frontend-performance for full frontend coverage.
---

<skill_overview>
Code quality in frontend work is about writing correct, readable, and minimal code — not about premature optimization. These rules eliminate whole categories of subtle bugs (specificity wars, mutation side effects, layout thrash) by encoding the right default at the pattern level.
</skill_overview>

<rigidity_level>
MEDIUM RIGID — The HTML and CSS rules are close to absolute; follow them unless you have a documented reason not to. The JS idioms are guiding principles; adapt them to your codebase's style, but don't abandon them wholesale.
</rigidity_level>

**Also invoke:** `frontend-performance` when making architecture or data-flow decisions — these two skills cover complementary concerns.

---

## HTML

### Semantics
- Use semantic HTML5 elements (`<main>`, `<article>`, `<header>`, `<time>`, `<nav>`, etc.)
- Using a semantic element incorrectly is worse than using a neutral `<div>`
- Never wrap block-level semantic elements inappropriately (e.g. a `<figure>` inside an `<h1>`)

### Brevity
- Drop XHTML habits: no self-closing tags, no `type=text/javascript`, no `type=text/css`, no `charset` in meta http-equiv
- Boolean attributes need no value: `required` not `required=required`
- Omit redundant tags/attributes from HTML5 documents

### Accessibility
- `alt` text must describe content, not the element (`alt=Company`, not `alt=Logo`)
- Interactive elements must be actual buttons/links — no `<div class=button>` (a `<button>` gets keyboard events, focus, and ARIA role for free; a div needs all of it added back manually)
- Never rely exclusively on color to communicate information
- All form inputs must be explicitly labelled — link `<label for=X>` to `<input id=X>`; clicking the label must focus the field
- **Focus states**: never just `outline: none` — replace with a custom visible style; removing focus indicators is an accessibility failure
- **Touch targets**: minimum 44×44px tappable area — the visual element can be smaller, but the hit area must not be
- **DOM order**: don't reorder elements visually with CSS (e.g. `order`, `flex-direction: row-reverse`) while leaving DOM order unchanged — screen readers follow DOM order, not visual order

### Language & Encoding
- Always declare `lang` on `<html>`
- Always declare `<meta charset=utf-8>` at the document level

### Performance
- Scripts go before `</body>` (or use `defer`/`async`) — never block rendering
- Isolate critical CSS; defer non-critical stylesheets

---

## CSS

### Structure
- **Box model**: use a global `* { box-sizing: border-box; }` — don't override per-element
- **Flow**: keep elements in natural document flow; prefer `margin-left: auto` over `position: absolute` when either works
- **Positioning**: favor Flexbox and Grid over `position: absolute/fixed` where possible
- **Semicolons**: always use as terminators, not separators

### Selectors & Specificity
- Keep selectors short — if a selector exceeds 3 structural pseudo-classes or combinators, add a class instead
- Don't overload selectors: prefer `[src$=svg]` over `img[src$=svg]` when type is redundant
- Avoid IDs in selectors; avoid `!important`
- Don't override styles you just set — use adjacent sibling selectors (`li + li`) instead of exception rules

### Inheritance & Brevity
- Let inheritable properties (e.g. `text-shadow`) be declared once on the parent, not repeated on children
- Use shorthand: `padding: 5px 10px 20px` not four separate declarations
- Use `calc()` instead of multi-step margin tricks

### Units & Values
- Use unitless values where possible (`margin: 0` not `margin: 0px`)
- Use `rem` for relative font/spacing units (not `em`)
- Use seconds for transitions (`.5s` not `500ms`)
- Prefer English pseudo-selectors: `:nth-child(odd)` over `:nth-child(2n+1)`, `1turn` over `360deg`
- Colors: hexadecimal by default; `rgba()` only when transparency is needed

### Animations
- Favor `transition` over `@keyframes animation`
- Only animate `opacity` and `transform` — never `width`, `height`, `margin`, or other layout properties (forces layout recalc every frame; performance difference is significant)
- Hover transitions ~150ms; 400ms+ with no feedback looks broken
- **Ease asymmetry**: `ease-out` for entering elements (decelerates into place), `ease-in` for exiting (accelerates away) — never mirror the enter animation for exit
- **Reduced motion**: any significant movement must check `@media (prefers-reduced-motion: reduce)` — ignoring it can trigger vestibular symptoms
- Remove obsolete vendor prefixes; when needed, prefix before standard property

### Visual Design Rules
- **Disabled states**: use a specific muted token (e.g. `--color-text-disabled`), not `opacity: 0.5` — opacity can pass or fail contrast unpredictably depending on background
- **Nested border-radius**: inner element radius = outer radius − padding (e.g. outer 12px, padding 4px → inner 8px); matching both creates a visible gap
- **Tabular nums**: apply `font-variant-numeric: tabular-nums` to any column of numbers that updates — keeps digits aligned as values change
- **Mobile viewport**: use `dvh` not `vh` for full-screen layouts — `vh` ignores the browser chrome that shows/hides on scroll and causes overflow
- **Safe area**: fixed bottom elements must account for the home indicator — use `padding-bottom: env(safe-area-inset-bottom)`
- **Decorative layers**: set `pointer-events: none` on decorative overlays so they don't intercept clicks
- **Color**: prefer OKLCH for gradients and generated palettes — HSL/sRGB midpoints go grey; OKLCH stays vivid and is perceptually accurate
- **Semantic color tokens**: name tokens for purpose, not value — `--color-border-subtle` not `#e0e0e0`; a single token change updates everything

### Misc
- Draw simple shapes (circles, lines) with CSS instead of loading an image over HTTP
- No CSS hacks (e.g. `translateZ(0)` as a forced composite layer trick without `will-change`)

---

## JavaScript

### Clarity over Cleverness
- Optimize for readability, correctness, and expressiveness — not micro-performance
- Eliminate smart tricks that obscure intent: `if (!foo) doSomething()` beats `foo || doSomething()`
- Avoid bitwise hacks: `Math.floor(3.14)` not `~~3.14`

### Functions
- **Pure by default**: functions should produce no side-effects, use no outside data, and return new objects instead of mutating existing ones
- **No `arguments` object**: use rest params (`...numbers`) — named, and a real array
- **No `apply()`**: use spread (`greet(...person)`)
- **No `bind()`** when an arrow function is cleaner
- **Avoid nested functions** when point-free works: `[1,2,3].map(String)` not `[1,2,3].map(n => String(n))`
- **Composition over nesting**: use a `pipeline` helper for multi-step transforms instead of `f(g(h(x)))`

### Iteration & Data Structures
- **No `for` / `while` loops**: use `array.prototype` methods (`map`, `filter`, `reduce`, `find`, etc.); fall back to recursion before imperative loops
- **No `for...in`** on objects: use `Object.keys(obj).forEach()`
- **Map over plain object** when the use case is a keyed collection — `Map` has `.size`, proper iteration, and no prototype pollution

### Variables & Conditions
- `const` > `let` > `var`
- Avoid `else if` / `else` chains — use early returns or IIFE + return pattern

### Coercion & Natives
- Embrace sensible implicit coercion (`x == undefined` catches both `null` and `undefined`)
- Use native array/string/object methods; implement small helpers instead of importing full libraries
- Cache feature tests once via IIFE, not inside the function that runs repeatedly

### Dependencies
- Don't load a full utility library for 2–3 functions — write the 3-line equivalent inline
- Minimize third-party code surface area: every dep is code you don't fully understand

---

## Quick Review Checklist

```
HTML
[ ] Semantic elements used correctly (not wrapper divs)
[ ] No XHTML artifacts (self-closing, redundant types)
[ ] Meaningful alt text on all images
[ ] Interactive elements are real <button>/<a> tags
[ ] lang + charset declared
[ ] Scripts deferred / at end of body
[ ] Focus styles replaced (not just removed)
[ ] Touch targets >= 44x44px
[ ] DOM order matches visual order (no CSS-only reordering)
[ ] Labels linked via for/id (clicking label focuses field)

CSS
[ ] Global box-sizing set, not per-element
[ ] No unnecessary position:absolute when flow works
[ ] Selectors < 3 levels deep
[ ] No !important / no ID selectors
[ ] Shorthand used everywhere
[ ] Unitless zeros, rem not em, seconds not ms
[ ] Only opacity/transform animated (no layout props)
[ ] Ease-out enter / ease-in exit (not mirrored)
[ ] prefers-reduced-motion respected
[ ] Disabled states use muted token, not opacity
[ ] Nested border-radius = outer - padding
[ ] Tabular nums on updating number columns
[ ] dvh not vh for full-screen mobile layouts
[ ] Safe area inset on fixed bottom elements
[ ] Decorative overlays have pointer-events: none

JS
[ ] No for/while loops (array methods or recursion)
[ ] No mutations — return new objects
[ ] const everywhere possible
[ ] No arguments object (rest params)
[ ] No apply() (spread)
[ ] No bind() when arrow fn is cleaner
[ ] No full library import for 2-3 utility functions
[ ] No clever obfuscation (bitwise, short-circuit abuse)
```

---

## Source

Rules derived from: [bendc/frontend-guidelines](https://github.com/bendc/frontend-guidelines) — a concise, opinionated coding standards guide for HTML, CSS, and JavaScript.

Visual design rules (disabled states, nested radius, tabular nums, dvh, safe area, ease asymmetry, reduced motion, OKLCH, semantic tokens) extracted from: [index.how/to/articulate](https://index.how/to/articulate) — 188-term designer vocabulary reference.
