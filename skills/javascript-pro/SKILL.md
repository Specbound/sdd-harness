---
name: javascript-pro
description: JavaScript expert for ES6+, async/event-loop debugging, functional patterns, and Node.js/browser performance. Use for JS architecture, async race-condition bugs, legacy-to-modern migration, or explaining language quirks (coercion, `this`, hoisting).
---

# JavaScript Pro

## Use this skill when
- Building modern JavaScript for Node.js or browsers
- Debugging async behavior, event loops, race conditions, or performance
- Migrating legacy JS (callbacks, `var`, CJS) to modern ES standards
- Explaining a language quirk (coercion, `this`, hoisting, equality)

## Do not use this skill when
- You need TypeScript architecture guidance (use typescript-pro)
- You are working in a non-JS runtime
- The task requires backend framework/architecture decisions (use nodejs-backend-patterns)

## Approach
1. Identify runtime targets (Node version / browser matrix) and module system (ESM vs CJS).
2. Prefer `async/await` over raw promise chains; handle errors at the right boundary, not every layer.
3. Prefer functional, immutable patterns where they don't hurt readability; avoid gratuitous currying.
4. For browser code, consider bundle size and polyfill strategy before reaching for a new API.
5. Validate: run the test suite with async-aware assertions; profile before claiming a performance fix worked.

## Language Gotchas (the parts that bite)
| Thing | Gotcha |
|---|---|
| `==` vs `===` | `null == undefined` is `true`; always use `===` unless you have a specific reason |
| `Object.is` | `Object.is(NaN, NaN)` → `true` (unlike `NaN === NaN`); `Object.is(-0, 0)` → `false` (unlike `0 === -0`) |
| Falsy values (8 total) | `false, 0, -0, 0n, "", null, undefined, NaN` — `[]` and `{}` are truthy |
| `typeof null` | `"object"` — historical bug, not a type signal |
| `var` | function-scoped, hoisted, re-declarable, ignores block scope — avoid in new code |
| `let`/`const` hoisting | hoisted into a Temporal Dead Zone — accessing before declaration throws `ReferenceError`, not `undefined` |
| `this` in arrow fns | lexical — inherits enclosing `this`; breaks object-method shorthand if misused (`greet: () => this.name` is `undefined`) |
| `??` vs `\|\|` | `??` only falls through on `null`/`undefined`; `0 ?? 'd'` → `0`, but `0 \|\| 'd'` → `'d'` |
| `?.()` optional call | `user?.getName?.()` — guards both missing object and missing method |
| `const` objects | binding is immutable, contents are not — `const o={}; o.a=1` is legal |

## Event Loop Order
```javascript
console.log("1");
setTimeout(() => console.log("2"), 0);
Promise.resolve().then(() => console.log("3"));
console.log("4");
// Output: 1, 4, 3, 2 — microtasks (Promise/queueMicrotask) always drain before macrotasks (setTimeout/I/O)
```

## Async Patterns
**Promise combinators** — pick deliberately, they behave differently on partial failure:
```javascript
Promise.all(ps)        // rejects fast on first rejection
Promise.allSettled(ps) // always resolves; inspect { status, value|reason } per entry
Promise.race(ps)       // settles on first settle (success OR failure)
Promise.any(ps)        // resolves on first success; rejects only if all fail
```
**Retry + timeout wrappers** (common production need, not built in):
```javascript
async function fetchWithRetry(url, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try { return await fetch(url); }
    catch (err) {
      if (i === retries - 1) throw err;
      await new Promise(r => setTimeout(r, 1000 * (i + 1)));
    }
  }
}
function withTimeout(promise, ms) {
  const timeout = new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), ms));
  return Promise.race([promise, timeout]);
}
```
**Sequential vs parallel awaits** — `await a(); await b();` is sequential (slow); use `Promise.all([a(), b()])` when independent.
**Top-level await** (ES2022) works directly in ESM modules, no wrapping IIFE needed.

## Functional Patterns
```javascript
// Currying
const curry = fn => (...args) => args.length >= fn.length ? fn(...args) : (...more) => curry(fn)(...args, ...more);
// Compose / pipe
const compose = (...fns) => x => fns.reduceRight((acc, fn) => fn(acc), x);
const pipe    = (...fns) => x => fns.reduce((acc, fn) => fn(acc), x);
// Memoization
function memoize(fn) {
  const cache = new Map();
  return (...args) => {
    const key = JSON.stringify(args);
    if (cache.has(key)) return cache.get(key);
    const result = fn(...args);
    cache.set(key, result);
    return result;
  };
}
```
**Immutability**: prefer `[...arr, x]`, `arr.filter(...)`, `arr.map(...)`, `{...obj, k: v}` over mutation. Use `structuredClone(obj)` for deep clones (not the `JSON.parse(JSON.stringify())` hack — it drops `undefined`, functions, `Date` becomes a string, etc.).

## Modern Class & Module Features
```javascript
class User {
  #password;                 // private field — not accessible outside the class
  static count = 0;
  constructor(name, password) { this.name = name; this.#password = password; User.count++; }
  get displayName() { return this.name.toUpperCase(); }
}
```
- Dynamic imports: `const mod = await import('./feature.js')` for conditional/lazy loading.
- Named vs default export: prefer named exports for tree-shaking and refactor-safety; reserve default for a single obvious entry point.

## Callback Hell → Modern Replacement
Don't nest callbacks for sequential async work — convert to `async/await` with early returns and try/catch at the boundary that can actually handle the failure, not every intermediate function.

## Output Expectations
- Modern JS with explicit error handling (no swallowed rejections)
- Async code free of race conditions (state updates go through the resolved value, not closures captured before the `await`)
- Clean module boundaries (named exports, no circular imports)
- Tests cover async paths (resolved, rejected, timeout) — not just the happy path
- Note any polyfill/bundle-size tradeoffs for browser targets

## Resources
- [JavaScript.info](https://javascript.info/) — language reference
- [33 JS Concepts](https://github.com/leonardomso/33-js-concepts) — gotcha catalog
</content>
