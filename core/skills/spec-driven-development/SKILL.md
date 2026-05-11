---
name: spec-driven-development
description: Write a structured spec before writing code. Use at the start of a new feature, project, or significant change when requirements aren't yet pinned down. Produces a PRD-style document that becomes the contract for implementation.
---

# Spec-Driven Development

Most rework = building wrong thing well. Spec front-loads disagreements when cheap to resolve.

## When to use

- New feature, non-trivial scope
- Multiple stakeholders with different mental models
- Requirements changing turn-to-turn
- Cross-team work where misalignment is expensive
- Anything you'd regret building wrong (auth, billing, data integrity, public APIs)

Skip: small + obvious answer; prototype to learn; spec exists and is current.

## HARD-GATE: spec required before Build-phase skills

<EXTREMELY-IMPORTANT>
These skills CANNOT BE INVOKED for non-trivial features until a written spec exists, user-approved, saved to `docs/specs/<feature>.md`:

- `test-driven-development` (impl tests)
- `frontend-ui-engineering`
- `interface-design`
- `interaction-design`
- `claude-api` (agentic features beyond single call)
- `api-and-interface-design` (new public surface)
- backend code generation
- any Build-phase skill

Attempting Build without spec for non-trivial feature:
1. STOP
2. Invoke this skill first
3. Get user approval, save to `docs/specs/<feature>.md`
4. Then proceed

Feature-without-spec = 41% scope drift (DAPLab). "Iterate spec in code" = the rationalization that produces the rework.

Gate does NOT apply: typo / comment / docstring / one-line config / pure rename / dead-code / bug fix with reproducer / explicitly scoped prototype.
</EXTREMELY-IMPORTANT>

## What a good spec is — and isn't

Spec describes **what** and **why**. Not **how**.

Spec **is**: scope, user outcomes, success criteria, constraints, open questions.
Spec **is not**: function names, file structure, library choice, line-by-line behavior.

Reads like pseudocode → it's a design doc, different artifact.

## Spec template

```
# [Feature name]

Status: draft | in review | approved | superseded
Author: [name]
Date: YYYY-MM-DD
Stakeholders: [who must sign off]

## Problem
What's broken or missing. One paragraph, specific.
Not "users want more features" — "support sees 12 tickets/week from
users who can't recover account when they lose 2FA."

## Goals
What we're solving. Bulleted, measurable.

## Non-goals
What we're explicitly NOT doing. Most-skipped, most-valuable section.

## Users / personas
Who's affected. What they're trying to do.

## User stories / scenarios
Concrete walkthroughs. Happy path + 2+ edge cases.

## Requirements
Functional + non-functional (perf, security, a11y, compliance).

## Success criteria
How we'll know it worked. Metrics, tests, qualitative bar.

## Constraints
Time, budget, technical, regulatory, brand.

## Open questions
Each gets owner + target resolution date.

## Out of scope (this version)
Explicitly punted.

## Risks
Ordered by impact * likelihood.

## Rollout
Phasing, flagging, audience, fallback.
```

## How to apply

### 1. Start with problem, not solution

Can't fill Problem + Goals without naming a solution → user need not pinned. Go talk to users.

### 2. Write Non-goals early

Catches scope creep before it starts.

### 3. Walk scenarios

For each user story: what does user see, click, type? Edge cases surface here. Finds 80% of missing requirements.

### 4. Mark unknowns

Open questions blocking decision get owner + date. Non-blocking ("what color is button?") aren't spec material.

### 5. Sign-off before implementing

Spec = contract. Get changes, get approval. Implementation against unsigned spec = rework.

### 6. Update or supersede — never silently rewrite

- Small drift — note, thumbs up, continue
- Big drift — pause, update, re-confirm sign-off
- Different feature — supersede with new spec

## Interview the user (vague scope)

Big features arrive as one-liners. Before drafting:

```
Interview me. Cover:
- User's actual current behavior
- What they'd do if this wasn't built
- Edge cases I haven't named
- Tradeoffs they accept
- "Good enough for v1" definition
```

## Common mistakes

- Spec prescribes implementation ("use Redis TTL=60s") — that's design
- No Non-goals — feature grows to everything
- Vague goals ("better UX") — write metric or nothing
- Rhetorical open questions — assign owner
- No success criteria — "we'll know it when we see it"
- Spec in isolation — stakeholders approve then disown
- Spec frozen forever — must evolve or be replaced
- Treating spec as paperwork

## Quick reference

| Symptom in execution | Likely spec gap |
|----------------------|-----------------|
| "Wait, are we doing X too?" | No Non-goals |
| "How will we know it works?" | Missing success criteria |
| Multiple rebuilds | Requirements too vague |
| Stakeholder surprised at demo | Skipped sign-off |
| Engineer paralyzed | Over-prescribed implementation |

## Output checkpoint

```
Spec status: [draft → review → approved]
Sign-off from: [names]
Open questions still blocking: [list, or "none"]
Implementation start condition: [what must be true to begin]
```

Don't build until clean.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Spec slows me, iterate in code" | Iterating in code = redoing spec implicitly in PR cycles with more cleanup. |
| "Simple change" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
