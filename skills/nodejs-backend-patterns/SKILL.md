---
name: nodejs-backend-patterns
description: Node.js backend architecture and decision-making for framework selection, layered architecture, middleware, error handling, validation, and security. Use when building REST/GraphQL APIs, microservices, or choosing between Express/Fastify/Hono/NestJS.
---

# Node.js Backend Patterns

Decision-making principles for Node.js backends, not a fixed template — ask about stack preference when unclear, choose based on context, don't default to the same framework every time.

## Use this skill when
- Building REST/GraphQL APIs or microservices
- Implementing auth, middleware, or error handling
- Integrating SQL/NoSQL databases
- Choosing a framework or runtime for a new service

## Framework Selection (decision tree)
```
Edge/serverless (Cloudflare, Vercel)     → Hono (zero-dep, fastest cold start)
High-performance API                     → Fastify (2-3x faster than Express)
Enterprise / team wants structure         → NestJS (DI, decorators, opinionated)
Legacy / maximum ecosystem                → Express (most middleware, mature)
Full-stack frontend-coupled               → Next.js API routes or tRPC
```
| Factor | Hono | Fastify | Express |
|---|---|---|---|
| Best for | Edge, serverless | Performance | Legacy, learning |
| Cold start | Fastest | Fast | Moderate |
| TypeScript | Native | Excellent | Good |

Ask: what's the deployment target? Is cold-start time critical? Does the team have existing experience? Is this legacy code to maintain?

## Runtime & Module System
- Node 22+: `--experimental-strip-types` runs `.ts` directly — fine for scripts/simple APIs, not a replacement for a build step on larger projects.
- ESM (`import`/`export`) for new projects — better tree-shaking, async loading. CommonJS (`require`) only for legacy compat or packages without ESM support.
- Runtime choice: Node (largest ecosystem) vs Bun (perf, built-in bundler) vs Deno (security-first, built-in TS) — pick based on deployment target and ecosystem needs, not novelty.

## Layered Architecture
```
Controller/Route  → HTTP specifics, input validation at the boundary, calls service
Service           → business logic, framework-agnostic, calls repository
Repository        → data access only, DB queries/ORM
```
Testability (mock layers independently), flexibility (swap DB without touching business logic), clarity (single responsibility per layer). Skip the ceremony for small scripts/prototypes — ask "will this grow?"

```typescript
// Repository + Service + Controller pattern (full example: resources/implementation-playbook.md)
export class UserService {
  constructor(private userRepository: UserRepository) {}
  async createUser(data: CreateUserDTO): Promise<User> {
    if (await this.userRepository.findByEmail(data.email)) throw new ValidationError('Email already exists');
    const hashed = await bcrypt.hash(data.password, 10);
    const user = await this.userRepository.create({ ...data, password: hashed });
    const { password, ...safe } = user;
    return safe as User;
  }
}
```

## Error Handling
Custom error hierarchy + a single global handler, never leak internals:
```typescript
export class AppError extends Error {
  constructor(public message: string, public statusCode = 500, public isOperational = true) {
    super(message);
    Error.captureStackTrace(this, this.constructor);
  }
}
export class NotFoundError extends AppError { constructor(m = 'Resource not found') { super(m, 404); } }
export class ValidationError extends AppError { constructor(m: string, public errors?: unknown[]) { super(m, 400); } }

export const errorHandler = (err: Error, req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof AppError) return res.status(err.statusCode).json({ status: 'error', message: err.message });
  logger.error({ error: err.message, stack: err.stack, url: req.url });
  res.status(500).json({ status: 'error', message: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message });
};
// Wrap async route handlers so rejections reach errorHandler
export const asyncHandler = (fn: RequestHandler) => (req: Request, res: Response, next: NextFunction) =>
  Promise.resolve(fn(req, res, next)).catch(next);
```
| Status | When |
|---|---|
| 400 | Client sent invalid data |
| 401 / 403 | No/invalid auth vs valid auth but not allowed |
| 404 | Resource doesn't exist |
| 409 | Duplicate / state conflict |
| 422 | Schema valid but business rule fails |
| 500 | Our fault — log everything, don't expose details |

## Middleware Essentials
- **Auth**: verify JWT signature + expiry on every protected route; attach `req.user`; separate `authorize(...roles)` for permission checks.
- **Validation**: validate at the API boundary with Zod/Valibot/ArkType before touching services; return field-level errors, never trust "internal" data either.
- **Rate limiting**: `express-rate-limit` + Redis store for distributed limits; stricter window on auth endpoints (`skipSuccessfulRequests`).
- Security baseline: `helmet()`, `cors({ origin: allowlist })`, `compression()`, body size limits (`express.json({ limit: '10mb' })`).

## Async Patterns
| Pattern | Use when |
|---|---|
| `async/await` | sequential async ops |
| `Promise.all` | parallel, all must succeed |
| `Promise.allSettled` | parallel, partial failure OK |
| `Promise.race` | timeout or first-response-wins |

I/O-bound (DB, HTTP, fs, network) benefits from async. CPU-bound (crypto, image processing, heavy compute) does not — offload to worker threads. Never use sync methods (`fs.readFileSync`) in request-handling paths; stream large payloads instead of buffering.

## Validation Library Selection
| Library | Best for |
|---|---|
| Zod | TypeScript-first, strong inference |
| Valibot | Smaller bundle, tree-shakeable |
| ArkType | Performance-critical |
| Yup | Existing React Form usage |

## Security Checklist
- [ ] All inputs validated (body, query, params, headers, cookies)
- [ ] Parameterized queries only — no string-concatenated SQL
- [ ] Passwords hashed with bcrypt/argon2
- [ ] JWT signature + expiry always verified
- [ ] Rate limiting on public and especially auth endpoints
- [ ] Security headers (Helmet.js or equivalent), HTTPS everywhere, CORS explicitly scoped
- [ ] Secrets only via environment variables, never hardcoded
- [ ] Dependencies audited regularly

## Database Patterns
- PostgreSQL: `pg.Pool` with `max`, `idleTimeoutMillis`, `connectionTimeoutMillis` set explicitly; graceful shutdown via `pool.end()`.
- MongoDB: Mongoose with `maxPoolSize`, `serverSelectionTimeoutMS`; handle `disconnected`/`error` connection events.
- Dependency injection: a small container (`register`/`resolve`/`singleton`) keeps repositories/services testable without a framework.

## Testing
| Type | Tools |
|---|---|
| Unit | `node:test`, Vitest |
| Integration | Supertest |
| E2E | Playwright |

Priority order: critical paths (auth, payments, core business) → edge cases (empty inputs, boundaries) → error handling. Skip testing framework code and trivial getters. Node 22+ built-in runner: `node --test src/**/*.test.ts` needs no extra dependency.

## Anti-Patterns
- Defaulting to Express for new edge/serverless projects (prefer Hono)
- Sync methods in production request paths
- Business logic in controllers instead of services
- Skipping input validation "because it's internal"
- Hardcoded secrets
- Blocking the event loop with CPU work instead of offloading

## Resources
- `resources/implementation-playbook.md` — full Express/Fastify setup, complete controller/service/repository classes, DI container, and middleware code.
</content>
