---
name: security-and-hardening
description: Defend code against real-world abuse. Use when handling untrusted input, building auth flows, persisting sensitive data, calling external services, or auditing existing code for vulnerabilities.
---

# Security and Hardening

Most breaches = small set of repeated mistakes: trust where you shouldn't, missing checks at boundaries, secrets in wrong place.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER trust input crossing a boundary (HTTP, queue, file, env) without validation at that boundary. Internal layers may then trust the type.
2. NEVER log secrets, tokens, full credit cards, PII, raw passwords. Once in logs = compromised.
3. ALWAYS check authorization at every endpoint touching tenant-scoped data. "Just this one place" auth bypass = data leak.

Breaches usually = these three ignored once.
</EXTREMELY-IMPORTANT>

## Red Flags

| Thought | Reality |
|---------|---------|
| "Endpoint is internal, no auth needed" | Internal = "I don't know who calls it yet". |
| "I'll validate downstream" | Downstream forgets. |
| "Logging this token helps debug" | Logs leak. Use redacted handle (last 4). |
| "User-supplied URL fine to fetch" | SSRF to internal network. Allowlist. |
| "Crypto is hard, I'll roll my own" | You'll get it wrong. Stdlib. |

## When to use

- New route taking user input
- Storing data tied to user identity
- Calling 3rd-party API on behalf of user
- Login, sessions, password reset, MFA
- Designing or changing permissions
- Reviewing PR touching above
- Post-incident hardening

## Threat model first (5 min)

1. **Attacker?** Random internet, logged-in user, insider, compromised dep
2. **Asset?** PII, money, content, account control, compute
3. **Boundary?** Where untrusted becomes trusted
4. **Blast radius?** One user, one tenant, all users, platform

## Boundary discipline

Every byte across a trust boundary: validated, normalized, bounded — once, at the boundary.

| Boundary | Defenses |
|----------|----------|
| HTTP → handler | Schema validation, size limits, content-type, rate limit |
| User input → DB | Parameterized queries; allowlist columns for ORDER BY |
| User input → shell | Don't. If must: argv array, no shell, allowlist binaries |
| Server → external URL (SSRF) | Allowlist hosts; resolve DNS, reject private/link-local; no internal redirects |
| Untrusted file → storage | Validate MIME, cap size, randomize name, outside webroot |
| Untrusted HTML → render | Escape by default; sanitize via allowlist if rich text needed |
| Deserialization | No pickle/native on user input. JSON with schema. |

## Auth — parts that go wrong

- **Authentication ≠ authorization.** Logged in ≠ allowed. Check both, every endpoint.
- **Object-level checks** — "user X owns row Y" enforced server-side, every time. URL guessing = #1 leak.
- **Session cookies** — `HttpOnly`, `Secure`, `SameSite=Lax` (or Strict), short idle timeout, server-side revocation.
- **Password storage** — Argon2id or bcrypt with real cost. Never SHA/MD5/unsalted.
- **Token leakage** — never log JWTs, refresh, OAuth codes. Treat URLs with tokens as secrets.
- **Reset flows** — single-use, time-bound, bound to requesting account, invalidate on use, rate-limit.
- **MFA** — TOTP or WebAuthn. SMS is fallback.

## Secrets and storage

- Secrets in platform secret manager. Not `.env` in repo. Not CI logs. Not error messages.
- Encryption at rest: provider disk encryption + app-level for high-sensitivity fields.
- TLS everywhere, internal too.
- Backups encrypted; restores tested.
- Logs scrubbed.

## External integrations

3rd-party = untrusted. Vendor compromise, behavior change, junk responses.

- Validate response shape
- Set timeouts and circuit breakers
- Don't echo opaque error strings to users
- Webhooks: verify signatures, replay-protect with timestamp + nonce, idempotent handlers
- Outbound URLs from user input → SSRF allowlist

## Common mistakes

- Client-only validation
- `X-Frame-Options` but no CSP
- API keys in localStorage
- Logging entire request body (incl. password)
- Trusting `req.user.id` from client JWT without verifying sig + expiry
- Auth check in 3 places, missed in 4th — centralize
- Sanitize-on-render instead of validate-on-input (different defense layer, not substitute)
- "Fix before launch" — security debt compounds

## Output format — security review

```
Severity: critical | high | medium | low
Class: [auth bypass / data leak / injection / SSRF / etc.]
Location: file:line
Reproduction: [minimal request demonstrating]
Impact: [what attacker gets]
Fix: [concrete change]
```

## Quick reference — 10 questions before merge

1. Every endpoint checks BOTH authentication AND authorization?
2. Every user-controlled string going to SQL parameterized?
3. Every user-controlled URL allowlisted?
4. Every user-controlled value HTML-escaped (or sanitized via allowlist)?
5. File uploads bounded by size, type, outside webroot?
6. Passwords hashed with Argon2id/bcrypt at real cost?
7. Session cookies `HttpOnly` + `Secure` + `SameSite`?
8. Secrets out of repo and logs?
9. Response avoids leaking stack traces/internal paths?
10. Rate-limiting on auth, reset, expensive endpoints?

Any "no" → block merge or document explicit risk acceptance.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "It's behind auth, attackers can't reach" | Auth bypass is one bug away. Defense-in-depth assumes any layer can fail. |
| "Simple change" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
