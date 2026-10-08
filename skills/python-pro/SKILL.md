---
name: python-pro
description: Python 3.12+ expert for architecture decisions, async patterns, modern tooling (uv, ruff, pydantic), project scaffolding, and performance tuning. Use for framework selection, async-vs-sync tradeoffs, project structure, or production-readiness review.
---

# Python Pro

## Use this skill when
- Writing or reviewing Python 3.12+ codebases
- Choosing a framework, async strategy, or project structure
- Scaffolding a new FastAPI/Django/library/CLI project
- Profiling or optimizing for latency/memory

## Do not use this skill when
- You need a non-Python stack
- You only need basic syntax tutoring
- You need FastAPI-specific routing/DI depth (see fastapi-pro)

## Decision-making, not defaults
Ask about framework/async preference when unclear instead of defaulting to the same stack every time. Choose based on *this* context.

## Framework Selection
```
API-first / microservices / AI-ML serving → FastAPI (async, Pydantic, uvicorn)
Full-stack web / CMS / admin-heavy         → Django (batteries-included, admin, ORM)
Simple script / learning / minimal         → Flask
Background workers                         → Celery (+ any framework)
```
| Factor | FastAPI | Django | Flask |
|---|---|---|---|
| Best for | APIs, microservices | Full-stack, CMS | Simple, learning |
| Async | Native | 5.0+ (partial ORM) | Via extensions |
| Admin UI | Manual | Built-in | Via extensions |
| ORM | Bring your own | Django ORM | Bring your own |

Ask: API-only or full-stack? Need an admin UI? Is the team async-fluent? What's the existing infra?

## Async vs Sync — the golden rule
**I/O-bound → async** (waiting on network/DB/file). **CPU-bound → sync + multiprocessing** (computing). Don't mix carelessly: never call a sync/blocking library from inside an async function without a thread offload (`asyncio.to_thread`), and don't force CPU-bound work into async for no benefit.

| Need | Async library |
|---|---|
| HTTP client | httpx |
| PostgreSQL | asyncpg |
| Redis | redis-py (async mode) |
| File I/O | aiofiles |
| ORM | SQLAlchemy 2.0 async, Tortoise |

In FastAPI specifically: `async def` for async drivers/HTTP calls/I/O; plain `def` for blocking or CPU-bound work — FastAPI runs sync `def` handlers in a threadpool automatically.

## Type Hints Strategy
Type: function parameters, return types, class attributes, public APIs. Can skip: local variables (let inference work), one-off scripts, most test bodies.
```python
def find_user(id: int) -> User | None: ...
def process(data: str | dict) -> None: ...
def get_items() -> list[Item]: ...
def apply(fn: Callable[[int], str]) -> str: ...
```
Use Pydantic for: API request/response models, settings/config, runtime validation, serialization — it gives auto JSON schema and integrates natively with FastAPI.

## Project Structure
```
Small/script:  main.py, utils.py, requirements.txt
Medium API:    app/{main,models/,routes/,services/,schemas/}, tests/, pyproject.toml
Large app:     src/myapp/{core/,api/,services/,models/}, tests/, pyproject.toml
Library:       src/library_name/{__init__.py, py.typed, core.py}, tests/, pyproject.toml
```
Organize FastAPI/Django apps **by layer** (routes/services/models/schemas) for small-medium apps, **by feature** (users/, products/ each with routes.py/service.py/schemas.py) once the app grows past a handful of domains.

### Bootstrap with uv
```bash
uv init <project-name> && cd <project-name>
git init && printf ".venv/\n*.pyc\n__pycache__/\n.pytest_cache/\n.ruff_cache/\n" >> .gitignore
uv venv && source .venv/bin/activate
```
Minimal `pyproject.toml` additions:
```toml
[tool.ruff]
line-length = 100
target-version = "py312"
[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP"]
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
```
Library packaging uses `hatchling` build-backend + `src/` layout + `py.typed` marker for type-checker consumers. CLI tools: `[project.scripts] name = "pkg.cli:main"`, typically built on `typer` + `rich`.

`Makefile` convention: `install` (`uv sync`), `dev` (`uv run uvicorn ... --reload`), `test` (`uv run pytest -v`), `lint`/`format` (`uv run ruff check .` / `ruff format .`), `clean` (remove `__pycache__`, caches).

## Testing
| Type | Purpose | Tools |
|---|---|---|
| Unit | Business logic | pytest |
| Integration | API endpoints | pytest + httpx `AsyncClient` |
| E2E | Full workflows | pytest + real/test DB |

```python
@pytest.mark.asyncio
async def test_endpoint():
    async with AsyncClient(app=app, base_url="http://test") as client:
        response = await client.get("/users")
        assert response.status_code == 200
```
Common fixtures: `db_session`, `client`, `authenticated_user`, `sample_data`. Use Hypothesis for property-based testing on pure functions; `pytest-benchmark` for perf regressions.

## Error Handling Philosophy
Raise domain exceptions in services → catch and transform at the boundary (exception handlers) → client gets a consistent error shape: `{code, message, details?}` — never leak stack traces or internals in the response.

## Background Tasks
| Solution | Best for |
|---|---|
| FastAPI `BackgroundTasks` | quick, in-process, fire-and-forget, no persistence needed |
| Celery | distributed, complex workflows, retry logic, persistent queue |
| ARQ | async, Redis-based |
| Dramatiq | actor-based, simpler than Celery |

## Performance
- Profile before optimizing: `cProfile`, `py-spy` (sampling, prod-safe), `memory_profiler`.
- Cache with `functools.lru_cache` for pure functions; external cache (Redis) for cross-process.
- `concurrent.futures`/`multiprocessing` for CPU-bound; async for I/O-bound — don't swap these.
- Watch for N+1 queries: `select_related()` for FKs, `prefetch_related()` for M2M (Django); eager loading equivalents in SQLAlchemy.

## Anti-Patterns
- Defaulting to the same framework regardless of context
- Using sync libraries/drivers inside async code paths without offloading
- Skipping type hints on public APIs
- Business logic in routes/views instead of services
- Ignoring N+1 queries
- `JSON.parse(JSON.stringify())`-style hacks for deep copy (Python equivalent: manual recursive copy instead of `copy.deepcopy`)

## Decision Checklist
- [ ] Framework chosen for *this* context, not by default
- [ ] Async vs sync decided deliberately
- [ ] Type hint strategy set for public surfaces
- [ ] Project structure matches project size
- [ ] Error handling and response shape defined
- [ ] Background task strategy chosen if needed
</content>
