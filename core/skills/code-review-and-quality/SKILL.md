---
name: code-review-and-quality
description: Conduct multi-axis code review across correctness, readability, architecture, security, and performance. Produces actionable findings with severity, file:line, and concrete fix.
when_to_use: before merging any change, when reviewing your own diff, another agent's output, or a human PR
---

# Code Review and Quality

Review = separate cognitive mode. Author proves it works; reviewer proves it can fail. Five orthogonal axes so nothing slips by single-dimension check.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER approve without running all five axes (correctness, readability, architecture, security, performance).
2. ALWAYS produce findings with file:line + severity + concrete fix. Vague comments aren't review output.
3. Rejected finding → state explicit reason. Silent dismissal hides risk.

Author confidence ≠ evidence. Prove the change can fail, not that it works.
</EXTREMELY-IMPORTANT>

## Red Flags — you're about to skip this skill

| Thought | Reality |
|---------|---------|
| "I wrote it, I know it works" | You verified your model, not the code. |
| "Diff small, one axis enough" | Small diffs hit global invariants constantly. |
| "LGTM, no comments" | Zero findings on non-trivial diff = you didn't review. |
| "CI passed, that's enough" | CI proves invariants with tests. Review proves the rest. |
| "Address in follow-up PR" | Follow-up rate <30%. Fix now or file issue. |

## When to use

- Before merging your own work
- Reviewing another agent's output
- Teammate's PR
- Periodic audit of hot module
- Post-incident review

## Run diff through five axes

### Axis 1 — Correctness

Does it do what it claims?

- Trace happy path: input → output, logic matches intent?
- Trace error paths: what throws, what's caught, what bubbles?
- Edge cases: empty, null, zero, negative, unicode, very large
- Off-by-one: indexes, slices, loop bounds, time windows
- Concurrency: shared state, races, ordering
- State machines: invalid state reachable? Stuck state?
- Math: rounding, overflow, currency, timezone

Smell: "what input would break this?" Can't think of any → haven't looked hard.

### Axis 2 — Readability

Understandable in 6 months?

- Names describe intent, not mechanism
- Functions: one thing, named after it
- Nesting 3+ levels = smell — extract or invert
- Comments explain why, never what
- Magic numbers/strings → named constants

Smell: "delete every comment, still clear?" No → rename until yes.

### Axis 3 — Architecture

Fits the system?

- Layering: imports from where it should?
- Duplication: pattern already exists?
- Validation at edges, trust inside
- Coupling: ripple to N files = too coupled
- Cohesion: module does one thing?
- Abstractions justified by 3+ uses?

Smell: "could new teammate find this by guessing?" No → wrong place.

### Axis 4 — Security

Attacker is the user.

- Input validation at boundaries (HTTP, queue, file parse)
- Authentication present on endpoint
- Authorization: user owns this resource?
- SQL/NoSQL: parameterized, never concat
- XSS: output encoded per context
- SSRF: user URLs allowlisted
- Secrets: not logged / in errors / in responses
- PII: minimum necessary, redacted in logs
- Crypto: stdlib only
- Rate limits on expensive ops
- Tenant isolation: every query filtered

Smell: "first thing attacker tries?" Verify blocked.

### Axis 5 — Performance

Will it scale?

- N+1 queries: any loop with per-iteration DB/API
- Unbounded: no limit/pagination/timeout
- Allocations in hot paths
- Index supports new queries
- Caching: hot read, sane key, invalidation
- Async/blocking: event loop tied up?
- Payload size: large response → paginate/project

Smell: "at 10x load?" Falls over → flag.

## Severity

| Severity | Definition | Action |
|----------|-----------|--------|
| `block` | Bug, security, data-loss, breaks contract | Must fix |
| `warn` | Maintainability, smell, weak test | Should fix or file issue |
| `nit` | Style, naming | Author's call |
| `praise` | Worth highlighting | Note it |

Don't dilute `block` with nits.

## Finding format

```
[severity] file:line — what's wrong
  why: brief reason
  fix: concrete suggestion (or snippet)
```

Example:
```
[block] src/orders/create.ts:42 — no idempotency key check
  why: client retry on network blip creates duplicate orders
  fix: read Idempotency-Key header, look up cached response, return same body
```

## Delivery

1. Read whole diff first, then comment
2. Group findings by file
3. Lead with `block`
4. Praise 1-2 spots genuinely
5. End with verdict: `approve / approve-with-nits / changes-requested / blocked`

## Common mistakes

- Line-by-line review misses architectural issues
- Style nits dressed as `block`
- "LGTM" without tracing logic
- Missing test pass (no test for new behavior)
- Missing what's NOT there (deleted test, removed validation)
- Approving because author is trusted
- Re-running review per fix instead of batching

## Quick reference — checklist

```
Correctness
  [ ] Happy path traced
  [ ] Error paths handled
  [ ] Edge cases covered
  [ ] Concurrency considered

Readability
  [ ] Names describe intent
  [ ] Single-purpose functions
  [ ] Nesting ≤3

Architecture
  [ ] Imports respect layers
  [ ] No duplication
  [ ] Validation at boundary

Security
  [ ] Auth checked
  [ ] Input validated
  [ ] No secrets in logs/responses
  [ ] Tenant isolation

Performance
  [ ] No N+1
  [ ] Indexes support queries
  [ ] Bounded operations
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Self-review before commit is enough" | Self-review misses ~50% of bugs. |
| "Simple change" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
