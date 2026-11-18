---
name: angular-migration
description: "Migrate an AngularJS (1.x) app to modern Angular with ngUpgrade hybrid mode — bidirectional DI bridging, component downgrade/upgrade, and dual-router coexistence. Use when planning or executing an AngularJS-to-Angular migration, running both frameworks side by side, or debugging hybrid interop failures."
risk: unknown
source: community
---

# AngularJS → Angular Migration

Covers the part of migration that is actually hard: running both frameworks in one page
while you move code across, and getting out again.

## Version facts (verified against the npm registry, 2026-10-22)

- Current Angular: **v22** (`@angular/core@22.2.3`).
- **`@angular/upgrade` is still published and versioned in lockstep — `22.2.3`.** ngUpgrade
  is not abandoned; the hybrid path is still supported.
- `angular@1.8.3` (AngularJS) is **formally deprecated on npm**: *"AngularJS support has
  officially ended."* No security patches. This is the business case for the migration —
  cite it, don't re-argue it.

Pin `@angular/upgrade` to the exact same version as `@angular/core`. A mismatched pair
fails in ways that look like application bugs.

## Pick a strategy

| Strategy | Use when | Real cost |
|---|---|---|
| **Hybrid (ngUpgrade)** | Large app, must keep shipping | Both frameworks in the bundle for the whole migration; interop bugs |
| **Rewrite alongside** | Small app, or AngularJS code is already being replaced | Two codebases to keep at feature parity until cutover |
| **Vertical slice** | Clear feature boundaries, new work can go in Angular | Needs a route-level seam; still ngUpgrade under the hood |

Avoid a big-bang cutover without a staging validation and a rollback path.

## Hybrid bootstrap

Hybrid bootstrap is still **NgModule-based**, even though standalone components are the
default for new Angular code. `UpgradeModule` needs the module injector, so this file stays
on `bootstrapModule` until AngularJS is fully gone. Components you *write* during migration
can still be standalone — it is only the bootstrap that is constrained.

```typescript
// main.ts
import { platformBrowserDynamic } from '@angular/platform-browser-dynamic';
import { UpgradeModule } from '@angular/upgrade/static';
import { AppModule } from './app/app.module';

platformBrowserDynamic()
  .bootstrapModule(AppModule)
  .then(ref => {
    const upgrade = ref.injector.get(UpgradeModule);
    // strictDi:true fails loudly on implicit DI annotations — turn it on NOW,
    // while you still have AngularJS experts around. Minification breaks
    // implicit annotations silently, and only in the production build.
    upgrade.bootstrap(document.body, ['myAngularJSApp'], { strictDi: true });
  });
```

`AppModule` imports `UpgradeModule` and declares an empty `ngDoBootstrap()` — Angular must
not bootstrap a root component itself, because AngularJS owns the DOM.

## Bridging DI in both directions

This is the core of ngUpgrade and the part worth keeping in context.

```typescript
// Angular service → usable from AngularJS
import { downgradeInjectable } from '@angular/upgrade/static';
angular.module('myApp').factory('newService', downgradeInjectable(NewService) as any);

// Angular component → usable from an AngularJS template
import { downgradeComponent } from '@angular/upgrade/static';
angular.module('myApp').directive(
  'appUserCard',
  downgradeComponent({ component: UserCardComponent })
);
// NOTE: `inputs`, `outputs` and `selectors` are accepted but have been
// @deprecated since v4 and are NOT used — verified in the v22.2.3 typings.
// Bindings come from the component's own @Input/@Output metadata. Copying
// an older snippet that passes them gives a false sense of wiring.

// AngularJS service → usable from Angular
export const OLD_SERVICE = new InjectionToken<unknown>('oldService');

// in AppModule providers:
{ provide: OLD_SERVICE, useFactory: (i: any) => i.get('oldService'), deps: ['$injector'] }
```

Rules that save time:
- Downgraded components are AngularJS **directives** — match AngularJS naming
  (`appUserCard` → `<app-user-card>`).
- To avoid paying Angular's bootstrap cost up front, `downgradeModule()` bootstraps the
  Angular side lazily, the first time a downgraded component is actually instantiated.
  Worth it when only a few AngularJS routes use Angular so far.
- A service must have exactly one owner. Two implementations bridged both ways means two
  instances and two sources of truth.
- Migrate **services before components**. Services have no template or change-detection
  surface, so they port cleanly and shrink the next step.

## Routing: the decision people get wrong

Do not run both routers against the same URL. They will fight over `location` and you will
get double navigations and lost history entries.

Pick one:
- **Keep the AngularJS router until the end** (simplest). Angular components mount inside
  AngularJS routes as downgraded directives.
- **Hand specific paths to the Angular router** using the router's `UrlHandlingStrategy` to
  declare which URLs Angular owns and which it must ignore.

Switching routers and migrating components in the same PR is how migrations stall.

## Interop failures and what they mean

| Symptom | Cause |
|---|---|
| `$digest already in progress` | Angular code called into AngularJS outside the digest; use `$applyAsync` or let ngUpgrade's zone integration drive it |
| Angular view does not update from an AngularJS callback | The change ran outside Angular's zone — re-enter via `NgZone.run()` |
| Works in dev, DI fails in prod | Implicit DI annotation lost to minification — this is what `strictDi: true` catches |
| Two instances of one service | The service was bridged in both directions |
| Double navigation / lost history | Both routers are handling the same URL |

## Porting patterns

- Controller + `$scope` → component class with fields; `$scope.x = v` becomes `this.x = v`.
- Directive with isolate scope → component: `scope: { user: '=' }` → `@Input() user`,
  `onDelete: '&'` → `@Output() delete = new EventEmitter<void>()`.
- `$http` → `HttpClient`. Note the semantic change: `$http` returns a **promise** (eager,
  one shot), `HttpClient` returns a **cold Observable** that does nothing until subscribed
  and re-fires the request on every subscribe. Code that subscribed twice to "reuse" a
  response now issues two requests.
- `ng-model` form → prefer **reactive forms** (`FormBuilder`/`formControlName`) over
  template-driven; validation becomes testable without a DOM.
- Type as you port. Carrying `any` across the boundary forfeits the main reason to migrate.

## Exit criteria

Migration is done when `@angular/upgrade` and `angular` are removed from `package.json`,
not when the last component is converted. Until both are gone you are still shipping two
frameworks. Delete the hybrid bootstrap, drop back to a normal (or standalone) bootstrap,
and re-check bundle size — the drop is the deliverable to report.
