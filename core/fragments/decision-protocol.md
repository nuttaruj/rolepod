## Decision protocol — simplest viable wins

Fires BEFORE writing code, whenever Lead faces a choice with ≥2 viable options and non-trivial impact (architecture / approach / tooling / abstraction / dependency). S1-S5 catches over-engineering at pre-commit; this protocol prevents it from entering the plan in the first place. Defense in depth.

<EXTREMELY-IMPORTANT>
NEVER pick a complex option when a simple option meets the requirement.
NEVER add abstractions for hypothetical future needs.
NEVER add config flexibility nobody asked for.
NEVER pre-optimize without measured evidence.

Default behavior: SIMPLEST viable option wins.
Complex option needs explicit user approval + cited reason.
</EXTREMELY-IMPORTANT>

### 5-step protocol

1. **Enumerate** — list every viable path (don't stop at first idea)
2. **Analyze** — concrete problems / tradeoffs / unknowns per option
3. **Compare** — side-by-side, criteria visible (complexity, blast radius, reversibility, cost)
4. **Pick simplest viable** — meets requirement with least machinery
5. **Document** — brief rationale inline; link to ADR if architectural

### Worked example — full 5 steps

Concrete demonstration so small models see exactly what enumeration + analysis looks like.

```
Task: "Add caching to API response"

Step 1 — Enumerate options:
  A. In-memory dict (no eviction)
  B. LRU cache (lru_cache decorator)
  C. Redis
  D. Add CDN layer

Step 2 — Analyze each:
  A: simple, 5 lines, no eviction → memory leak risk if growth
  B: simple, decorator, built-in eviction → handles 90% of cases
  C: external dep, infra cost, network round-trip → over-engineered for
     single-server
  D: changes deployment, requires DNS → way over-scoped

Step 3 — Compare:
  Required: response cache. Not required: distributed cache, edge caching.

Step 4 — Pick SIMPLEST that meets requirement:
  → B (lru_cache decorator)

Step 5 — Document:
  ADR-031: chose lru_cache over Redis/CDN because single-server + 90% case
  fit.
```

Anti-pattern: skipping straight to "I'll just use Redis since it's industry standard" → no enumeration, no comparison, picks the complex option by default.

### Examples

- **Bad** — "I'll add a plugin system in case we need it later" → over-engineered for a single use case
- **Good** — "Direct function call now. Revisit plugin system when 3rd extension point appears."
- **Bad** — "Wrap this in a config-driven factory for flexibility" → no current second consumer
- **Good** — "Hardcode the value. Extract when the second caller arrives."

### Common rationalizations (the usual excuses)

- *"We might need this flexibility later"* → YAGNI. 80% of speculative flexibility never gets used and rots into dead code.
- *"It's a small abstraction"* → still adds a hop, a name to learn, a place bugs hide. Defer until 3rd repetition (S5 gate).
- *"Industry best practice"* → best practice is contextual. Simpler may be the right practice for this scale.
- *"I've already started building it"* → sunk cost. Cut now is cheaper than maintain forever.
- *"It's only 20 more lines"* → 20 lines × N future readers × forever = real cost.

### Red flags — Lead about to over-engineer

- Adding interface/abstract class with one implementation
- Adding config key with one valid value
- Adding plugin/hook system with zero current plugins
- Adding generic wrapper around a single library call
- Adding retry/timeout/circuit-breaker without observed failure
- Refactoring "while I'm here" beyond the requested change
- Pre-splitting modules before they hit 500 lines

Any red flag → stop, run the 5-step protocol, pick simpler.

### Relationship to S1-S5

This protocol = upstream prevention (catch at plan time).
S1-S5 = downstream gate (catch at commit time).
F1-F6 = post-impl hallucination check.

If the protocol fires correctly, S-gate has nothing to flag.
