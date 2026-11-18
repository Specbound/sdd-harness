# Documentation templates

## readme

```markdown
# Project Name

Brief description of what this does and who it's for. 2-3 sentences max.

## Key Features
- Feature 1
- Feature 2

## Tech Stack
- **Language**: ...
- **Framework**: ...
- **Database**: ...
- **Deployment**: ...

## Prerequisites
- Tool/runtime versions needed before starting

## Getting Started
```bash
git clone <repo>
cd <repo>
<install deps>
cp .env.example .env
<db setup>
<run dev server>
```

## Architecture
```
src/
├── ...          # one line per top-level dir, what it holds
```

## Environment Variables
| Variable | Description | Required | Default |
|---|---|---|---|
| DATABASE_URL | Connection string | Yes | - |

## Available Scripts
| Command | Description |
|---|---|
| `npm run dev` | Start dev server |

## Testing
```bash
npm test
```

## Deployment
<platform-specific steps, detected from repo config>

## Troubleshooting
**Error:** `<message>`
**Solution:** <fix>
```

## api-endpoint

```markdown
## Create User

Creates a new user account.

**Endpoint:** `POST /api/v1/users`
**Authentication:** Required (Bearer token)

**Request Body:**
\`\`\`json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "John Doe"
}
\`\`\`

**Success Response (201 Created):**
\`\`\`json
{ "id": "usr_123", "email": "user@example.com", "name": "John Doe", "createdAt": "2026-01-20T10:30:00Z" }
\`\`\`

**Error Responses:**
- `400 Bad Request` — invalid input, with `{"error": "VALIDATION_ERROR", "message": "...", "field": "email"}`
- `409 Conflict` — `{"error": "EMAIL_EXISTS", "message": "..."}`
- `401 Unauthorized` — missing/invalid token

**Example (curl):**
\`\`\`bash
curl -X POST https://api.example.com/api/v1/users \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"SecurePass123!","name":"John Doe"}'
\`\`\`

**Example (JavaScript):**
\`\`\`javascript
const res = await fetch('https://api.example.com/api/v1/users', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password, name }),
});
const user = await res.json();
\`\`\`
```

## openapi-skeleton

```yaml
openapi: 3.1.0
info:
  title: My API
  version: 1.0.0
  description: |
    ${DESCRIPTION}
servers:
  - url: https://api.example.com/v1
security:
  - bearerAuth: []
paths:
  /users:
    get:
      summary: List all users
      operationId: listUsers
      parameters:
        - name: page
          in: query
          schema: { type: integer, default: 1 }
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items: { $ref: '#/components/schemas/User' }
components:
  schemas:
    User:
      type: object
      required: [id, email]
      properties:
        id: { type: string, format: uuid }
        email: { type: string, format: email }
  securitySchemes:
    bearerAuth: { type: http, scheme: bearer, bearerFormat: JWT }
```

## changelog (Keep a Changelog)

```markdown
# Changelog

## [Unreleased]
### Added
- New feature

## [1.0.0] - 2026-01-01
### Added
- Initial release
### Changed
- Updated dependency
### Fixed
- Bug fix
```

## adr

```markdown
# ADR-001: Title

## Status
Accepted / Deprecated / Superseded

## Context
Why are we making this decision?

## Decision
What did we decide?

## Consequences
What are the trade-offs?
```

## llms.txt

```markdown
# Project Name
> One-line objective.

## Core Files
- [src/index.ts]: Main entry
- [src/api/]: API routes
- [docs/]: Documentation

## Key Concepts
- Concept 1: Brief explanation
- Concept 2: Brief explanation
```
