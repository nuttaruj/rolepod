---
name: code-review-and-quality
description: Conduct multi-axis code review across correctness, readability, architecture, security, and performance. Apply before merging any change, when reviewing your own diff, another agent's output, or a human PR. Produces actionable findings with severity, file:line, and concrete fix.
---

# Code Review and Quality

Review is a separate cognitive mode from writing. The author proves it works; the reviewer proves it can fail. This skill structures that adversarial pass across five orthogonal axes so nothing slips by because you only checked one dimension.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER approve a diff without running all five axes (correctness, readability, architecture, security, performance). Skipping an axis = blind spot shipped.
2. ALWAYS produce findings with file:line + severity + concrete fix. Vague comments ("could be cleaner") are not review output.
3. If a finding is rejected, ALWAYS state the explicit reason in code or comment — silent dismissal hides risk from the next reviewer.

The author's confidence is not evidence. Reviewer's job: prove the change can fail, not confirm it works.
</EXTREMELY-IMPORTANT>

## Red Flags — you are about to skip this skill

| Red flag (your thought) | What it actually means |
|-------------------------|------------------------|
| "I wrote it, I already know it works" | You verified your model of the code, not the code itself. |
| "Diff is small, one axis is enough" | Small diffs hit global invariants (auth/money/locks) constantly. |
| "LGTM with no comments" | Zero findings on a non-trivial diff = you didn't actually review. |
| "CI passed, that's enough" | CI proves invariants with tests. Review proves the rest. |
| "I'll address that in a follow-up PR" | Follow-up PR rate < 30% in practice. Fix now or file an issue. |

## When to use

- Before merging your own work (self-review pass)
- Reviewing another agent's output before accepting it
- Reviewing a teammate's PR
- Periodic audit of a hot module
- Post-incident review of the code that caused the incident

## How to apply

Run the diff through five axes. Each finding gets a severity, location, and fix.

### Axis 1 — Correctness

Does the code do what it claims?

- Trace happy path: input → output, does logic match intent?
- Trace error paths: what can throw, what's caught, what bubbles?
- Edge cases: empty input, null, zero, negative, unicode, very large
- Off-by-one: indexes, slices, loop bounds, time windows
- Concurrency: shared state, race conditions, ordering assumptions
- State machines: can it reach an invalid state? Can it get stuck?
- Math: rounding, overflow, currency precision, timezone math

Smell test: "what input would break this?" If you can't think of any, you haven't looked hard enough.

### Axis 2 — Readability

Will someone (including future-you) understand this in 6 months?

- Names: do they describe intent, not mechanism?
- Functions: one thing, named after the thing
- Nesting: 3+ levels deep is a smell — extract or invert
- Comments: explain why, never what
- File organization: related things together, unrelated things apart
- Magic numbers/strings: extracted to named constants

Smell test: "If I deleted every comment, would the code still be clear?" If no, rename until yes — then re-add comments only for non-obvious WHY.

### Axis 3 — Architecture

Does it fit the system?

- Layering: does it import from where it should?
- Duplication: is this pattern already implemented elsewhere?
- Boundaries: validation at edges, trust inside?
- Coupling: does this change ripple to N other files? (then it's too coupled)
- Cohesion: does this module do one thing? (or has it become a junk drawer?)
- Abstractions: justified by 3+ uses or single-use premature?

Smell test: "Could a new teammate find this code by guessing where it lives?" If no, it's in the wrong place.

### Axis 4 — Security

What happens when an attacker is the user?

- Input validation at boundaries (HTTP, queue, file parse)
- Authentication: is this endpoint protected?
- Authorization: does this user own this resource?
- SQL/NoSQL injection: parameterized queries, never string concat
- XSS: output encoded for context (HTML, attribute, JS, URL)
- SSRF: user URLs allowlisted before fetch
- Secrets: not logged, not in error messages, not in client responses
- PII: minimum necessary, redacted in logs
- Crypto: stdlib only, no rolling-your-own
- Rate limits: present on expensive operations
- Tenant isolation: every query filtered by tenant/owner

Smell test: "If I gave an attacker access to this code, what's the first thing they'd try?" Verify it's blocked.

### Axis 5 — Performance

Will this scale?

- N+1 queries: any loop that calls a DB or API per iteration
- Unbounded operations: no limit, no pagination, no timeout
- Allocations in hot paths: arrays in loops, string concat in tight loops
- Indexes: is the new query supported by an index?
- Caching: hot read path, cache-key sane, invalidation handled
- Async / blocking: is the event loop tied up by sync work?
- Payload size: large response → pagination or projection

Smell test: "What does this do at 10x the current load?" If the answer is "fall over", flag it.

## Severity levels

| Severity | Definition | Action |
|----------|-----------|--------|
| `block` | Bug, security, data-loss, breaks contract | Must fix before merge |
| `warn` | Maintainability, smell, weak test | Should fix; if deferred, file issue |
| `nit` | Style, naming, minor preference | Optional; author's call |
| `praise` | Worth highlighting good work | Note it; reinforces good patterns |

Don't dilute `block` with style preferences — reviewers who block on nits get ignored.

## Finding format

Each finding:

```
[severity] file:line — what's wrong
  why: brief reason
  fix: concrete suggestion (or code snippet)
```

Example:
```
[block] src/orders/create.ts:42 — no idempotency key check
  why: client retry on network blip will create duplicate orders
  fix: read Idempotency-Key header, look up cached response, return same body
```

Vague findings ("this seems off") waste rounds. Be specific.

## How to deliver review

1. Read the whole diff first — don't comment until you have the full picture
2. Group findings by file
3. Lead with `block` items — surface the must-fix
4. Praise something genuine (1-2 spots) — review isn't only fault-finding
5. End with a summary verdict: `approve / approve-with-nits / changes-requested / blocked`

## Common mistakes

- Reviewing line-by-line instead of holistically (miss architectural issues)
- Style nits dressed up as `block` severity
- "LGTM" without actually tracing logic
- Missing the test pass (review code that has no test for the new behavior)
- Forgetting to check the diff for what's NOT there (deleted test, removed validation)
- Approving because author is senior / trusted (review the code, not the author)
- Bikeshedding minor naming while the architecture is wrong
- Re-running the review after each fix instead of batching findings

## Quick reference — checklist

```
Correctness
  [ ] Happy path traced
  [ ] Error paths handled
  [ ] Edge cases covered
  [ ] Concurrency considered

Readability
  [ ] Names describe intent
  [ ] Functions are single-purpose
  [ ] Nesting depth ≤ 3

Architecture
  [ ] Imports respect layers
  [ ] No duplication of existing code
  [ ] Validation at boundary

Security
  [ ] Auth checked
  [ ] Input validated
  [ ] No secrets in logs/responses
  [ ] Tenant isolation present

Performance
  [ ] No N+1
  [ ] Indexes support new queries
  [ ] Bounded operations
```

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "I'll self-review before commit" | Self-review misses ~50% of bugs (author blind spots are well-documented). Multi-axis structure forces you out of your own pattern-matching. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
