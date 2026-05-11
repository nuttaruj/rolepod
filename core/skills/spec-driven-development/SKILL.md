---
name: spec-driven-development
description: Write a structured spec before writing code. Use at the start of a new feature, project, or significant change when requirements aren't yet pinned down. Produces a PRD-style document that becomes the contract for implementation.
---

# Spec-Driven Development

Most rework comes from building the wrong thing well. A spec doesn't slow you down — it front-loads the disagreements and unknowns when they're cheap to resolve. This skill turns a fuzzy idea into a document that engineers can build from and stakeholders can sign off on.

## When to use

- New feature with non-trivial scope
- Project has multiple stakeholders with different mental models
- Requirements have been changing turn-to-turn
- Cross-team work where misalignment is expensive
- Anything you'd regret building wrong (auth, billing, data integrity, public APIs)

Skip when: the change is small and the answer is obvious; you're prototyping to learn, not shipping; the spec already exists and is current.

## HARD-GATE: spec required before Build-phase skills

<EXTREMELY-IMPORTANT>
The following skills CANNOT BE INVOKED for a non-trivial feature until a written spec exists, has been user-approved, and is saved to `docs/specs/<feature>.md`:

- `test-driven-development` (writing implementation tests)
- `frontend-ui-engineering`
- `interface-design`
- `interaction-design`
- `claude-api` (when building agentic features beyond a single call)
- `api-and-interface-design` (when defining new public surface)
- backend code generation
- any skill in the **Build** phase of the lifecycle taxonomy

If you attempt to invoke a Build-phase skill without a spec for a non-trivial feature:
1. STOP
2. Invoke this skill (`spec-driven-development`) first
3. Get user approval on the written spec saved to `docs/specs/<feature>.md`
4. Only then proceed to Build-phase work

This gate exists because feature-without-spec = 41% probability of scope drift (DAPLab failure-pattern data). "I'll iterate the spec in code" is the rationalization that produces the rework you tried to avoid.

Skip cases (gate does NOT apply): typo / comment / docstring / one-line config / pure rename / dead-code removal / bug fix with reproducer / prototype explicitly scoped to learning.
</EXTREMELY-IMPORTANT>

## What a good spec is — and isn't

A spec describes **what** and **why**. It does not lock down **how**. Implementation freedom matters because the engineer (or future-you) will see the codebase context the spec author can't.

Spec **is**: scope, user outcomes, success criteria, constraints, open questions.
Spec **is not**: function names, file structure, choice of library, line-by-line behavior.

If your spec reads like pseudocode, you're writing a design doc. Different artifact, later phase.

## Spec template

```
# [Feature name]

Status: draft | in review | approved | superseded
Author: [name]
Date: YYYY-MM-DD
Stakeholders: [who must sign off]

## Problem
What's broken, missing, or worth doing. One paragraph. Specific.
Not "users want more features" — "support sees 12 tickets/week from
users who can't recover their account when they lose 2FA."

## Goals
What we're solving. Bulleted, measurable where possible.
- Reduce 2FA-recovery support tickets to <2/week
- Median recovery time <10 minutes
- No new attack surface for account takeover

## Non-goals
What we are explicitly not doing. This is the most-skipped, most-valuable section.
- Not building self-serve recovery for users without backup codes
- Not changing the SMS-fallback policy

## Users / personas
Who's affected. What they're trying to do.

## User stories / scenarios
Concrete walk-throughs. Happy path + at least 2 edge cases.

## Requirements
Functional: what the system must do.
Non-functional: performance, security, accessibility, compliance.

## Success criteria
How we'll know it worked. Metrics, tests, or qualitative bar.

## Constraints
Time, budget, technical, regulatory, brand.

## Open questions
Things we don't yet know that block the decision. Each one needs an
owner and a target resolution date.

## Out of scope (for this version)
What's explicitly punted to later. Saves arguments later.

## Risks
What could go wrong, ordered by impact * likelihood.

## Rollout
Phasing, flagging, audience, fallback. (Brief — full launch plan
lives in shipping-and-launch.)
```

## How to apply

### 1. Start with the problem, not the solution

Write the Problem and Goals sections first. If you can't fill these without naming a solution, the user need isn't pinned down yet — go talk to users (or the user who's asking).

### 2. Write Non-goals early

Non-goals catch scope creep before it starts. Stakeholders argue about scope; non-goals prevent the argument from happening twice.

### 3. Walk the scenarios

For each user story, walk through it concretely. What does the user see, click, type? What does the system do? What does the user see next?

This phase finds 80% of the missing requirements. Edge cases surface here.

### 4. Mark unknowns explicitly

Open questions that block the decision get a name and an owner. Open questions that don't block ("what color is the button?") aren't spec material.

### 5. Get sign-off before implementing

The spec is a contract. Send it to stakeholders, get changes, get approval. Implementation against an unsigned spec is rework waiting to happen.

### 6. Update or supersede — never silently rewrite

If reality contradicts the spec mid-build:
- **Small drift** — note it, get a thumbs up, keep going.
- **Big drift** — pause, update the spec, re-confirm sign-off.
- **Different feature now** — supersede with a new spec.

Don't quietly build something different from what was approved.

## Interview the user (when scope is vague)

Big features often arrive as one-line requests. Before drafting:

```
Interview me. Cover:
- The user's actual current behavior (not just the request)
- What they'd do if this didn't get built
- Edge cases I haven't named
- Tradeoffs they're willing to accept
- What "good enough for v1" looks like
```

Surfaces things the user hasn't yet considered. Cheaper than discovering them at implementation.

## Common mistakes

- Spec that prescribes implementation ("use Redis with TTL=60s") — that's design, not spec
- No Non-goals — the feature grows until it's everything
- Vague goals ("better UX") — write the metric or write nothing
- Open questions left as rhetorical — assign an owner
- Skipping success criteria — "we'll know it when we see it" is how scope wars start
- Spec written in isolation — stakeholders approve, then disown
- Spec frozen forever — reality wins, the spec must evolve or be replaced
- Treating the spec as paperwork — paperwork is what specs become when no one uses them; if no one uses it, write less of it next time

## Quick reference

| Symptom in execution | Likely spec gap |
|----------------------|-----------------|
| "Wait, are we doing X too?" | No Non-goals section |
| "How will we know this works?" | Missing success criteria |
| Multiple rebuilds of same component | Requirements too vague |
| Stakeholder surprised at demo | Skipped sign-off |
| Engineer paralyzed | Spec over-prescribed implementation |

## Output checkpoint

After draft, before implementation, confirm:

```
Spec status: [draft → review → approved]
Sign-off from: [names]
Open questions still blocking: [list, or "none"]
Implementation start condition: [what must be true to begin]
```

Don't start building until that checkpoint is clean.

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "Spec slows me down, I'll iterate in code" | Iterating in code without a spec = redoing the spec implicitly, in PR cycles, with more cleanup. Write 1 page first; ship faster overall. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
