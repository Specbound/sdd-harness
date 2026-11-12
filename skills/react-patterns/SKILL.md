---
name: react-patterns
description: Modern React patterns — component design, hooks, state management, composition, performance (Vercel's 45-rule priority list), and UI state (loading/error/empty). Use when building or reviewing React/Next.js components, choosing state solutions, or fixing render performance.
---

# React Patterns

> Principles for building production-ready React applications. Build small, compose thoughtfully.

## 1. Component Design
| Type | Use | State |
|---|---|---|
| Server | Data fetching, static | None |
| Client | Interactivity | useState, effects |
| Presentational | UI display | Props only |
| Container | Logic/state | Heavy state |

Rules: one responsibility per component; props down, events up; composition over inheritance; prefer small, focused components.

## 2. Hooks
Extract a custom hook when: storage logic repeats (`useLocalStorage`), multiple debounced values exist (`useDebounce`), fetch patterns repeat (`useFetch`), or form state gets complex (`useForm`).
Rules: hooks only at top level, same order every render; custom hooks start with `use`; always clean up effects on unmount.

React 19: `useActionState` (form submission state), `useOptimistic` (optimistic UI), `use` (read resources in render). The compiler auto-memoizes — write less manual `useMemo`/`useCallback` and focus on pure components.

## 3. State Management Selection
| Complexity | Solution |
|---|---|
| Simple | useState, useReducer |
| Shared local | Context |
| Server state | React Query, SWR |
| Complex global | Zustand, Redux Toolkit |

Placement: single component → useState; parent-child → lift state up; subtree → Context; app-wide → global store.

## 4. Composition
- **Compound components**: parent provides context, children consume it, slot-based composition that adapts to each use case (Tabs, Accordion, Dropdown).
- Custom hook for reusable logic; render props when the caller needs control over rendering; HOC only for genuine cross-cutting concerns.

## 5. Performance — Priority Order
Check if actually slow → profile with DevTools → identify the bottleneck → apply the targeted fix. Never speed things up before profiling.

Rule categories, ranked by real-world impact (Vercel engineering guidance):
| Priority | Category | Impact | Key rules |
|---|---|---|---|
| 1 | Eliminating waterfalls | CRITICAL | move `await` into the branch that needs it; `Promise.all()` independent ops; start promises early/await late in API routes; `Suspense` to stream content |
| 2 | Bundle size | CRITICAL | import directly, avoid barrel files; `next/dynamic` for heavy components; defer third-party scripts (analytics); preload on hover/focus |
| 3 | Server-side perf | HIGH | `React.cache()` for per-request dedup; LRU cache cross-request; parallelize server fetches; use `after()` for non-blocking work |
| 4 | Client-side fetching | MED-HIGH | SWR for automatic request dedup; dedupe global event listeners |
| 5 | Re-render tuning | MEDIUM | don't subscribe to state only used in callbacks; extract expensive work into memoized components; primitive deps in effects; subscribe to derived booleans not raw values; functional `setState` for stable callbacks; lazy `useState` init for expensive initial values; `startTransition` for non-urgent updates |
| 6 | Rendering | MEDIUM | animate a wrapper `div`, not the SVG element; `content-visibility` for long lists; hoist static JSX outside the component; ternary over `&&` for conditional render (avoids stray `0`/`false`) |
| 7 | JS perf | LOW-MED | build a `Map` for repeated lookups; cache object property access and function results in loops; cache storage reads; combine multiple `filter`/`map` into one pass; early-exit/length-check before expensive comparisons; hoist `RegExp` literals |
| 8 | Advanced | LOW | stable refs for event handlers; `useLatest` pattern for always-current closures |

## 6. Error Handling
Error boundaries: app-wide at root, feature-level at route boundary, component-level around a specifically risky subtree. Recovery: show fallback UI, log the error, offer retry, preserve user data where possible.

## 7. TypeScript
| Pattern | Use |
|---|---|
| Interface | Component props |
| Type | Unions, complex compositions |
| Generic | Reusable components |

Common types: `ReactNode` for children, `MouseEventHandler`/etc. for handlers, `RefObject<Element>` for refs.

## 8. Testing
Unit → pure functions/hooks. Integration → component behavior. E2E → user flows. Priorities: user-visible behavior, edge cases, error states, accessibility.

## 9. UI State Patterns (loading / error / empty)
**Golden rule: show a loading indicator ONLY when there is no data to display** — otherwise refetches flash a spinner over good data.
```tsx
if (error) return <ErrorState error={error} onRetry={refetch} />;
if (loading && !data) return <LoadingState />;
if (!data?.items.length) return <EmptyState />;
return <ItemList items={data.items} />;
```
Skeleton vs spinner: skeleton for known content shape (lists/cards, initial load); spinner for unknown shape (modal actions, button submissions).

**Never swallow errors.** Every mutation needs an `onError` that surfaces feedback (toast/banner), not just `console.error`. Error hierarchy: inline field error → toast (recoverable) → page-level banner (partial data still usable) → full error screen (unrecoverable).

**Buttons**: always disable + show loading during async ops, or users double-submit:
```tsx
<Button disabled={isSubmitting} isLoading={isSubmitting} onClick={handleSubmit}>Submit</Button>
```
**Empty states are mandatory** for every list/collection, and should be contextual (e.g. "No results found" for search vs "No items yet — Create your first item" for a fresh list).

## 10. Anti-Patterns
| Don't | Do |
|---|---|
| Prop drilling deep | Use context |
| Giant components | Split smaller |
| useEffect for everything | Server components |
| Premature performance tuning | Profile first |
| Index as key | Stable unique ID |
| `if (loading) return <Spinner/>` | `if (loading && !data) return <Spinner/>` |
| Swallowing errors in `catch`/`onError` | Surface via toast/banner + log |
| Button without disabled state during submit | `disabled={isSubmitting}` |
| List with no empty state | Explicit `EmptyState` component |

## Pre-Ship Checklist
- [ ] Error state handled and shown to the user
- [ ] Loading state shown only when there's no data
- [ ] Empty state provided for every collection
- [ ] Buttons disabled + show loading during async ops
- [ ] Mutations have an `onError` handler with user feedback
</content>
