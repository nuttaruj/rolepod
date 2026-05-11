---
name: api-and-interface-design
description: Design stable APIs and module boundaries that survive change. Apply when creating REST/GraphQL endpoints, RPC methods, public package exports, or internal module interfaces. Covers naming, versioning, error shape, idempotency, evolution.
---

# API and Interface Design

Every interface is a promise. Cheap to make, expensive to break.

## When to use

- New public endpoint / RPC method
- New exported function/type in shared package
- Queue message, event payload, webhook contract
- Splitting module — what does each side expose?
- Reviewing PR that changes existing API
- About to break backwards compatibility

## How to apply

### 1. Identify audience

| Audience | Stability bar |
|----------|---------------|
| External customers/partners | Highest — semver, deprecation, migration guide |
| Other teams same org | High — versioned, deprecation notice |
| Other modules same service | Medium — coordinated change OK |
| Internal helpers same module | Low — change freely |

### 2. Resource model first

REST: nouns, not verbs. Methods supply the verb.

```
GOOD: POST /orders, GET /orders/{id}, PATCH /orders/{id}/status
BAD:  POST /createOrder, POST /getOrder, POST /updateOrderStatus
```

RPC/GraphQL: verbs OK but consistent (`createX`/`updateX`/`deleteX`, not `makeX`/`modifyX`/`removeX`).

### 3. Request/response shape

- **Required vs optional** — explicit. Optional defaults to omitted, not `null`, unless `null` carries meaning.
- **No flat sentinels** — structured errors, not `-1` or `""`
- **Pagination** — cursor for live data, offset for finite/cacheable. Pick before launch.
- **Timestamps** — ISO 8601 UTC always
- **IDs** — opaque strings even if numeric internally

### 4. Errors

Standard shape, pick once:

```json
{
  "error": {
    "code": "rate_limited",
    "message": "Too many requests; retry after 30s",
    "details": { "retry_after_seconds": 30 }
  }
}
```

- `code` — machine-readable (snake_case, stable)
- `message` — human-readable (wording may change)
- `details` — structured per-code

HTTP status: standard codes (400, 401, 403, 404, 409, 422, 429, 500, 503). Don't invent.

### 5. Idempotency

Mutating endpoints clients may retry:

```
POST /payments
Idempotency-Key: <client-generated-uuid>
```

Server stores `key → response`. Same key → same response, no re-execute. Prevents double-charge.

### 6. Versioning

| Strategy | Where | Tradeoff |
|----------|-------|----------|
| URL path | `/v1/orders` | Visible, easy route, ugly URLs |
| Header | `Api-Version: 2024-01-15` | Clean URLs, less discoverable |
| Date-based | `2024-01-15` | Stripe-style, encodes change-set |

Breaking → new version. Additive (new optional field, new endpoint) → no bump.

### 7. Evolution rules

Safe additions:
- New endpoint
- New optional request field
- New response field (consumers ignore unknown)
- New error code (consumers handle unknown gracefully)

Breaking (new version + deprecation):
- Removing field
- Renaming field
- Tightening type (string → enum)
- Changing field semantics
- Optional → required

### 8. Internal module interfaces

Same principles, lower ceremony. Function signature is contract.

- Narrow parameters — pass what's needed, not the world
- Rich return types, not bool + side channels
- Errors part of signature (Result type / typed throws / documented)
- One responsibility — "does X and Y" → split

## Common mistakes

- HTTP 200 with `{"success": false}` — use right status
- New error shape per endpoint — pick one, reuse
- Bool flags that should be enums (`status: "draft"|"published"` beats `isDraft, isPublished`)
- Embedding huge objects when reference would do
- Public field leaks DB name (`user_id_fk`)
- `/api2/` then `/api3/` with no deprecation plan
- Idempotency only on some mutations
- Different shapes for same endpoint based on query param

## Quick reference

| Decision | Default |
|----------|---------|
| Resource naming | Plural nouns |
| ID format | Opaque string |
| Time format | ISO 8601 UTC |
| Error shape | `{ error: { code, message, details } }` |
| Pagination | Cursor live, offset finite |
| Auth | Bearer in `Authorization` header |
| Mutations | Support `Idempotency-Key` |
| Versioning | URL path or date header |

## Before shipping

- [ ] Documented (OpenAPI / SDL / typed exports)
- [ ] Examples per endpoint
- [ ] Error codes enumerated
- [ ] Rate limits stated
- [ ] Deprecation policy documented
- [ ] Backwards compat strategy decided

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Internal API, no stable contract needed" | Internal becomes external. Yesterday's `/admin/users` is today's mobile dep. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
