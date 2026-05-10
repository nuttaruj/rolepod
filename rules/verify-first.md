# Verify-First — claiming facts / answering questions

**Scope:** rules for confirming facts BEFORE making claims.
**NOT this file:** how to verify YOUR change works after editing → see `verification.md`.

Read when: about to claim a fact / make recommendation / answer factual question.

## Core principle

**Before any plan / edit / recommendation / answer → confirm from primary source.**
Memory + pattern-match = unreliable. Verify or state assumption + risk explicitly.

## Sources of truth (priority order)

### Internal (codebase / project)

1. **File system** — `Read` actual file, don't recall content from memory
2. **Code intel** — `gitnexus_impact` / `gitnexus_context` for symbol facts (NOT grep-and-guess)
3. **Live state** — run command / query DB / check API response / curl endpoint
4. **MemPalace** — past decision (verify still current before applying)

### External (web / docs / 3rd-party)

5. **WebFetch** — official docs page (specific URL)
6. **WebSearch** — current state (pricing / news / library versions / API changes)
7. **CLI tools** — `gh api`, `stripe`, `aws`, etc. for live 3rd-party state
8. **MCP servers** — Stripe MCP, Sentry MCP, GitHub MCP for structured data

### Last resort

9. **User** — ask when can't determine from sources above

## MUST verify before claiming

### Internal
- "File X exists" / "function Y is at line Z" → Read it
- "X is called by Y" → `gitnexus_impact` upstream
- "API returns Z" → curl / read actual response
- "We decided X last time" → MemPalace query + verify code matches
- "Build/test passes" → actually run it

### External
- "Library X has method Y" → WebFetch current docs (training stale)
- "Service X costs $Y" → WebSearch / official pricing page (volatile)
- "API endpoint X behaves Z" → WebFetch official spec OR curl live
- "Framework X v2 released" → WebSearch + check release notes
- "Best practice for X" → WebFetch official guide, NOT training recall
- "Company X announced Y" → WebSearch with current year qualifier
- "Stripe/AWS/Vercel does X" → MCP server OR official CLI OR docs

## Volatility ladder

| Type | Trust training? | Verify how |
|------|----------------|------------|
| Math / algorithms / language semantics | Yes (stable) | Skip verify |
| Stable library API (1.x → 1.x) | Partial | WebFetch if version-specific |
| Pricing / quotas / limits | NO | Always WebSearch + cite source |
| Current events / news | NO | WebSearch with current year |
| API changes / new features | NO | Official docs / changelog |
| Library version compat | NO | WebFetch latest docs |

## Cross-verify when stakes high

1 source can be wrong/outdated. For high-stakes decision (architecture / cost / security):
- Get 2 independent sources (e.g. official docs + recent blog post)
- Note conflict if found, don't pick silently
- Cite source with link when reporting

## Forbidden patterns

### Internal
- Pattern-match from training: "this codebase probably has X"
- Recall from earlier in session: "I remember reading that file said..."
- Assume defaults: "should be using PostgreSQL" without checking
- Confident claims about lines/symbols not just-verified
- Citing function name from memory without `Read`/`gitnexus_context`

### External
- Quote pricing / quota / limit from training (always volatile)
- Cite library API from training without checking current version
- Reference "recent" events / releases without WebSearch
- Recommend service / tool without verifying it still exists + current state
- Use training year (2025) when current year (2026) matters for search
- Skip source link when reporting external fact to user

## When verification impossible

State explicitly:
```
Assuming: [what assumed]
Reason: [why can't verify]
Risk if wrong: [impact]
Verify by: [how user/Lead can confirm]
```

DO NOT proceed silently on assumption.

## Memory decay

MemPalace facts can be stale. Code referenced in memory may have moved/renamed/deleted.
Before recommending from memory → verify file/symbol still exists.

## Common mistakes — DO NOT

- Claim line number from memory (always Read first)
- Quote pricing without WebSearch (always volatile)
- Assume library API matches training (check version)
- Skip source link when stating external fact
- Treat MemPalace as authoritative without verifying current state
