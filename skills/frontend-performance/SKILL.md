---
name: frontend-performance
description: Use when building web UIs, React apps, or frontend architecture — provides a checklist of performance decisions covering local-first data, optimistic updates, bundle strategy, animation constraints, and interaction design. Based on production patterns from apps like Linear.
---

<skill_overview>
Web app speed is not a single optimization — it emerges from aligning architecture, data flow, and design decisions around one principle: hide the network from the user. Every "loading" spinner is a failure of architecture, not a UI necessity.
</skill_overview>

<rigidity_level>
MEDIUM FREEDOM — Work through the checklist phases, but adapt patterns to your stack. The architecture decisions (local-first vs server-driven) are context-dependent; the animation rules are absolute.
</rigidity_level>

# Frontend Performance Skill

## When to Invoke

Use this skill when:
- Designing a new web application or feature
- Reviewing frontend architecture for performance
- Adding data fetching, mutations, or sync logic
- Adding animations or transitions
- Optimizing initial load time or bundle size
- Building a command palette, keyboard shortcuts, or interaction layer

**Also invoke:** `frontend-code-quality` when writing or reviewing HTML, CSS, or JS files — it covers per-file code quality rules (semantic HTML, CSS structural patterns, JS idioms) that complement this skill's architecture focus.

---

## Phase 1: Architecture Decision

**First, decide your data model:**

| Pattern | Use When | Tradeoff |
|---------|----------|----------|
| **Local-first** | User's data is workspace-scoped, must feel instant | Complex sync engine; eventual consistency |
| **Server-driven** | Real-time multi-user, strict consistency required | Spinners on every interaction; network bottleneck |
| **Hybrid** | Read-heavy with occasional writes | Most common for CRUD apps |

### Local-First Checklist (if chosen)
- [ ] Use IndexedDB (or similar) as the client-side DB — server is sync target, not source of truth
- [ ] Hydrate UI from local storage immediately on load — no waiting for network
- [ ] Write mutations to a transaction queue in IndexedDB first, then sync to server
- [ ] Implement retry + rollback logic for failed mutations in the background
- [ ] Chunk heavy data (large lists) with lazy-loading — treat it like code-splitting for data

### Server-Driven Checklist (if chosen)
- [ ] Use SWR/React Query stale-while-revalidate to reduce perceived latency
- [ ] Preload data for likely next routes on hover/focus
- [ ] Cache aggressively with appropriate invalidation

---

## Phase 2: Optimistic Updates

**Rule: The UI must never block on a network request for a user-initiated action.**

```
User action → Update local state immediately → Render → Sync to server in background
                                                              ↓
                                              On success: no-op (already correct)
                                              On failure: rollback + notify
```

Implementation pattern:
1. Apply change to local state synchronously
2. Queue async server call (don't await it in the render path)
3. On server success: confirm (possibly reconcile if server returned new fields)
4. On server failure: revert the local state change + show error

**Never show a loading spinner for mutations the user initiated.** Loading indicators are only valid for data the user didn't ask to change (background syncs, initial cold loads).

---

## Phase 3: Bundle & Load Strategy

### Initial Load
- [ ] Use `<link rel="modulepreload">` in `<head>` for the entire dependency graph — browser fetches all chunks in parallel before the entry script parses. Eliminates waterfall loading.
- [ ] Inline critical CSS in `<head>` (above-the-fold styles only) — page renders loading state without external stylesheet round-trip
- [ ] Inline a small JS snippet that reads `localStorage` to restore theme/sidebar/auth state before the bundle loads (avoids FOUC)
- [ ] Check `localStorage` for auth/workspace state to determine logged-in vs. logged-out immediately — don't wait for a `/me` network call to decide what to render

### Bundle Size
- [ ] Target modern browsers only (`esmodules`, no legacy transpilation) — cuts ~50% of bundle size
- [ ] Remove polyfills for features your browser targets support natively
- [ ] Code-split at route level (each route = separate chunk, lazy-loaded)
- [ ] Give each npm package its own cached chunk file (Vite/webpack: vendor splitting per package)
- [ ] Result: chunks are fine-grained and long-lived in cache — only changed chunks get re-fetched

### Service Worker
- [ ] Precache all hashed static assets on install (~CSS, fonts, route chunks, icons)
- [ ] Lazy-load the service worker after first login (don't block initial render)
- [ ] Subsequent navigations should hit cache-first — zero network for static assets

### Authentication
- [ ] Assume the happy path: check local workspace data exists, render immediately
- [ ] Validate session in the background — server rejects with 401 if stale
- [ ] Don't gate the entire render on an auth network call

---

## Phase 4: Reactivity & State

### Granular Observables (MobX or equivalent)
- [ ] Each model property should be its own observable, not the whole model
- [ ] One field update = one component re-render (not the entire list)
- [ ] At scale: 10 concurrent users editing = 10 cell re-renders, not a cascade

**Anti-pattern to avoid:**
```js
// BAD: one observable for the entire issue
const issue = observable({ title: '', status: '', priority: '' })

// GOOD: each property independently observable
class Issue {
  @observable title = ''
  @observable status = ''
  @observable priority = ''
}
```

### Command Palette
- [ ] Searches local in-memory state (never hits the server for search)
- [ ] Accessible via `⌘K` / `Ctrl+K`
- [ ] Surfaces keyboard shortcuts for every action listed

---

## Phase 5: Animation Rules (ABSOLUTE — no exceptions)

### Property Hierarchy

| Property Type | Examples | Rule |
|--------------|----------|------|
| **Composited** | `transform`, `opacity` | ✅ Safe to animate — GPU-accelerated, no layout recalc |
| **Paint** | `background-color`, `border-color`, `box-shadow` | ⚠️ Use sparingly — repaints pixels but skips layout |
| **Layout** | `width`, `height`, `margin`, `padding`, `top`, `left` | ❌ Never animate — recomputes every element's position |

### Timing Rules
- Default transitions: **100–150ms** (below the 200ms cause-and-effect perception threshold)
- Asymmetric timing: elements **appear instantly** (0ms or <50ms), **fade out over 150ms**
- Never use `transition: all` — always specify individual properties
- Page-level transitions: **200–300ms max**

### Quick Animation Checklist
- [ ] All animated properties are `transform` or `opacity` (composited layer)
- [ ] No `width`/`height`/`margin` animations anywhere in the codebase
- [ ] Transitions specify exact properties (not `all`)
- [ ] Duration ≤ 150ms for micro-interactions, ≤ 300ms for page transitions
- [ ] `will-change: transform` only on elements that WILL animate (not preemptively)

---

## Phase 6: Interaction Design

### Keyboard-First
- [ ] Every common action has a single-key or two-key shortcut
- [ ] Shortcuts are visible in the UI (not hidden in docs)
- [ ] Command palette consolidates all actions for discoverability

**Why it matters:** The gap between a keyboard shortcut and a 2-step mouse path is small per action, but compounds across hundreds of daily interactions. Keyboard-first users experience the app as fundamentally faster.

---

## Summary Checklist

Use this at architecture review time:

```
ARCHITECTURE
[ ] Local-first OR server-driven decision made intentionally
[ ] Optimistic updates for all user-initiated mutations
[ ] No spinners on mutations (only on cold initial loads)

LOAD
[ ] modulepreload declared for dependency graph
[ ] Critical CSS inlined
[ ] Auth state checked from localStorage before bundle load
[ ] Modern-browser-only bundle (no legacy transpilation)
[ ] Service worker precaching hashed assets

REACTIVITY  
[ ] Property-level observables (not model-level)
[ ] Command palette searches local state

ANIMATION
[ ] Only transform/opacity animated
[ ] No layout property animations
[ ] Durations ≤ 150ms (micro), ≤ 300ms (page)
[ ] No `transition: all`
```

---

## Source

Patterns derived from: [How is Linear So Fast? A Technical Breakdown](https://performance.dev/how-is-linear-so-fast-a-technical-breakdown) — covers Linear's sync engine, bundle strategy, and animation discipline at production scale.
