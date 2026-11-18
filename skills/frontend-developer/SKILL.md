---
name: frontend-developer
description: "React and Next.js frontend development: component patterns, hooks, state management, Suspense-first data fetching, performance, forms, and accessibility. Use when building or reviewing React/Next.js components, choosing a state-management or data-fetching pattern, or improving render performance of an existing UI."
risk: unknown
source: community
---

# Frontend Developer (React / Next.js)

## Use this skill when
- Building or refactoring React components, hooks, or Next.js routes
- Choosing a state-management, data-fetching, or component-composition pattern
- Debugging render performance, prop drilling, or stale closures
- Adding forms, error boundaries, or accessible keyboard interactions

## Do not use this skill when
- The task is pure visual/aesthetic styling with no component behavior
- The system is non-React/non-web

## Core Stack Defaults
- **React 19**: `useActionState` for form submission with built-in pending/error state, `useOptimistic` for optimistic UI updates, `useTransition` for state updates that shouldn't block input, `useDeferredValue` to defer expensive re-renders (e.g. search results) behind fast typing.
- **Next.js 15 (App Router)**: Server Components by default; `'use client'` only where interactivity/hooks are needed; Server Actions for mutations instead of API routes where possible; co-locate `loading.tsx`/`error.tsx` per route segment.
- **Suspense-first data fetching** (e.g. TanStack Query): `useSuspenseQuery` as the primary hook — no `isLoading` conditionals, no manual spinners, no early-return loading states; rely on `<Suspense>` boundaries instead.

## Component Standards
- Order: types/props → hooks → derived values (`useMemo`) → handlers (`useCallback`) → render → default export.
- Lazy-load anything heavy (routes, charts, editors, large dialogs): `const Heavy = React.lazy(() => import('./Heavy'))`, always inside a Suspense boundary.
- Feature-based organization: domain logic in `features/<name>/{api,components,hooks,types}`, reusable primitives in `components/`. No cross-feature imports.

### Composition patterns
```tsx
// Composition over inheritance
export function Card({ children, variant = 'default' }: CardProps) {
  return <div className={`card card-${variant}`}>{children}</div>;
}
export function CardHeader({ children }: { children: ReactNode }) { return <div className="card-header">{children}</div>; }
```
Compound components (`Tabs`/`TabList`/`Tab`) share state via an internal context instead of prop drilling — each child reads `useContext(TabsContext)` and throws if used outside the provider.

## Custom Hooks
```tsx
function useToggle(initial = false) {
  const [v, setV] = useState(initial);
  return [v, useCallback(() => setV(x => !x), [])] as const;
}
function useDebounce<T>(value: T, delay: number) {
  const [d, setD] = useState(value);
  useEffect(() => { const t = setTimeout(() => setD(value), delay); return () => clearTimeout(t); }, [value, delay]);
  return d;
}
```
Debounce search/filter input 300-500ms before firing a query. For async data-fetching hooks, expose `{ data, error, loading, refetch }` and support an `enabled` flag so callers can defer the initial fetch.

## State Management
- Local/derived state: `useState`/`useMemo`. Cross-component but feature-scoped state: Context + `useReducer` — typed action union, a reducer switch, a provider, and a custom `useX()` hook that throws if called outside its provider.
- Avoid prop drilling past 2-3 levels — promote to context or a feature-level store instead.

## Data Fetching
- API calls isolated in a feature's `api/` layer — never inline `fetch`/axios calls inside components.
- Typed responses end-to-end; no untyped `any` from a fetch call.
- Forbidden when using a Suspense-based data layer: `isLoading` conditionals, manual spinners, fetch logic inside component bodies.

## Routing
- **Next.js App Router**: file-based, Server Components by default, `loading.tsx`/`error.tsx` per segment, Server Actions for mutations.
- **TanStack Router** (SPA alternative): folder-based routing, lazy-loaded route components, breadcrumb metadata via loaders:
```ts
export const Route = createFileRoute('/my-route/')({ component: MyPage, loader: () => ({ crumb: 'My Route' }) });
```

## Styling
- Inline (`className`/`sx`) for components under ~100 lines of style; extract to a co-located stylesheet past that.
- Keep theme/token access type-safe — no magic-string colors/spacing outside the design-token set.

## Performance
- `useMemo` for expensive derivations, `useCallback` for handlers passed to children, `React.memo` for heavy pure components — skip it on trivial components where the comparison itself costs more than the render.
- Code-split anything heavy via `React.lazy` + `Suspense`.
- Virtualize long lists (hundreds of rows) with `@tanstack/react-virtual` — render only visible rows plus overscan, not the full list.
- Clean up effects (`clearTimeout`, `removeEventListener`, subscription teardown) to avoid leaks.
- Treat a performance regression as a bug, not a follow-up.

## Forms
- Controlled inputs + a `validate()` function returning a field-keyed error object; validate on submit, show errors inline per field.
- Prefer `useActionState` (React 19) for server-backed submission over manual `useState` + fetch wiring.

## Error Boundaries
```tsx
class ErrorBoundary extends React.Component<{ children: ReactNode }, { hasError: boolean }> {
  state = { hasError: false };
  static getDerivedStateFromError() { return { hasError: true }; }
  componentDidCatch(error: Error, info: ErrorInfo) { /* log */ }
  render() { return this.state.hasError ? <Fallback /> : this.props.children; }
}
```
Place boundaries at feature or route level, not only once at the app root — one broken widget shouldn't blank the whole page.

## Accessibility
- Keyboard nav for custom interactive components (dropdowns, menus): arrow keys move selection, `Enter` selects, `Escape` closes; set `role`/`aria-expanded`/`aria-haspopup` correctly.
- Focus management: save `document.activeElement` before opening a modal, focus the modal on open, restore focus to the trigger on close.
- Respect `prefers-reduced-motion`; never rely on color as the only state indicator; keep focus rings visible.

## Anti-Patterns
Early loading returns instead of Suspense boundaries · feature logic placed in shared `components/` · inline API calls inside components · untyped fetch responses · prop drilling past a few levels instead of context · wrapping every component in `React.memo` regardless of render cost · missing effect cleanup · modals that don't restore focus on close.

## Operator Checklist
- [ ] Suspense boundaries (or Server Components) used instead of manual loading state
- [ ] Feature boundaries respected, no cross-feature imports
- [ ] Types explicit, no `any`
- [ ] Heavy components lazy-loaded
- [ ] Long lists virtualized
- [ ] Forms validated with inline per-field errors
- [ ] Keyboard nav + focus management on custom interactive components
