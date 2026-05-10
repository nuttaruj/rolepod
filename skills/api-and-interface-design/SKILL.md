---
name: api-and-interface-design
description: Design stable APIs and module boundaries that survive change. Apply when creating REST/GraphQL endpoints, RPC methods, public package exports, or internal module interfaces. Covers naming, versioning, error shape, idempotency, evolution.
---

# API and Interface Design

Every interface is a promise. Cheap to make, expensive to break. This skill helps you design promises you can keep — for HTTP endpoints, gRPC services, package exports, or just a function signature another module will call.

## When to use

- Creating a new public endpoint or RPC method
- Adding a new exported function/type to a shared package
- Defining a queue message shape, event payload, or webhook contract
- Splitting a module — what does each side expose to the other?
- Reviewing a PR that changes an existing API
- About to break backwards compatibility (read this first, twice)

## How to apply

### 1. Identify the audience

| Audience | Stability bar |
|----------|---------------|
| External customers / partners | Highest — semver, deprecation cycle, migration guide |
| Other teams in same org | High — versioned, deprecation notice |
| Other modules in same service | Medium — coordinated change OK |
| Internal helpers (same module) | Low — change freely |

Higher stability = more design effort upfront.

### 2. Design the resource model first

For REST: nouns (resources), not verbs. Methods (`GET`, `POST`, `PATCH`, `DELETE`) supply the verb.

```
GOOD: POST /orders, GET /orders/{id}, PATCH /orders/{id}/status
BAD:  POST /createOrder, POST /getOrder, POST /updateOrderStatus
```

For RPC / GraphQL: verbs are fine, but pick consistent naming (`createX`, `updateX`, `deleteX` — not `makeX`, `modifyX`, `removeX`).

### 3. Request/response shape

- **Required vs optional** — be explicit. Optional fields default to omitted, not `null`, unless `null` carries meaning.
- **No flat sentinel values** — return structured errors, not `-1` or `""`.
- **Pagination** — cursor-based for stable lists, offset for finite/cacheable ones. Pick before launch; switching later is painful.
- **Timestamps** — ISO 8601 UTC, always. Include timezone in the field name only if it varies.
- **IDs** — opaque strings. Even if it's a number internally, expose as string to allow future migration.

### 4. Errors

Standard shape. Pick once, use everywhere:

```json
{
  "error": {
    "code": "rate_limited",
    "message": "Too many requests; retry after 30s",
    "details": { "retry_after_seconds": 30 }
  }
}
```

- `code` is machine-readable (snake_case, stable)
- `message` is human-readable (can change wording)
- `details` is structured per-code

HTTP status: use the standard codes (400, 401, 403, 404, 409, 422, 429, 500, 503). Don't invent.

### 5. Idempotency

Mutating endpoints that clients might retry → support an idempotency key:

```
POST /payments
Idempotency-Key: <client-generated-uuid>
```

Server stores `key → response` for some retention window. Same key returns same response without re-executing. Prevents double-charges from network blips.

### 6. Versioning

Pick a strategy and stick with it:

| Strategy | Where | Tradeoff |
|----------|-------|----------|
| URL path | `/v1/orders` | Visible, easy to route, ugly URLs |
| Header | `Api-Version: 2024-01-15` | Clean URLs, less discoverable |
| Date-based | `2024-01-15` | Stripe-style, encodes change-set |

Breaking change = new version. Additive changes (new optional field, new endpoint) don't need a version bump.

### 7. Evolution rules

Safe additions:
- New endpoint
- New optional request field
- New response field (consumers must ignore unknown fields)
- New error code (consumers must handle unknown codes gracefully)

Breaking changes (require new version + deprecation):
- Removing a field
- Renaming a field
- Tightening a type (string → enum)
- Changing semantics of an existing field
- Making an optional field required

### 8. Internal module interfaces

Same principles, lower ceremony. The function signature is the contract.

- Keep parameters narrow — pass what the function needs, not the world
- Return rich types, not booleans + side channels
- Errors are part of the signature (return `Result`, throw typed errors, document what throws)
- One responsibility per function — if you'd describe it as "does X and Y", split

## Common mistakes

- Returning HTTP 200 with `{"success": false}` — use the right status code
- Inventing a new error shape per endpoint — pick one, reuse
- Bool flags that should be enums (`{ status: "draft" | "published" | "archived" }` beats `{ isDraft, isPublished }`)
- Embedding huge objects when a reference would do (paginate, link, or expand on request)
- Public field name leaks DB column name (`user_id_fk` — pick a clean external name)
- Versioning by `/api2/` then `/api3/` with no deprecation plan
- Idempotency only on some mutations — clients can't tell which
- Returning different shapes for the same endpoint based on query param

## Quick reference

| Decision | Default |
|----------|---------|
| Resource naming | Plural nouns |
| ID format | Opaque string |
| Time format | ISO 8601 UTC |
| Error shape | `{ error: { code, message, details } }` |
| Pagination | Cursor for live data, offset for finite |
| Auth | Bearer token in `Authorization` header |
| Mutations | Support `Idempotency-Key` |
| Versioning | URL path or date header — pick one |

## Before shipping the API

- [ ] Documented (OpenAPI / SDL / typed exports)
- [ ] Examples for each endpoint
- [ ] Error codes enumerated
- [ ] Rate limits stated
- [ ] Deprecation policy documented
- [ ] Backwards compatibility strategy decided
