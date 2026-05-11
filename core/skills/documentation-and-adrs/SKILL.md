---
name: documentation-and-adrs
description: Write durable technical docs and architectural decision records (ADRs). Use when capturing why a choice was made, documenting a public API, writing a runbook, or recording context that future readers will need.
---

# Documentation and ADRs

Code shows what. Tests show how. Docs show why — and only docs survive a re-architecture. This skill is for the writing that has to outlive the people who wrote it.

## When to use

- Made a non-obvious technical decision (write an ADR)
- Building a public API surface (write reference + how-to)
- Stood up a new service or job (write a runbook)
- Onboarding turned out to be painful for the last hire (write the missing piece)
- Same question gets asked in chat for the 3rd time (the answer belongs in docs)
- Removing or migrating a system (write what the replacement looks like)

Skip when: it's obvious from reading the code, it'll be true for a week, or nobody will ever look it up.

## Four document types — pick the right one

Each type answers a different question. Don't mix them in one file.

| Type | Question it answers | Example |
|------|---------------------|---------|
| **Reference** | "What does X do?" | API endpoints, config keys, CLI flags |
| **How-to** | "How do I accomplish Y?" | "Add a new tenant", "Rotate the signing key" |
| **Tutorial** | "I'm new — walk me through it" | First-day onboarding, first-feature path |
| **Explanation / ADR** | "Why is it this way?" | Architecture, design tradeoffs, history |

When in doubt, name the audience and what they'll do next. That tells you the type.

## ADRs — Architectural Decision Records

An ADR is a short note explaining one decision. Not a design doc. Not a future plan. A decision that was made, why, and what was rejected.

### When to write one

- Choice between non-trivial alternatives (Postgres vs SQLite, REST vs gRPC)
- Choice that's hard to reverse later (auth model, tenant isolation strategy, billing source of truth)
- Choice that surprises new readers ("why on earth is this synchronous?")
- Convention that will repeat across many places (naming, error format, time zones)

### Structure (one page max)

```
# ADR-NNN: [Decision in active voice — "Use Postgres for primary store"]

Date: YYYY-MM-DD
Status: proposed | accepted | superseded by ADR-MMM
Authors: [names]

## Context
What forces us to decide. Constraints, requirements, failed alternatives we
already tried, the parts of the system this touches.

## Decision
What we are doing, in 2-5 sentences. Active voice. Specific.

## Alternatives considered
What else we looked at. One paragraph each. Why each was rejected.
This is the part future readers will care about most.

## Consequences
What gets easier. What gets harder. What new risks we accept. What we'll
need to revisit if X changes.
```

ADRs are immutable. If the decision changes, write a new ADR that supersedes it. Don't edit history.

## Reference docs — survive when nobody updates them

Reference docs rot fast unless they're generated or proximate to the code:

- **Generate from source** when possible — OpenAPI from handlers, type docs from types, CLI help from argument parsers.
- **Co-locate** when not — the README in the directory, not in a far-off `docs/` tree, gets updated.
- **Test the examples** — runnable snippets in CI catch rot. A code block that no longer compiles is worse than no code block.
- **Date material that ages** — costs, limits, perf numbers — note the measurement date.

## How-tos — answer one task, end-to-end

Format:

```
# How to [task]

When to use this: [one sentence]
Prerequisites: [what reader must have / know first]
Time: [rough budget — 5 min, 1 hour]

## Steps
1. [Action] — [what should happen]
2. [Action] — [what should happen]
...

## Verify it worked
[Concrete check the reader can run]

## If it didn't work
[Top 2-3 failure modes and fixes]

## See also
[Related how-tos / references]
```

Skip motivation, philosophy, and history. Those belong in Explanation.

## Runbooks — for someone tired at 3 AM

Runbooks are for the on-call who didn't write the system. Optimize for that reader.

- Start with **symptoms** ("alert X firing", "users seeing Y") — they read symptom-first.
- One section per symptom, with **immediate actions** at the top.
- Include **commands** the reader copy-pastes. Not screenshots that go stale, not "you can use kubectl to see..." prose.
- Note **what's safe to do without paging someone** vs. what needs escalation.
- Update after every incident — the postmortem feeds the runbook.

## Common mistakes

- Writing a "design doc" instead of an ADR — five pages of context, no decision
- ADR with no rejected alternatives — future readers can't tell why you picked this
- Reference docs in a separate `docs/` repo that nobody syncs
- How-to that explains the philosophy of the system instead of the steps
- Runbook full of "you might want to consider checking..." instead of `kubectl get pods -n foo`
- Tutorial that assumes the reader already knows the thing the tutorial teaches
- Editing ADRs in place when the decision changes (history vanishes)
- One giant `README.md` that's reference + how-to + tutorial + history

## Quick reference

| Reader's question | Doc type | Length target |
|-------------------|----------|---------------|
| What is this thing? | Reference | as long as needed, generated where possible |
| How do I do X? | How-to | 1 page, recipe-style |
| I'm new, where do I start? | Tutorial | walk-through, takes ~30 min to follow |
| Why was this built like this? | ADR / Explanation | 1 page ADR, longer for explanation |
| It's broken and I'm on call | Runbook | symptom-first, copy-paste commands |

## Maintenance

- Date everything that ages. Include a "last verified" line.
- When you change code, ask "is there a doc that just became wrong?"
- Delete docs for systems that no longer exist. Stale docs poison trust in fresh ones.
- Index from a single starting point — README → directory of doc types → individual docs.

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "We'll remember why we made this decision" | You won't. 6 months out, neither will the new hire. ADRs are cheaper than re-running the decision conversation. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
