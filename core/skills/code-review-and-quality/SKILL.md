---
name: code-review-and-quality
description: Compatibility shim — multi-axis code review now lives in `review-code`.
when_to_use: before merging any change, when reviewing your own diff, another agent's output, or a human PR
tier: 3
redirect_to: review-code
---

# code-review-and-quality

Compatibility shim. Multi-axis code review now lives in **`review-code`**.

→ Open `core/skills/review-code/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `review-code` is not available

Minimum viable fallback:

1. Read the whole diff with line numbers, not just the changed regions
2. Walk the correctness axis: logic, edges, null, off-by-one
3. Walk the security axis: input validation, auth, secret, SSRF, injection
4. Walk the performance axis: N+1, blocking calls, unbounded loops
5. Walk the architecture axis: pattern match, source-of-truth violations
6. Walk the test axis: assertion strength, mock at correct boundary
7. Findings severity-ordered (BLOCKER / MAJOR / MINOR) with file:line and concrete fix
