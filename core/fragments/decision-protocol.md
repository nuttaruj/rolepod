## Decision protocol — simplest viable wins

Fires BEFORE writing code when Lead faces ≥2 viable options with non-trivial impact. Upstream prevention; S1-S5 = downstream gate.

<EXTREMELY-IMPORTANT>
NEVER pick complex when simple meets the requirement.
NEVER add abstractions for hypothetical needs.
NEVER add config flexibility nobody asked for.
NEVER pre-optimize without measured evidence.

Default: SIMPLEST viable wins. Complex needs explicit user approval + reason.
</EXTREMELY-IMPORTANT>

### 5-step protocol

1. **Enumerate** — list every viable path
2. **Analyze** — problems / tradeoffs / unknowns per option
3. **Compare** — criteria visible (complexity, blast radius, reversibility, cost)
4. **Pick simplest viable** — meets requirement with least machinery
5. **Document** — brief rationale inline; link ADR if architectural

### Worked example

```
Task: "Add caching to API response"

1. Enumerate: A. dict (no eviction) · B. lru_cache · C. Redis · D. CDN
2. Analyze:
   A: memory leak risk
   B: decorator, built-in eviction → 90% of cases
   C: external dep, infra cost → over-engineered for single-server
   D: changes deployment → way over-scoped
3. Compare: required = response cache. NOT required = distributed/edge.
4. Pick: B (lru_cache)
5. Document: ADR-031 — chose lru_cache, single-server + 90% case fit.
```

Anti-pattern: "I'll just use Redis, industry standard" → no enumeration, picks complex by default.

### Common rationalizations (reject)

- *"We might need it later"* → YAGNI. 80% never used, rots into dead code.
- *"Small abstraction"* → still a hop + name + bug hiding place. Defer to S5 (3rd repetition).
- *"Industry best practice"* → context-dependent.
- *"Already started"* → sunk cost. Cut now < maintain forever.
- *"Just 20 lines"* → 20 × N readers × forever = real cost.

### Red flags — about to over-engineer

- Interface/abstract class with one impl
- Config key with one valid value
- Plugin/hook system with zero current plugins
- Generic wrapper around a single library call
- Retry/timeout/circuit-breaker without observed failure
- Refactoring "while I'm here"
- Pre-splitting modules <500 lines

Any flag → run 5-step protocol, pick simpler.

### Relationship to gates

Protocol = plan time. S1-S5 = commit time. F1-F5 = post-impl hallucination check.
Protocol fires correctly → S-gate finds nothing to flag.
