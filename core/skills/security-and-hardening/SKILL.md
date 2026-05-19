---
name: security-and-hardening
description: Compatibility shim — security review and hardening now lives in `review-code`; depth lives in the `security-engineer` agent.
when_to_use: when handling untrusted input, building auth flows, persisting sensitive data, calling external services, or auditing existing code for vulnerabilities
tier: 3
redirect_to: review-code
---

# security-and-hardening

Compatibility shim. Security review now lives inside **`review-code`**; the `security-engineer` agent adds depth when installed.

→ Open `core/skills/review-code/SKILL.md` and follow that instead. Brief `security-engineer` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `review-code` is not available

Minimum viable fallback:

1. Validate every input at the boundary; trust no client-supplied data
2. Auth check at every endpoint — not just the first one in the module
3. Secrets never appear in logs, error messages, or stack traces
4. SSRF: allowlist URLs; never let user-controlled URL hit internal network
5. Injection: parameterize SQL, escape shell args, encode HTML output
6. Token / cookie: set `HttpOnly`, `Secure`, `SameSite` appropriately
7. Cryptographic primitives: use stdlib / well-known library, never roll your own
