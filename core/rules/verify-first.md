# Verify-First — claiming facts / answering questions

**Scope:** confirming facts BEFORE claims.
**NOT this file:** verifying YOUR change after editing → `verification.md`.

Read when: about to claim fact / make recommendation / answer factual question.

## Core principle

**Before any plan / edit / recommendation / answer → confirm from primary source.**
Memory + pattern-match = unreliable. Verify or state assumption + risk.

## Sources of truth (priority)

### Internal

1. **File system** — `Read` actual file, don't recall
2. **Code intel** — `gitnexus_impact` / `gitnexus_context` (NOT grep-and-guess)
3. **Live state** — run command / query DB / curl endpoint
4. **MemPalace** — past decision (verify still current)

### External

5. **WebFetch** — official docs (specific URL)
6. **WebSearch** — current state (pricing / news / lib versions / API changes)
7. **CLI tools** — `gh api`, `stripe`, `aws`
8. **MCP servers** — Stripe / Sentry / GitHub

### Last resort

9. **User** — ask when no source available

## MUST verify

### Internal
- "File X exists" / "fn Y at line Z" → Read
- "X called by Y" → `gitnexus_impact` upstream
- "API returns Z" → curl / read actual response
- "We decided X" → MemPalace + verify code matches
- "Build/test passes" → actually run

### External
- "Library X has method Y" → WebFetch current docs
- "Service X costs $Y" → WebSearch / pricing page
- "API endpoint X behaves Z" → WebFetch spec OR curl
- "Framework X v2 released" → WebSearch + release notes
- "Best practice for X" → WebFetch official, NOT training recall
- "Company X announced Y" → WebSearch with current year
- "Stripe/AWS/Vercel does X" → MCP / CLI / docs

## Volatility ladder

| Type | Trust training? | How verify |
|------|----------------|------------|
| Math / algorithms / language semantics | Yes | Skip |
| Stable library API | Partial | WebFetch if version-specific |
| Pricing / quotas / limits | NO | Always WebSearch + cite |
| Current events / news | NO | WebSearch w/ current year |
| API changes / new features | NO | Official docs / changelog |
| Library version compat | NO | WebFetch latest |

## Cross-verify high stakes

For architecture / cost / security:
- 2 independent sources (official docs + recent blog)
- Note conflict, don't pick silently
- Cite source with link

## Forbidden patterns

### Internal
- "This codebase probably has X"
- "I remember earlier that file said..."
- "Should be using PostgreSQL" without checking
- Confident line/symbol claims not just-verified
- Citing fn name from memory without `Read`/`gitnexus_context`

### External
- Quote pricing / quota from training
- Cite library API from training without version check
- "Recent" events without WebSearch
- Recommend service without verifying current state
- Training year when current year matters
- Skip source link when reporting external fact

## When can't verify

```
Assuming: [what]
Reason: [why can't verify]
Risk if wrong: [impact]
Verify by: [how user can confirm]
```

DO NOT proceed silently.

## Memory decay

MemPalace facts can be stale. Before recommending from memory → verify file/symbol still exists.

## Common mistakes — DO NOT

- Claim line number from memory
- Quote pricing without WebSearch
- Assume library API matches training
- Skip source link for external fact
- Treat MemPalace as authoritative without verifying current state
