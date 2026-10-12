---
name: fastapi-pro
description: FastAPI expert for async-first REST APIs — layered architecture (router/service/repository), SQLAlchemy 2.0 async, Pydantic V2, JWT auth, and pytest-asyncio testing. Use when building endpoints, CRUD routers, auth, or reviewing FastAPI architecture/performance.
---

# FastAPI Pro

If the API's purpose, auth requirements, or Python version is ambiguous, ask one question. Otherwise: start from the Pydantic models and OpenAPI schema, implement async-first, validate with Pydantic V2, and include at least one working pytest example per endpoint.

## Use this skill when
- Building REST endpoints, CRUD routers, or microservices with FastAPI
- Implementing JWT/OAuth2 auth, async SQLAlchemy, or WebSockets
- Reviewing FastAPI code for async correctness or layering
- Writing pytest-asyncio tests for API endpoints

## Do not use this skill when
- The task is unrelated to FastAPI/async Python APIs
- General Python architecture guidance without a framework is needed (see python-pro)

## Project Structure
```
app/
├── api/v1/endpoints/{users,auth,items}.py   # routers
├── api/dependencies.py                       # shared Depends
├── core/{config,security,database}.py
├── models/            # SQLAlchemy models
├── schemas/           # Pydantic schemas
├── services/           # business logic
├── repositories/        # data access
└── main.py
```
Keep business logic out of routes (service layer), keep data access out of services (repository layer) — each layer is independently testable and mockable.

## App Entry & Config
```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    yield
    await database.disconnect()

app = FastAPI(title="API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(api_router, prefix="/api/v1")
```
```python
# core/config.py
class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    class Config: env_file = ".env"

@lru_cache()
def get_settings() -> Settings: return Settings()
```
```python
# core/database.py — async session dependency with commit/rollback
async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
```

## Repository Pattern (generic base)
```python
class BaseRepository(Generic[ModelType, CreateSchemaType, UpdateSchemaType]):
    def __init__(self, model: Type[ModelType]): self.model = model
    async def get(self, db: AsyncSession, id: int) -> ModelType | None:
        return (await db.execute(select(self.model).where(self.model.id == id))).scalars().first()
    async def get_multi(self, db: AsyncSession, skip=0, limit=100) -> list[ModelType]:
        return (await db.execute(select(self.model).offset(skip).limit(limit))).scalars().all()
    async def create(self, db: AsyncSession, obj_in: CreateSchemaType) -> ModelType:
        db_obj = self.model(**obj_in.dict()); db.add(db_obj); await db.flush(); await db.refresh(db_obj)
        return db_obj
    async def update(self, db: AsyncSession, db_obj: ModelType, obj_in: UpdateSchemaType) -> ModelType:
        for field, value in obj_in.dict(exclude_unset=True).items(): setattr(db_obj, field, value)
        await db.flush(); await db.refresh(db_obj)
        return db_obj
```
Subclass per resource (`UserRepository(BaseRepository[User, UserCreate, UserUpdate])`) and add resource-specific queries (`get_by_email`, etc).

## Service Layer
Owns business rules the repository shouldn't know about — e.g. rejecting a duplicate email, hashing a password before create, re-hashing on update only if a new password was supplied. Routes call services; services call repositories; repositories never leak into routes.

## Router Patterns
```python
# Optional auth - None if not authenticated; required auth - 401 if missing
current_user: Optional[User] = Depends(get_current_user)
current_user: User = Depends(get_current_user_required)

@router.get("/items/{item_id}", response_model=Item)
async def get_item(item_id: str) -> Item: ...
@router.post("/items", status_code=status.HTTP_201_CREATED)
@router.delete("/items/{id}", status_code=status.HTTP_204_NO_CONTENT)
```
Integration steps for a new resource: router in `api/v1/endpoints/`, mount in `main.py`, Pydantic schemas, service layer if there's real logic, then frontend API functions if needed.
Raise `HTTPException(status_code=400/403/404, detail=...)` from the route after the service signals failure (`ValueError`, `None` return, etc.) — don't let repository exceptions leak raw to the client.

## Auth & Security
```python
# core/security.py
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
def verify_password(plain, hashed) -> bool: return pwd_context.verify(plain, hashed)
def get_password_hash(password) -> str: return pwd_context.hash(password)
def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    to_encode.update({"exp": datetime.utcnow() + (expires_delta or timedelta(minutes=15))})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm="HS256")
```
```python
# api/dependencies.py
oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")
async def get_current_user(db: AsyncSession = Depends(get_db), token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    except JWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Could not validate credentials", headers={"WWW-Authenticate": "Bearer"})
    return await user_repository.get_by_email(db, payload.get("sub"))
```
Always verify JWT signature and expiry; never trust a decoded payload without the `except JWTError` guard. CORS, rate limiting, and input validation (Pydantic) sit at the same boundary — never inside services.

## Async Discipline
- `async def` for DB/HTTP/I-O-bound handlers; plain `def` for CPU-bound work (FastAPI runs it in a threadpool automatically).
- Never call a sync/blocking driver from an async handler — use the async variant (asyncpg, aiomysql, Motor) or `run_in_executor`.
- Connection pooling: configure pool size on the engine, not per-request.

## Testing
```python
# conftest.py — in-memory async DB + dependency override
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest.fixture
async def client(db_session):
    async def override_get_db(): yield db_session
    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client

@pytest.mark.asyncio
async def test_create_user(client):
    response = await client.post("/api/v1/users/", json={"email": "t@x.com", "password": "pw", "name": "T"})
    assert response.status_code == 201
```
Test each layer independently where it matters (repository against a real/in-memory DB, service with a mocked repository, router via `AsyncClient`).

## Common Pitfalls
- Blocking code in async handlers (sync DB drivers, `requests` instead of `httpx`)
- No service layer — business logic leaking into routes
- Missing type hints — loses Pydantic/OpenAPI generation benefits
- Not managing DB sessions properly (missing commit/rollback/close)
- Tight coupling — routes querying the DB directly instead of going through a repository
- Skipping integration tests and relying on unit tests alone

## Stack & Quality Gates
Typical stack: FastAPI, Python 3.11+, SQLAlchemy 2.0 (async), Pydantic v2, PostgreSQL, Alembic migrations, JWT/OAuth2, pytest.
Before shipping: tests passing (>80% coverage), mypy clean, ruff/black clean, OpenAPI docs complete, security scan passed, performance benchmarks met.

## Resources
- `resources/implementation-playbook.md` — full worked examples (complete app, repository/service/router layers, auth, test fixtures).
</content>
