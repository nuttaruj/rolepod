---
name: documentation-and-adrs
description: Write durable technical docs and architectural decision records (ADRs).
when_to_use: when capturing why a choice was made, documenting a public API, writing a runbook, or recording context that future readers will need
paths:
  - "**/docs/**/*.md"
  - "**/ADR-*.md"
  - "**/decisions/**"
---

# Documentation and ADRs

Code shows what. Tests show how. Docs show why — and only docs survive re-architecture.

## When to use

- Made non-obvious technical decision (ADR)
- Building public API surface (reference + how-to)
- New service or job (runbook)
- Onboarding was painful for last hire
- Same chat question 3rd time (belongs in docs)
- Removing/migrating a system

Skip: obvious from reading code, true for a week only, nobody will look up.

## Four document types — pick one

Each answers a different question. Don't mix.

| Type | Question | Example |
|------|----------|---------|
| **Reference** | "What does X do?" | API endpoints, config keys, CLI flags |
| **How-to** | "How do I do Y?" | "Add new tenant", "Rotate signing key" |
| **Tutorial** | "I'm new — walk me through it" | First-day onboarding |
| **Explanation / ADR** | "Why is it this way?" | Architecture, tradeoffs, history |

When in doubt: name the audience and what they'll do next.

## ADRs — Architectural Decision Records

Short note explaining one decision. Not a design doc. Not a future plan. Decision made, why, what was rejected.

### When to write

- Choice between non-trivial alternatives (Postgres vs SQLite, REST vs gRPC)
- Hard to reverse later (auth model, tenant isolation, billing source of truth)
- Surprising to new readers ("why is this synchronous?")
- Convention repeating across places (naming, error format, time zones)

### Structure (one page max)

```
# ADR-NNN: [Decision in active voice — "Use Postgres for primary store"]

Date: YYYY-MM-DD
Status: proposed | accepted | superseded by ADR-MMM
Authors: [names]

## Context
What forces the decision. Constraints, requirements, failed alternatives.

## Decision
What we are doing, 2-5 sentences. Active voice. Specific.

## Alternatives considered
What else we looked at. One paragraph each. Why rejected.
Future readers care most about this part.

## Consequences
What gets easier. What gets harder. New risks accepted. What we'd
revisit if X changes.
```

ADRs are immutable. Decision changes → write new ADR superseding. Don't edit history.

## Reference docs — survive without updates

- **Generate from source** when possible — OpenAPI from handlers, type docs from types, CLI help from arg parsers
- **Co-locate** — README in the directory beats far-off `docs/` tree
- **Test examples** — runnable snippets in CI catch rot
- **Date material that ages** — costs, limits, perf numbers

## How-tos — one task, end-to-end

```
# How to [task]

When to use: [one sentence]
Prerequisites: [what reader must have/know]
Time: [rough budget]

## Steps
1. [Action] — [expected outcome]
2. [Action] — [expected outcome]

## Verify it worked
[Concrete check]

## If it didn't work
[Top 2-3 failure modes + fixes]

## See also
[Related how-tos/references]
```

Skip motivation, philosophy, history. Those belong in Explanation.

## Runbooks — for someone tired at 3 AM

- Start with **symptoms** ("alert X firing", "users seeing Y")
- One section per symptom, **immediate actions** at top
- **Commands** to copy-paste — not screenshots, not "you can use kubectl to see..."
- Note **what's safe without paging someone** vs. needs escalation
- Update after every incident

## Common mistakes

- Writing "design doc" instead of ADR — five pages of context, no decision
- ADR with no rejected alternatives
- Reference docs in separate `docs/` repo that never syncs
- How-to explaining philosophy instead of steps
- Runbook with "you might want to consider checking..." instead of `kubectl get pods -n foo`
- Tutorial assuming reader knows the thing the tutorial teaches
- Editing ADRs in place when decision changes
- One giant README = reference + how-to + tutorial + history

## Quick reference

| Reader's question | Doc type | Length |
|-------------------|----------|--------|
| What is this? | Reference | As needed, generated where possible |
| How do I do X? | How-to | 1 page, recipe-style |
| I'm new, where do I start? | Tutorial | Walk-through, ~30 min |
| Why was this built like this? | ADR / Explanation | 1 page ADR |
| It's broken and I'm on call | Runbook | Symptom-first, copy-paste commands |

## Maintenance

- Date everything that ages, include "last verified"
- Changing code → ask "what doc just became wrong?"
- Delete docs for systems that no longer exist
- Index from single starting point — README → directory → docs

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "We'll remember why we decided" | You won't. ADRs cheaper than re-running the decision conversation. |
| "Simple change" | 41% of agentic-LLM failures hide in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
