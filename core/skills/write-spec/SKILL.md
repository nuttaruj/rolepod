---
name: write-spec
description: Use when turning a fuzzy goal, half-stated feature, or vague request into a sharp implementation spec. Discovery dialogue first, then design, then user approval, then a compact contract. Phase = Define.
when_to_use: when the user request is non-trivial and the goal, scope, success criteria, or risk surfaces are not already pinned down in the conversation or in the repo
tier: 1
phase: define
---

# Write Spec

Define-phase entry skill. Convert a vague request into a sharp spec the next phase can execute against. Discovery questions one at a time, design alternatives, user approval, compact contract.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER skip the spec when the goal, scope, or success criteria are ambiguous, or when the request touches a high-risk surface (auth, billing, migration, data deletion, security).
2. NEVER start implementation before the user approves the design direction.
3. ASK one focused question at a time during discovery unless the user explicitly asks for a full questionnaire.
4. NEVER ship a spec that contains placeholders, contradictions, or untested assumptions about the user's intent.
</EXTREMELY-IMPORTANT>

## When to use

- User asks for a feature with vague boundaries
- Multiple valid implementations exist and the choice changes the diff
- The request touches a high-risk surface
- The codebase has no existing pattern for this work
- The user said "build me X" without details

Skip when:
- The task is a one-line fix with an obvious diff
- The user has already supplied a written spec
- The user explicitly says "skip spec" or "just write the code"

## Inputs to gather

- Exact user request (literal quote)
- Repo state relevant to the request (existing patterns, prior decisions)
- Constraints the user has already stated (deadline, stack, no-touch zones)
- High-risk surfaces likely touched

## Workflow

### 1. Frame the goal

State the user goal in one sentence. State 2-3 likely constraints. Flag any high-risk surface up front.

### 2. Discovery dialogue

Ask up to 5 targeted questions, one at a time. Each question must change the implementation if the answer changes. Skip obvious questions. Use the native question UI when available; otherwise plain-text prompts.

### 3. Present 2-3 approaches

When the design has meaningful options, lay out 2-3 viable approaches with tradeoffs (complexity, blast radius, reversibility, cost). Recommend one. The simplest viable approach wins by default.

### 4. Self-review the draft

Scan for:
- Placeholders (`TODO`, `<...>`, `tbd`)
- Contradictions between sections
- Ambiguous wording ("maybe", "should", "if needed")
- Scope creep beyond the user request
- Over-engineering for hypothetical needs

### 5. Get user approval

Present the proposed spec. Wait for the user to accept, edit, or reject the direction. Do not proceed to planning before approval.

### 6. Produce the contract

A compact spec artifact: goal, non-goals, constraints, success criteria, high-risk surfaces, chosen approach with rationale, open questions if any.

## If a matching Rolepod agent is available

Delegate discovery / drafting to the most appropriate specialist:

- `product-manager` for feature scope, user stories, success criteria
- `system-architect` for API / data-model / integration design
- `tech-writer` for ADRs and durable spec artifacts
- `business-analyst` for cost / ROI / commercial framing

Brief the agent with the user request, the discovery questions answered so far, and the approval gate the user expects.

## If no matching agent is available

Execute the discovery + design checklist directly as Lead. Use this minimum viable checklist:

1. Quote the user request literally
2. List goals and non-goals
3. Name the high-risk surfaces touched
4. Ask the smallest set of questions needed
5. Sketch 2-3 viable approaches with tradeoffs
6. Recommend one approach with rationale
7. Wait for user approval before continuing
8. Save the spec inline or as `docs/specs/<feature>.md` if the work spans more than one session

## Output format

A compact spec artifact (inline or file) with these sections:

```
Goal
Non-goals
Constraints
Success criteria
High-risk surfaces
Approach (chosen, with rationale)
Open questions (if any)
```

For repeat work or multi-session features, save to `docs/specs/<feature>.md`. For one-session work, inline in chat is enough.

## Hard stops

- Goal still ambiguous after 5 questions → ask the user to choose between two concrete framings
- User declines to approve any approach → stop, report what is blocking
- A high-risk surface is touched without a security / migration / audit plan → stop, route to `review-code` first

## Full Rolepod enhancement

Full Rolepod improves this phase by adding router continuity into `write-plan`, specialist agents for deeper domain shaping, hooks that remind on high-risk surfaces, and tests that prove the spec did not leak placeholders.

## Next phase

- If `write-plan` is available, continue there with the approved spec.
- If `write-plan` is not available, hand off using this Implementation Plan Outline: files to touch, ordered tasks, test plan, risks, done criteria.
