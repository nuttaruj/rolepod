---
name: doubt-driven-development
description: Adversarial 5-step review with reasoning-stripping. A fresh reviewer sees only artifact + contract — never the author's reasoning — and must derive doubts from the code alone. Bounded to 3 cycles.
when_to_use: irreversible operations (migrations, money, deploys), cross-module changes, or any unverifiable claim ("works correctly", "no edge cases")
---

# Doubt-Driven Development

Most review failures = reviewer absorbed author's reasoning and pattern-matched "looks fine." This skill strips reasoning: reviewer gets artifact + contract only, forced to invent doubts from scratch.

Adapted from addyosmani/agent-skills (`doubt-driven-development`). Complements `code-review-and-quality` and `verify-first`.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER pass author's reasoning, rationale, or chat history to the doubt reviewer. Artifact + contract only.
2. NEVER ship after 0 doubts on first pass — reviewer pattern-matched, didn't review. Re-spawn with sharper contract.
3. ALWAYS bound to 3 cycles. After 3, escalate.

Reasoning is a confidence drug. Reviewer must derive doubts from code alone.
</EXTREMELY-IMPORTANT>

## Red Flags

| Thought | Reality |
|---------|---------|
| "Let me give reviewer context to save time" | Context = author reasoning = exactly what destroys review. |
| "0 doubts on cycle 1, ship" | Reviewer didn't engage. Sharpen contract, re-spawn. |
| "Already on cycle 4, one more" | Stop at 3. Escalate. |
| "Change is reversible" | Then you don't need this skill. |
| "qa-tester already reviewed, this is redundant" | qa-tester checks behavior; doubt-driven checks unstated invariants. Different lens. |

## When to use

- **Irreversible operations** — migrations, money, deploys, data deletion, email sends
- **Cross-module changes** — touches ≥3 modules with coupled invariants
- **Unverifiable claims** — "works correctly", "no edge cases", "trivial"
- **High-risk surface** — auth, permissions, billing, distributed locks, external mutations
- **Hot-path code** — runs on every request/job/page load
- **Author == reviewer** — self-review blind spots

Skip: typo, comment-only, verified dead-code, pure rename caught by typechecker.

## How to apply

### Step 1 — CLAIM (author)

Author states two things only:

```
ARTIFACT: <file path(s) + diff or symbol name>
CONTRACT: <what this MUST do — observable terms, no implementation hints>
```

Bad: "cache should work efficiently"
Good: "GET /api/user/:id returns within 50ms p95 for cached users; cache invalidates on PUT within 1s"

Vague contract → vague doubts. Sharpen before proceeding.

### Step 2 — EXTRACT (Lead)

Lead strips reasoning:

| Keep | Strip |
|------|-------|
| Artifact (code, diff, path) | "I chose X because Y" |
| Contract (observable behavior) | "This handles edge case where..." |
| Test names + pass/fail status | "I considered Z but it wasn't needed" |
| Public API signatures | Author's confidence statements |

Remaining: artifact + contract. Hand to reviewer. Reviewer never sees the rest.

### Step 3 — DOUBT (fresh reviewer)

Reviewer gets ONLY artifact + contract. Job: invent doubts artifact alone cannot dispel.

Doubt template:

```
DOUBT: <one sentence>
EVIDENCE: <line refs OR "absence — contract says X, artifact doesn't show how">
IMPACT: <what breaks if doubt is real>
DISPELS BY: <what change or test would dispel>
```

Minimum doubt set:
- **Boundary**: empty, max, off-by-one, time-zone, locale
- **Concurrency**: two callers, retry-during-failure, partial commit, lost update
- **Failure**: dep unreachable, partial write, rollback path, idempotency
- **Contract gap**: contract says X, behavior under !X undefined
- **Invariant**: cross-call invariant silently broken
- **Observability**: how would you notice regression in prod?

Reviewer cannot say "looks fine." Must produce ≥1 doubt OR explicitly write `NO DOUBTS — contract fully witnessed by artifact + tests at lines L1, L2, ...` with line refs.

### Step 4 — RECONCILE (author)

Per doubt, one of:

- **FIX**: code change dispelling doubt (paste diff)
- **TEST**: new test proving unfounded (paste test)
- **CONTRACT-UPDATE**: contract was wrong; here's corrected
- **ARGUE WITH EVIDENCE**: invalid because <evidence with line refs / measured numbers / spec citation>

Banned:
- "Trust me" — no evidence
- "Can't happen in practice" — without proof
- "Tested manually" — without reproducible artifact

### Step 5 — STOP (bound to 3 cycles)

| Cycle | Action |
|-------|--------|
| 1 | First doubt round + reconcile |
| 2 | Re-doubt only on issues from cycle 1 changes |
| 3 | Final pass — prior doubts dispelled, no new surfaced |
| 4+ | **Escalate** — ship-with-known-risks OR redesign |

After 3 cycles, either artifact is good or disagreement is about contract itself — that needs human decision.

## Output format

```
DDD cycle <N>/3:
- Doubts raised: <count>
- Doubts dispelled: <count>
- Doubts deferred: <count>
- Contract changes: <count>
- Decision: continue / ship / escalate
```

## Anti-pattern — DO NOT

- Show reviewer author's reasoning ("for context...")
- Let reviewer pattern-match to known patterns
- Accept "trust me" as reconcile
- Run >3 cycles silently
- Skip when contract is vague — sharpen first
- Treat `NO DOUBTS` as default — require line refs
- Run on every change — reserve for irreversible/high-risk/cross-module

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Change too small for adversarial review" | 41% of agentic-LLM failures in <50-line changes (DAPLab). Small ≠ safe. |
| "I know what could go wrong" | Self-doubt is weaker than fresh-eye doubt. |
| "No time for 3 cycles" | One Sev-1 from skipped doubt cycle costs more. Run cycle 1 minimum. |
| "Reviewer should use author's reasoning" | Reasoning IS the contamination. |
| "Tests pass, ship" | Tests prove what was tested. Doubt asks what wasn't. |

Default: run cycle 1 minimum.
