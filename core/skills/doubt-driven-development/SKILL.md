---
name: doubt-driven-development
description: Adversarial 5-step review with reasoning-stripping. Use for irreversible operations (migrations, money, deploys), cross-module changes, or any unverifiable claim ("works correctly", "no edge cases"). A fresh reviewer sees only artifact + contract — never the author's reasoning — and must derive doubts from the code alone. Bounded to 3 cycles.
---

# Doubt-Driven Development

Most review failures come from the reviewer absorbing the author's reasoning and pattern-matching to "looks fine." Reasoning is a confidence drug. This skill strips it out: a fresh reviewer gets the artifact and the contract, nothing else, and is forced to invent doubts from scratch.

Adapted from addyosmani/agent-skills (`doubt-driven-development`). Complements `code-review-and-quality` (multi-axis review) and `verify-first` (claim verification before assertion).

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER pass the author's reasoning, rationale, or chat history to the doubt reviewer. Artifact + contract only. Reasoning leakage destroys the entire point.
2. NEVER ship after 0 doubts on the first pass — that means the reviewer pattern-matched, not reviewed. Re-spawn with a sharper contract.
3. ALWAYS bound to 3 cycles. After 3, escalate (advisor / qa-tester / hard stop). More cycles = thrashing, not insight.

Reasoning is a confidence drug. The reviewer must derive doubts from the code alone.
</EXTREMELY-IMPORTANT>

## Red Flags — you are about to skip this skill

| Red flag (your thought) | What it actually means |
|-------------------------|------------------------|
| "Let me give the reviewer some context to save time" | Context = author reasoning = exactly what destroys the review. |
| "Reviewer returned 0 doubts on cycle 1, ship it" | Reviewer didn't engage. Sharpen the contract and re-spawn. |
| "Already on cycle 4, one more should do it" | Stop at 3. Escalate. More cycles is thrashing. |
| "This change is reversible, I don't need doubt review" | Then you don't need this skill. Read the When-to-use list and re-check. |
| "qa-tester already reviewed, doubt-driven is redundant" | qa-tester checks behavior; doubt-driven checks the unstated invariants. Different lens. |

## When to use

- **Irreversible operations** — migrations, money transfers, deploys, data deletion, email sends
- **Cross-module changes** — touches ≥3 modules with coupled invariants
- **Unverifiable claims** — author says "works correctly", "no edge cases", "trivial change"
- **High-risk surface** — auth, permissions, billing, distributed locks, external API mutations
- **Hot-path code** — change runs on every request, every job, every page load
- **Author and reviewer are the same agent** — self-review blind spots

Skip when: typo, comment-only, dead-code removal already verified, pure rename caught by typechecker.

## How to apply

### Step 1 — CLAIM (author)

Original author states **two things only**:

```
ARTIFACT: <file path(s) + diff or symbol name>
CONTRACT: <what this MUST do — in observable terms, no implementation hints>
```

Bad contract: "the cache should work efficiently"
Good contract: "GET /api/user/:id returns within 50ms p95 for cached users; cache invalidates on PUT /api/user/:id within 1s"

Contract is the success oracle. If it's vague, doubts will be vague too. Sharpen before proceeding.

### Step 2 — EXTRACT (Lead)

Lead reads the author's hand-off and **strips reasoning**:

| Keep | Strip |
|------|-------|
| Artifact (code, diff, file path) | "I chose X because Y" |
| Contract (observable behavior) | "This handles the edge case where..." |
| Test names + pass/fail status | "I considered Z but it wasn't needed" |
| Public API signatures | Author's confidence statements |

What remains: artifact + contract. Hand to reviewer. Reviewer never sees the rest.

### Step 3 — DOUBT (fresh reviewer)

Reviewer gets ONLY artifact + contract. Their job: invent doubts the artifact alone cannot dispel.

Doubt template:

```
DOUBT: <one sentence>
EVIDENCE: <line refs from artifact OR "absence — contract says X, artifact doesn't show how">
IMPACT: <what breaks if doubt is real>
DISPELS BY: <what artifact change or test would dispel this doubt>
```

Minimum doubt set to consider:
- **Boundary**: empty input, max input, off-by-one, time-zone, locale
- **Concurrency**: two callers, retry-during-failure, partial commit, lost update
- **Failure**: dep unreachable, partial write, rollback path, idempotency
- **Contract gap**: contract says X, artifact's behavior under !X is undefined
- **Invariant**: any cross-call invariant the artifact could silently break
- **Observability**: how would you notice this regressing in prod?

Hard rule: reviewer cannot say "looks fine" or "approved." Reviewer must produce ≥1 doubt OR explicitly write `NO DOUBTS — contract is fully witnessed by artifact + tests at lines L1, L2, ...` with line refs.

### Step 4 — RECONCILE (author)

Author responds to each doubt with one of:

- **FIX**: code change that dispels the doubt (paste diff)
- **TEST**: new test that proves doubt is unfounded (paste test)
- **CONTRACT-UPDATE**: doubt reveals the contract was wrong, here's the corrected contract
- **ARGUE WITH EVIDENCE**: doubt is invalid because <evidence with line refs / measured numbers / spec citation>

Banned responses:
- "Trust me, this is fine" — no evidence = not accepted
- "That can't happen in practice" — without proof = not accepted
- "I tested it manually" — without reproducible artifact = not accepted

Each doubt gets one of the four responses. Lead checks each response against the doubt's `DISPELS BY` line.

### Step 5 — STOP (bound to 3 cycles)

| Cycle | Action |
|-------|--------|
| 1 | First doubt round + reconcile |
| 2 | Re-doubt only on issues that surfaced from cycle 1 changes |
| 3 | Final pass — confirm prior doubts dispelled, no new ones surfaced |
| 4+ | **Escalate** — Lead/user decides: ship-with-known-risks OR redesign |

Why bound? Infinite doubt = infinite cost. After 3 cycles either the artifact is genuinely good or the disagreement is about the contract itself — that needs a human decision, not more cycles.

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "This change is too small to need adversarial review" | DAPLab research: 41% of agentic-LLM failures land in changes < 50 lines. Small ≠ safe. |
| "I already know what could go wrong" | Self-doubt is fundamentally weaker than fresh-eye doubt. Author blind spots persist even when author is suspicious. |
| "We don't have time for 3 cycles" | One Sev-1 from a skipped doubt cycle costs more than 3 cycles ever would. Run cycle 1 minimum. |
| "The author already explained the reasoning, reviewer should use it" | Reasoning IS the contamination. Reviewer using author reasoning = author reviewing self with extra steps. |
| "Tests pass, ship it" | Tests prove what was tested, not what's correct. Doubt asks "what wasn't tested?" |

Default response when rationalizing: run at least cycle 1. Cost of running it is bounded; cost of skipping when you needed it is not.

## Output format

After each cycle, Lead writes:

```
DDD cycle <N>/3:
- Doubts raised: <count>
- Doubts dispelled: <count>
- Doubts deferred: <count>
- Contract changes: <count>
- Decision: continue / ship / escalate
```

## Anti-pattern — DO NOT

- Show reviewer the author's reasoning ("for context...")
- Let reviewer pattern-match to "this looks like the X pattern, fine"
- Accept "trust me" as reconcile response
- Run >3 cycles silently (escalate at 4)
- Skip when contract is vague — sharpen contract first, then run
- Treat reviewer's `NO DOUBTS` as default — require line refs
- Run on every change — reserve for irreversible / high-risk / cross-module
