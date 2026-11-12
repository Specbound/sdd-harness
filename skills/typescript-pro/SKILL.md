---
name: typescript-pro
description: TypeScript expert for advanced types, generics, strict config, monorepo/build performance, and migration strategies. Use for TS architecture, type-safety hardening, complex typing/inference problems, or diagnosing slow builds and type checks.
---

# TypeScript Pro

## Use this skill when
- Designing TypeScript architectures or shared types
- Solving complex typing, generics, or inference issues
- Hardening type safety for production systems
- Diagnosing slow type checking/builds or migrating JS→TS

## Do not use this skill when
- You only need JavaScript guidance (use javascript-pro)
- You cannot enforce TypeScript in the build pipeline
- You need UI/UX design rather than type design

## Workflow
1. Detect project setup before changing config: `npx tsc --version`, `node -v`, check `package.json` deps for biome/eslint/prettier/vitest/jest/nx/turbo, and check for `pnpm-workspace.yaml`/`lerna.json`/`nx.json`/`turbo.json` (monorepo).
2. Match existing import style (absolute vs relative), respect existing `baseUrl`/`paths`, prefer existing project scripts over raw `tsc`. In monorepos, consider project references before broad tsconfig changes.
3. Apply the narrowest fix for the problem category (see Error Patterns below) rather than a broad rewrite.
4. Validate with one-shot commands only — never watch/serve processes:
   ```bash
   npm run -s typecheck || npx tsc --noEmit
   npm test -s || npx vitest run --reporter=basic --no-watch
   npm run -s build   # only if build affects outputs/config
   ```

## Strict Config Baseline
Reference: `references/tsconfig-strict.json` for a full strict ESM config (paths, lib, decorators commented).
```json
{
  "strict": true,
  "noUncheckedIndexedAccess": true,
  "noImplicitOverride": true,
  "exactOptionalPropertyTypes": true,
  "noPropertyAccessFromIndexSignature": true,
  "noFallthroughCasesInSwitch": true
}
```
- `skipLibCheck: true` for large projects (speeds up checking; can mask app typing issues if overused)
- `incremental: true` + `.tsbuildinfo` cache; precise `include`/`exclude`
- Monorepos: project references with `composite: true`, `declaration: true`, `declarationMap: true`

## Type-Level Programming Patterns
**Branded/nominal types** — prevent primitive obsession at domain boundaries:
```typescript
type Brand<K, T> = K & { __brand: T };
type UserId = Brand<string, 'UserId'>;
function processOrder(orderId: OrderId, userId: UserId) {}
```
**Recursive/conditional types** — cap recursion depth (~10 levels) to avoid instantiation errors:
```typescript
type DeepReadonly<T> = T extends (...args: any[]) => any ? T
  : T extends object ? { readonly [K in keyof T]: DeepReadonly<T[K]> } : T;
```
**Inference**: `satisfies` (TS 5+) validates constraints while preserving literal types; `as const` for literal inference from arrays/objects.

## Common Error Patterns → Fixes
| Error | Fix priority |
|---|---|
| "Inferred type of X cannot be named" | Export the type explicitly → `ReturnType<typeof fn>` → break circular deps with type-only imports |
| "Excessive stack depth comparing types" | Limit recursion in conditional types → prefer `interface extends` over intersections → simplify generic constraints |
| "Type instantiation is excessively deep" | Replace intersections with interfaces; split unions >100 members; avoid circular generic constraints |
| Missing type declarations | Add `types/ambient.d.ts` with `declare module 'pkg' { ... }` |
| "Cannot find module" despite file existing | Check `moduleResolution` matches bundler; verify `baseUrl`/`paths`; in monorepos ensure `workspace:*`; clear `.tsbuildinfo`/cache |
| TS `paths` not resolving at runtime | Paths are compile-time only — use `tsx`, `ts-node -r tsconfig-paths/register`, or pre-compile with resolved paths for prod |

## Performance Diagnostics
```bash
npx tsc --extendedDiagnostics --incremental false | grep -E "Check time|Files:|Nodes:"
npx tsc --generateTrace trace --incremental false   # then analyze-trace if installed
npx tsc --traceResolution > resolution.log 2>&1     # module resolution issues
node --max-old-space-size=8192 node_modules/typescript/lib/tsc.js  # memory issues
```

## Migration (JS → TS)
1. Enable `allowJs` + `checkJs` in existing tsconfig (don't replace the file).
2. Rename files gradually (`.js` → `.ts`); type file by file.
3. Enable strict-mode flags one at a time, not all at once.
4. Optional tooling: `ts-migrate migrate . --sources 'src/**/*.js'`, `typesync` (missing `@types`).

## Monorepo & Tooling Decisions
- **Turborepo** if simple structure, speed matters, <20 packages. **Nx** if complex dependencies, need visualization/plugins, or >50 packages.
- **Biome**: faster, single lint+format tool, ~64 TS rules, TypeScript-first — but no type-aware linting and limited Vue/Angular support. Stick with **ESLint + typescript-eslint** for type-aware rules or complex custom rules.
- Type testing: Vitest `expectTypeOf` (preferred) or `tsd` for library publishing / generic-heavy APIs.

## Code Review Checklist
- No implicit `any`; strict null checks handled; `as` assertions justified and minimal
- Discriminated unions for errors; exhaustive `switch` using `never`
- `interface` over `type` for object shapes (better error messages); const assertions for literals
- No circular deps; consistent ESM/CJS; dynamic imports for code splitting
- Type complexity doesn't slow compilation (no deep mapped types in hot paths)

## ESM-First Setup
- `"type": "module"` in `package.json`; `.mts` for explicit TS ESM files
- `"moduleResolution": "bundler"` for modern bundlers
- CJS interop: `const pkg = await import('cjs-package')`, often `.default` depending on export shape

## References
- `references/tsconfig-strict.json` — drop-in strict ESM tsconfig
- [TypeScript Wiki Performance](https://github.com/microsoft/TypeScript/wiki/Performance)
- [Type Challenges](https://github.com/type-challenges/type-challenges)
</content>
