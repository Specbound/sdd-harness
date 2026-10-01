---
name: nextjs-best-practices
description: Next.js 14+ App Router patterns — Server/Client Components, data fetching and caching, Server Actions, parallel/intercepting routes, streaming, route handlers, and metadata. Use when building, reviewing, or migrating Next.js App Router applications.
---

# Next.js Best Practices

> Server Components are the default for a reason. Start there, add client only when needed.

## 1. Server vs Client Components
```
Needs useState/useEffect/event handlers/browser APIs?  → Client ('use client')
Only fetches data, no interactivity?                    → Server (default)
Needs both?                                              → Split: Server parent + Client child
```
| Type | Use |
|---|---|
| Server | Data fetching, layout, static/secret-bearing content |
| Client | Forms, buttons, interactive UI |

Don'ts: no hooks in Server Components; don't pass non-serializable data across the Server→Client boundary; don't fetch inside Client Components (fetch in a Server Component or use React Query/SWR instead).

## 2. File Conventions
| File | Purpose |
|---|---|
| `page.tsx` | Route UI |
| `layout.tsx` | Shared layout (persists across navigation) |
| `template.tsx` | Like layout but re-mounts on navigation |
| `loading.tsx` | Suspense fallback for the route |
| `error.tsx` | Error boundary |
| `not-found.tsx` | 404 UI |
| `route.ts` | API endpoint (Route Handler) |
| `default.tsx` | Fallback for an unmatched parallel-route slot |

## 3. Rendering Modes
| Mode | Where | When |
|---|---|---|
| Static | Build time | Content that rarely changes |
| Dynamic | Request time | Personalized/real-time data (`cache: 'no-store'`) |
| ISR | Build + revalidate | `fetch(url, { next: { revalidate: 60 } })` |
| Streaming | Progressive | Large pages or slow data sources behind `<Suspense>` |

## 4. Data Fetching & Caching
```typescript
fetch(url, { cache: 'no-store' })              // always fresh
fetch(url, { cache: 'force-cache' })            // static, cached indefinitely
fetch(url, { next: { revalidate: 60 } })        // ISR: refresh after 60s
fetch(url, { next: { tags: ['products'] } })    // tag for on-demand invalidation

// Invalidate from a Server Action
'use server'
import { revalidateTag, revalidatePath } from 'next/cache'
export async function updateProduct(id: string, data: ProductData) {
  await db.product.update({ where: { id }, data })
  revalidateTag('products')
  revalidatePath('/products')
}
```
Colocate data fetching with the component that needs it — fetch requests for the same URL+options are automatically deduped within a render pass.

## 5. Server Actions
```typescript
// app/actions/cart.ts
'use server'
import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'

export async function addToCart(productId: string) {
  const sessionId = (await cookies()).get('session')?.value
  if (!sessionId) redirect('/login')
  try {
    await db.cart.upsert({ where: { sessionId_productId: { sessionId, productId } },
      update: { quantity: { increment: 1 } }, create: { sessionId, productId, quantity: 1 } })
    return { success: true }
  } catch { return { error: 'Failed to add item to cart' } }
}
```
Call from a Client Component via `useTransition` so the UI shows `isPending` without blocking input. Mark every Server Action with `'use server'`, validate all inputs, return typed `{ success | error }` responses.

## 6. Parallel & Intercepting Routes
- **Parallel routes** (`@slot` folders): layout receives each slot as a prop (`{ children, analytics, team }`), each slot renders and loads independently — use for dashboards with independent panels.
- **Intercepting routes** (`(.)segment`): render a route in a modal overlay while keeping the full-page version at its own URL (classic photo-modal pattern) — `app/@modal/(.)photos/[id]/page.tsx` intercepts `app/photos/[id]/page.tsx`.

## 7. Streaming with Suspense
```typescript
export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)          // blocks — needed for header
  return (
    <div>
      <ProductHeader product={product} />
      <Suspense fallback={<ReviewsSkeleton />}><Reviews productId={id} /></Suspense>
      <Suspense fallback={<RecsSkeleton />}><Recommendations productId={id} /></Suspense>
    </div>
  )
}
```
Each `Suspense`-wrapped async component fetches its own (possibly slow) data and streams in independently — don't block the whole page on the slowest query.

## 8. Route Handlers (API Routes)
```typescript
// app/api/products/[id]/route.ts
export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await db.product.findUnique({ where: { id } })
  if (!product) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  return NextResponse.json(product)
}
```
Validate input with Zod, return proper status codes, use the Edge runtime when latency matters and the handler has no Node-only dependencies.

## 9. Metadata & SEO
```typescript
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const product = await getProduct(slug)
  if (!product) return {}
  return { title: product.name, description: product.description,
    openGraph: { title: product.name, images: [{ url: product.image, width: 1200, height: 630 }] } }
}
export async function generateStaticParams() { /* return [{ slug }, ...] for SSG */ }
```
title 50-60 chars, description 150-160 chars, always set Open Graph images + canonical URL. Use `generateMetadata` for per-route dynamic values, static `export const metadata` otherwise.

## 10. Performance
- `next/image`: set `priority` on above-the-fold images, always provide a blur placeholder, use responsive `sizes`.
- Dynamic imports (`next/dynamic`) for heavy client components; route-based code splitting is automatic.
- Analyze with the bundle analyzer before assuming a fix worked.

## 11. Anti-Patterns
| Don't | Do |
|---|---|
| `'use client'` everywhere | Server by default |
| Fetch inside Client Components | Fetch in Server Components |
| Skip loading states | `loading.tsx` or `<Suspense>` |
| Ignore error boundaries | `error.tsx` per route segment |
| Large client bundles | Dynamic imports, check bundle analyzer |
| Over-nested layouts | Each layout adds to the component tree — nest only what truly shares UI |

## 12. Project Structure
```
app/
├── (marketing)/       # Route group — organizes without affecting the URL
│   └── page.tsx
├── (dashboard)/
│   ├── layout.tsx
│   ├── @analytics/    # Parallel route slot
│   └── page.tsx
├── api/[resource]/route.ts
└── components/ui/
```

## Stack & Quality Gates
Typical stack: Next.js 14+/React 18+, TypeScript 5+, Tailwind CSS, Zustand/React Query for state, React Hook Form + Zod for forms, Vitest + Playwright for tests, deployed on Vercel.
Before shipping: TypeScript compiles clean, tests pass, lint clean, Core Web Vitals (LCP/CLS/FID) met, WCAG 2.1 checked, responsive design verified.

## Resources
- `resources/implementation-playbook.md` — full worked examples for every pattern above.
</content>
