---
name: angular
description: Angular v20+ expert — Signals, Standalone Components, Zoneless change detection, SSR/hydration, routing/DI, reactive forms, performance priority rules, and UI loading/error/empty state patterns. Use when building, reviewing, or tuning Angular applications.
---

# Angular

## Use this skill when
- Building Angular apps (v20+) with Signals, Standalone Components, Zoneless change detection
- Implementing SSR, hydration, routing, DI, or reactive forms
- Reviewing Angular code for performance (change detection, bundle size, rendering)
- Choosing loading/error/empty UI state patterns

## Do not use this skill when
- Migrating AngularJS (1.x) — different framework entirely
- General TypeScript issues unrelated to Angular — see typescript-pro

## 1. Signals
```typescript
const count = signal(0);
count.set(5);
count.update(v => v + 1);
const doubled = computed(() => count() * 2);
effect(() => console.log(`Count: ${count()}`));
```
```typescript
// Signal inputs/outputs/two-way binding
export class UserCardComponent {
  id = input.required<string>();
  role = input<string>('User');       // default
  select = output<string>();
  isSelected = model(false);           // two-way: [(isSelected)]
}
// Signal queries replace @ViewChild/@ContentChild
searchInput = viewChild<ElementRef>('searchInput');
items = viewChildren(ItemComponent);
```

## 2. Standalone Components & Bootstrap
```typescript
@Component({ selector: 'app-header', standalone: true, imports: [CommonModule, RouterLink], template: `...` })
export class HeaderComponent {}

bootstrapApplication(AppComponent, { providers: [provideRouter(routes), provideHttpClient()] });

// Lazy load
{ path: 'dashboard', loadComponent: () => import('./dashboard.component').then(m => m.DashboardComponent) }
```

## 3. Zoneless Change Detection
```typescript
// main.ts — Zoneless Angular (v20+)
bootstrapApplication(AppComponent, { providers: [provideZonelessChangeDetection()] });

@Component({ changeDetection: ChangeDetectionStrategy.OnPush, template: `<div>{{ count() }}</div>` })
export class CounterComponent { count = signal(0); }
```
Benefits: no zone.js patches on async APIs, ~15KB smaller bundle, clean stack traces, better Web Component/micro-frontend interop. Enable for new projects; don't force onto untested legacy apps.

## 4. SSR & Hydration
```bash
ng add @angular/ssr
```
```typescript
// app.config.ts
providers: [provideClientHydration(withIncrementalHydration(), withEventReplay())]
```
```html
<app-header /><app-hero />                      <!-- critical, renders immediately -->
@defer (hydrate on viewport) { <app-comments /> }
@defer (hydrate on interaction) { <app-chat-widget /> }
```
| Trigger | When |
|---|---|
| `on idle` | Low priority, hydrate when browser idle |
| `on viewport` | Element enters viewport |
| `on interaction` | First user interaction |
| `on hover` | User hovers |

Use `TransferState` to pass server-fetched data to the client and avoid a duplicate fetch (check `isPlatformBrowser`/`isPlatformServer`, `set`/`get`/`remove` the state key). Avoid client-only `ngOnInit` fetches for critical data in SSR routes — use a route resolver so data is ready before the component renders.

## 5. Routing & DI
```typescript
export const authGuard: CanActivateFn = (route, state) => {
  const auth = inject(AuthService);
  return auth.isAuthenticated() || router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
};
export const userResolver: ResolveFn<User> = (route) => inject(UserService).getUser(route.paramMap.get('id')!);
// component: user = toSignal(this.route.data.pipe(map(d => d['user'])));
```
```typescript
// Modern inject() over constructor injection
export class UserComponent {
  private http = inject(HttpClient);
  users = toSignal(this.userService.getUsers());
}
export const API_BASE_URL = new InjectionToken<string>('API_BASE_URL');
```

## 6. Composition
Content projection (`<ng-content select="[card-header]">`) for slot-based layout; host directives for reusable cross-cutting behavior (e.g. a tooltip directive attached via `hostDirectives` instead of inheritance).

## 7. State Management
```typescript
@Injectable({ providedIn: 'root' })
export class StateService {
  private _user = signal<User | null>(null);
  readonly user = computed(() => this._user());
  setUser(user: User | null) { this._user.set(user); }
}
```
Feature-scoped stores (`@Injectable()` + `providers: [ProductStore]` on the component, not `providedIn: 'root'`) keep state tree-shakeable and avoid re-rendering subscribers of unrelated global state. Selectors/computed signals give selective subscription — read only the derived slice a component needs.

## 8. Reactive Forms
```typescript
form = this.fb.group({
  name: ['', Validators.required],
  email: ['', [Validators.required, Validators.email]],
});
isFieldInvalid(f: string) { const c = this.form.get(f); return !!c && c.invalid && c.touched; }
```
Signal-based Forms API is experimental (preview) — current reactive forms remain the production path.

## 9. Performance — Priority Order
| Priority | Category | Key rules |
|---|---|---|
| 1 | Change detection | `OnPush` everywhere; Signals over mutable properties; Zoneless for new projects |
| 2 | Async waterfalls | `forkJoin` for parallel fetches, not nested subscribes; resolvers for SSR-critical data, not `ngOnInit` fetches |
| 3 | Bundle size | Lazy-load routes (`loadChildren`/`loadComponent`); `@defer` heavy components; avoid barrel re-exports; dynamic-import third-party libs |
| 4 | Rendering | `track` expression on every `@for`; virtual scroll (`cdk-virtual-scroll-viewport`) for large lists; pure pipes/`computed()` over template methods |
| 5 | SSR | Incremental hydration, defer non-critical content, `TransferState` for server-fetched data |
| 6 | Templates | New `@if`/`@for`/`@defer` control flow over `*ngIf`/`*ngFor`; precompute sorts/filters in `computed()`, not in the template |
| 7 | Memory | `takeUntilDestroyed(destroyRef)` or Signals (`toSignal`) over manual subscription + `ngOnDestroy` |

```html
<img ngSrc="hero.jpg" width="800" height="600" priority />            <!-- above fold -->
<img ngSrc="thumb.jpg" width="200" height="150" loading="lazy" placeholder="blur" />
```

## 10. UI State Patterns (loading / error / empty)
**Golden rule: show a loading indicator only when there is no data to display** — otherwise refetches flash a spinner over good content.
```html
@if (error()) { <app-error-state [error]="error()" (retry)="load()" /> }
@else if (loading() && !items().length) { <app-skeleton-list /> }
@else if (!items().length) { <app-empty-state message="No items found" /> }
@else { <app-item-list [items]="items()" /> }
```
Skeleton vs spinner: skeleton for known content shape (lists/cards, initial load); spinner for unknown shape (modal actions, button submissions).

**Never swallow errors** — every `catch` surfaces feedback (toast/banner), not just `console.error`. Hierarchy: inline field error → toast (recoverable) → page banner (partial data still usable) → full error screen (unrecoverable).

Buttons disable + show a loading state during async ops, or users double-submit:
```html
<button [disabled]="saving()" (click)="save()">@if (saving()) { <app-spinner /> Saving... } @else { Save }</button>
```
Every list needs an `@empty` block — contextual (e.g. "No results found" for search vs "No items yet — Create your first" for a fresh list).

## 11. Testing
```typescript
fixture = TestBed.createComponent(CounterComponent);
component = fixture.componentInstance;
fixture.detectChanges();
component.increment();
expect(component.count()).toBe(1);
```
```typescript
// Signal inputs are set via componentRef, not property assignment
componentRef.setInput('id', '123');
componentRef.setInput('name', 'John Doe');
fixture.detectChanges();
```

## Anti-Patterns
| Don't | Do |
|---|---|
| Default change detection everywhere | `OnPush` + Signals |
| `@Input()` decorator on new code | `input()` signal function |
| Constructor injection (verbose) | `inject()` function |
| Spinner whenever `loading()` is true | Spinner only when `loading() && !data` |
| Swallowing errors in `catch` | Surface via toast/banner + log |
| Button without disabled state during submit | `[disabled]="saving()"` |
| List with no `@empty` block | Explicit empty state with an action |
| Bloated `SharedModule` | Standalone components with direct imports |
| Eager-loaded feature routes | `loadComponent`/`loadChildren` + `@defer` |

## Common Troubleshooting
| Issue | Solution |
|---|---|
| Signal not updating UI | Ensure `OnPush` + call the signal as a function (`count()`) |
| Hydration mismatch | Check server/client content consistency |
| Circular dependency | `inject()` with `forwardRef` |
| Zoneless not detecting changes | Trigger via signal updates, not direct mutation |
| SSR fetch fails | Use `TransferState` or `withFetch()` |

## Resources
- [Angular.dev Documentation](https://angular.dev)
- [Angular Signals Guide](https://angular.dev/guide/signals)
- [Angular SSR Guide](https://angular.dev/guide/ssr)
- [Zoneless Angular](https://angular.dev/guide/experimental/zoneless)
