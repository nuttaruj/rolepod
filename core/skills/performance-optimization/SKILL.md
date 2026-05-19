---
name: performance-optimization
description: Compatibility shim — performance review and optimization now lives in `review-code` and `check-work`; depth lives in the `performance-engineer` agent.
when_to_use: when performance budgets are missed, regressions appear, or users report slowness
tier: 3
redirect_to: review-code
---

# performance-optimization

Compatibility shim. Performance review now lives inside **`review-code`** (analysis) and **`check-work`** (evidence); the `performance-engineer` agent adds depth when installed.

→ Open `core/skills/review-code/SKILL.md` for analysis or `core/skills/check-work/SKILL.md` for evidence. Brief `performance-engineer` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `review-code` is not available

Minimum viable fallback:

1. Measure before optimizing — no perf work without numbers
2. p95 / p99, not average — averages hide the slow tail
3. UI: Core Web Vitals (LCP, INP, CLS) within target
4. DB: read the query plan; missing index is the most common cause
5. FE: bundle analyzer; lazy-load and code-split what is not on the critical path
6. Backend: N+1 queries, blocking I/O, unbounded loops, big payloads
7. Re-measure after the fix to confirm the regression closed
