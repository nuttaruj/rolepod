---
name: security-and-hardening
description: Defend code against real-world abuse. Use when handling untrusted input, building auth flows, persisting sensitive data, calling external services, or auditing existing code for vulnerabilities.
---

# Security and Hardening

Most production breaches come from a small set of repeated mistakes: trust where you shouldn't, missing checks at boundaries, secrets in the wrong place. This skill is the checklist for the boundaries you cross every day.

## When to use

- Adding a route that takes user input
- Storing data tied to a user identity
- Calling a third-party API on behalf of a user
- Implementing login, sessions, password reset, MFA
- Designing or changing permission rules
- Reviewing a PR that touches any of the above
- After an incident — hardening the surface that broke

## Threat model first (5 minutes, not 5 hours)

Before writing code, answer:

1. **Who is the attacker?** Random internet, logged-in user, insider, compromised dependency.
2. **What's the asset?** PII, money, content, account control, compute.
3. **What's the boundary?** Where does untrusted data become trusted?
4. **What's the blast radius?** One user, one tenant, all users, the platform.

Two minutes of this beats two days of "we'll add validation later."

## Boundary discipline

Every byte that crosses a trust boundary gets validated, normalized, and bounded — once, at the boundary.

| Boundary | Defenses |
|----------|----------|
| HTTP request → handler | Schema validation, size limits, content-type check, rate limit |
| User input → DB query | Parameterized queries (never string concat), allowlist columns for `ORDER BY` |
| User input → shell/exec | Don't. If you must: argv array, no shell, allowlist binaries |
| Server → external URL (SSRF) | Allowlist hosts; resolve DNS, reject private/link-local; no redirects to internal |
| Untrusted file → storage | Validate MIME, cap size, randomize filename, store outside webroot |
| Untrusted HTML → render | Escape by default; sanitize only when rich text is required, with an allowlist |
| Deserialization | No pickle / native deserialize on user input. JSON with a schema. |

## Auth — the parts that go wrong

- **Authentication** ≠ **authorization**. Logged in is not the same as allowed. Check both at every endpoint.
- **Object-level checks** — "user X owns row Y" must be enforced server-side, every time. URL guessing is the #1 leak.
- **Session cookies** — `HttpOnly`, `Secure`, `SameSite=Lax` (or `Strict` where flows allow), short idle timeout, server-side revocation.
- **Password storage** — Argon2id or bcrypt with a real cost factor. Never SHA / MD5 / unsalted.
- **Token leakage** — never log JWTs, refresh tokens, OAuth codes. Treat URLs with tokens as secrets (don't email them, don't put in error pages).
- **Reset flows** — single-use, time-bound, bound to the requesting account, invalidate on use, rate-limit on request.
- **MFA** — TOTP or WebAuthn. SMS is a fallback, not a primary.

## Secrets and storage

- Secrets in the platform's secret manager. Not in `.env` in the repo. Not in CI logs. Not in error messages returned to users.
- Encryption at rest: enable provider-level disk encryption + app-level encryption for high-sensitivity fields (tokens, PII).
- TLS everywhere — internal too, if you cross a network you don't physically own.
- Backups encrypted. Restores tested. An untested backup is not a backup.
- Logs scrubbed: no full credit cards, no passwords, no tokens, no full session IDs.

## External integrations

Third-party = untrusted. The vendor can be compromised, change behavior, return junk.

- Validate response shape. Don't trust their JSON to match yesterday's schema.
- Set timeouts and circuit breakers. A hanging upstream becomes your outage.
- Don't echo opaque error strings to users.
- Webhooks: verify signatures, replay-protect with timestamp + nonce, idempotent handlers.
- Outbound URLs derived from user input → SSRF allowlist (above).

## Common mistakes

- Validating only on the client (attacker bypasses)
- Adding `X-Frame-Options` headers but missing CSP
- Storing API keys in localStorage "because it's convenient"
- Logging the entire request body for debugging — including the password field
- Trusting `req.user.id` from a client-supplied JWT without verifying signature + expiry
- Auth check in 3 places, missed in the 4th — centralize
- Sanitize-on-render instead of validate-on-input (different layer of defense, but not a substitute)
- "We'll fix it before launch" — security debt compounds; ship hardened or don't ship

## Output format — security review

When auditing code, report findings as:

```
Severity: critical | high | medium | low
Class: [auth bypass / data leak / injection / SSRF / etc.]
Location: file:line
Reproduction: [minimal request or input that demonstrates]
Impact: [what an attacker gets]
Fix: [concrete change, not "validate input"]
```

## Quick reference — the 10 questions before merge

1. Does every endpoint check both authentication AND authorization?
2. Is every user-controlled string going to SQL parameterized?
3. Is every user-controlled URL going to an HTTP client allowlisted?
4. Is every user-controlled value going to HTML escaped (or sanitized via allowlist)?
5. Are file uploads bounded by size, type, and stored outside the webroot?
6. Are passwords hashed with Argon2id/bcrypt at a real cost?
7. Are session cookies `HttpOnly` + `Secure` + `SameSite`?
8. Are secrets out of the repo and out of logs?
9. Does the response avoid leaking stack traces / internal paths to users?
10. Is rate-limiting in place on auth, password reset, and expensive endpoints?

Any "no" → block the merge or document the explicit risk acceptance.
