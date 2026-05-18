---
name: spec-driven-development
description: Write a structured spec before writing code. Produces a PRD-style document that becomes the contract for implementation.
when_to_use: at the start of a new feature, project, or significant change when requirements aren't yet pinned down
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

## HARD-GATE: dialogue → spec → approval, before any Build-phase skill

<EXTREMELY-IMPORTANT>
For a non-trivial feature, **two gates** stand between user's request and any code:

**Gate A — Discovery dialogue must run before drafting spec.** Lead does NOT pre-fill the spec template from the request text. Lead runs Phase 0 (below) — one question per message, options with a Recommended pick, 2-3 approaches with tradeoffs — until the spec can be filled without TBDs.

**Gate B — Spec must exist in user-approved form** before any of these fire:

- `test-driven-development` (impl tests)
- `frontend-ui-engineering`
- `interface-design`
- `interaction-design`
- `claude-api` (agentic features beyond single call)
- `api-and-interface-design` (new public surface)
- backend code generation
- any Build-phase skill

**Spec persistence — tiered by risk + scope:**

| Tier | Trigger | Persistence | Approval shape |
|------|---------|-------------|----------------|
| **Small** | ≤1 module, no high-risk surface, no multi-agent, ≤5 vertical slices | Spec lives **in chat** — short brief (problem + goals + non-goals + success criteria, ~10-15 lines). No file. | User replies "approved" / "OK go" in chat |
| **Medium / High-risk** | auth / billing / migrations / payments / public APIs / data deletion / multi-agent / cross-module / >5 vertical slices | Spec saved to `docs/specs/<feature>.md` | User-approved comment on the file (or explicit "approved" referencing the path) |
| **External repo / open source** | Touching a repo where future contributors need the spec | Always save to `docs/specs/<feature>.md` regardless of tier | Same as Medium |

Default: Small if you can defend it; Medium if unsure. When in doubt, file it.

Attempting Build without the appropriate Gate B form:
1. STOP
2. Run Phase 0 (dialogue) → Phase 1 (write spec) → Phase 2 (self-review) → Phase 3 (user approval)
3. For Medium/High-risk: save to `docs/specs/<feature>.md` before invoking Build
4. Then proceed

Feature-without-spec = 41% scope drift (DAPLab). "Iterate spec in code" = the rationalization that produces the rework. **"Too simple to design" is also a rationalization** — write a 5-line brief even for "simple" things; the dialogue takes 60 seconds and prevents the rework.

Gate does NOT apply: typo / comment / docstring / one-line config / pure rename / dead-code / bug fix with reproducer / explicitly scoped prototype / user explicit "skip spec, just code".
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

## The four phases

```
Phase 0: Discovery dialogue  → understand intent + constraints
Phase 1: Draft spec          → fill template, no TBDs
Phase 2: Self-review         → scan placeholder / contradiction / scope / ambiguity
Phase 3: User approval       → sign-off, then Build can fire
```

Lead runs all four in order. Skipping Phase 0 is the most common (and most expensive) failure — Lead pattern-matches the user's one-liner into a half-filled template, user spends approval round filling in blanks Lead should have asked about.

## Phase 0 — Discovery dialogue (the real entry point)

**Goal:** end the phase able to fill the spec template with zero placeholders.

**Method:** structured Q&A, one question per message, 2-4 options each, one option labeled `(Recommended)`. Free-text "Other" always available. The point is **lowering the cost of answering** so the user can shape the spec in 30 seconds of clicks instead of 5 minutes of typing.

**Native question UI (preferred when available):**
- **Claude Code** — invoke the `AskUserQuestion` tool. Renders as a clickable multi-choice prompt with an "Other" free-text fallback.
- **Codex CLI / Gemini CLI** — no structured question tool yet. Emit a plain-text message with the same shape (see below) and wait for the user's reply.

When falling back to plain text, format the question this way so the affordance is identical to the native widget:

```
Q1. <question text>?

  A. <option label> (Recommended)
     <one-line description>
  B. <option label>
     <one-line description>
  C. <option label>
     <one-line description>
  D. Other — reply with free-form text
```

Single question per message regardless of UI — the constraint is about user attention, not tool surface.

### 0.1 — Explore project context FIRST

Before asking the user anything:
- `Read` the relevant existing files (entry points, nearby modules, schema)
- `git log --oneline -20` for recent direction
- Glance at related specs in `docs/specs/`
- `gitnexus_context` / `gitnexus_query` if installed — symbol + concept map

If a clarifying question is answerable from the repo, **answer it from the repo, don't ask the user.** Asking what's already visible burns trust.

### 0.2 — Spot scope before asking details

If the request describes multiple independent subsystems ("build a platform with chat + storage + billing + analytics"), STOP and surface this. Don't burn questions refining a project that needs decomposition first. Help the user split into sub-projects; each gets its own spec → plan → build cycle.

### 0.3 — Ask clarifying questions, one per message

Use the native question UI when present (Claude Code's `AskUserQuestion`); otherwise emit the plain-text format from Phase 0's Method block. Same question content either way.

Example (Claude Code `AskUserQuestion` shape):

```
question: "Who's the primary user for this feature?"
header:   "Primary user"
options:
  - label: "Existing paying customer (Recommended)"
    description: "User who already pays; we know their behavior from telemetry."
  - label: "New free-tier signup"
    description: "Acquisition surface; needs onboarding consideration."
  - label: "Internal admin / ops"
    description: "Internal-only; UX bar is lower, audit bar is higher."
```

Equivalent plain-text (Codex CLI / Gemini CLI fallback):

```
Q1. Who's the primary user for this feature?

  A. Existing paying customer (Recommended)
     User who already pays; we know their behavior from telemetry.
  B. New free-tier signup
     Acquisition surface; needs onboarding consideration.
  C. Internal admin / ops
     Internal-only; UX bar is lower, audit bar is higher.
  D. Other — reply with free-form text
```

Cover (in roughly this order — but adapt based on what the repo already answers):

1. **Primary user** — who, specifically
2. **Current behavior** — what they do today without this feature
3. **Success definition** — what observable state means "shipped well"
4. **Hard constraints** — time / budget / tech / regulatory
5. **Non-goals** — what we're explicitly NOT doing
6. **Edge cases** — at least 2 the user hasn't named
7. **Tradeoffs they accept** — speed vs polish, breadth vs depth, etc.

**Question discipline:**
- One topic per message — if a topic needs depth, break into multiple sequential questions
- Multiple-choice > open-ended (lowers user effort, surfaces options they hadn't considered)
- Always provide a `(Recommended)` option — that's Lead's judgment showing through; user can override
- Stop asking when you have enough to fill the template without TBDs. Don't fish for more.

### 0.4 — Propose 2-3 approaches with tradeoffs

Once intent is clear, **before drafting the spec**, present approaches:

```
Approach A — [name]:    [1-line description] · pros: ... · cons: ... · effort: S/M/L
Approach B — [name]:    [1-line description] · pros: ... · cons: ... · effort: S/M/L
Approach C — [name]:    [1-line description] · pros: ... · cons: ... · effort: S/M/L

Recommended: A — [why, in one sentence].
```

Let the user pick (native widget if available, plain-text format otherwise). Free-text "Other" lets them combine or veto.

Why this matters: the user usually has a preferred approach in their head but didn't state it. Surfacing alternatives gives them a chance to redirect cheaply, before any code or spec is written against the wrong shape.

### 0.5 — Incremental section approval (for nuanced features)

For features with >1 design decision, don't write the whole spec then ask "approve?". Instead present in chunks:

- "Here's the **Problem + Goals** section — does this match your read?" → user adjusts → continue
- "Here's the **Non-goals + Out of scope** section — anything to add/remove?" → continue
- "Here's the **User stories + edge cases** section — did I miss any?" → continue
- ...

Each section gets a tiny approval before the next is written. Catches drift early instead of at full-spec review.

For simple features (≤5-line spec total), skip incremental approval — write the whole thing, one approval round.

## Phase 1 — Draft the spec

Pick the form by tier (see HARD-GATE → Spec persistence table):

- **Small tier** — write a short brief directly in chat (problem + goals + non-goals + success criteria, ~10-15 lines). No file. Skip the full template.
- **Medium / High-risk / External repo** — fill the full template and save to `docs/specs/<feature>.md`. Commit the file with the implementation later.

**Either form: No TBDs, no "TODO".** If a slot is genuinely deferrable, write `Out of scope (this version): X — revisit when Y`. Deferral is a decision; "TBD" is a half-decision.

### Apply these as you draft

- **Problem before solution** — Problem + Goals must read coherently without naming any implementation. If you can't fill these without naming Redis / React / a specific table, Phase 0 didn't surface the actual user need; go back.
- **Non-goals early** — write Non-goals + Out of scope BEFORE Requirements. Catches scope creep before it lands in the requirement list.
- **Walk scenarios concretely** — "user clicks X, sees Y, types Z" for happy path + ≥2 edge cases. Surfaces 80% of missing requirements.
- **Mark blocking unknowns with owners** — Open questions that block decisions get owner + target date. Non-blocking ("button color?") aren't spec material — strip them.

## Phase 2 — Spec self-review (before showing the user)

After writing the spec, **read it fresh** through this checklist. Fix inline; don't make the user catch these.

### 2.1 Placeholder scan
- Any `TBD` / `TODO` / `???` / `<fill in>` / "to be determined" / "we'll figure out" / "depends" / "later"? → Resolve or move to Out-of-scope.
- Any section header with one-line content that's obviously a stub? → Fill or remove.

### 2.2 Internal consistency
- Does the **Architecture** described match the **Requirements**? (e.g., requirement says "real-time updates" but no streaming surface in the design)
- Do **Success criteria** actually measure the **Goals**? (Goal: "reduce signup friction." Success: "p50 signup ≤45s" — match. Success: "100 daily signups" — mismatch, measures volume not friction.)
- Do **Non-goals** contradict any **Requirements**? (Both saying "must support SSO" + "SSO out of scope" = pick one)
- Do **User stories** all map to a **Requirement**? Orphan stories = either a missing requirement or a story that doesn't belong.

### 2.3 Scope check
- Is this a single coherent feature, or did three features sneak in?
- Can one implementation plan cover the whole spec, or does it need decomposition into 2+ specs?
- If scope spans >5 vertical slices (per `planning-and-task-breakdown`), strong signal to split.

### 2.4 Ambiguity check
- Pick any 3 requirements at random. Could each be interpreted two different ways by a reasonable implementer?
  - "fast" → state the p95 budget
  - "secure" → state which threat model
  - "configurable" → state which knobs, who turns them
- If yes, pick one interpretation and make it explicit.

### 2.5 "Skim test"
- Read only the section headers + first sentence of each. Could a stakeholder approve from that alone? If no, the lead sentences are buried — rewrite them.

Fix all findings inline. **No round-trip with the user for self-review findings.** Phase 2 ends when the spec passes its own checklist.

## Phase 3 — User approval (sign-off)

Present the spec for approval. Format depends on tier:

**Small tier (in-chat brief):**
> "Here's the brief — problem, goals, non-goals, success criteria. Passed self-review. Reply 'approved' / 'OK go' to proceed, or call out anything off."

**Medium / High-risk / External (saved file):**
> "Spec drafted at `docs/specs/<feature>.md`. It passed self-review (no placeholders, scope checked, ambiguities resolved). Please skim — request changes if anything's off, or approve so we can move to planning."

Wait for explicit approval. If user requests changes:
- Make them
- Re-run Phase 2 self-review (changes can introduce new contradictions)
- Re-present

Only proceed to `planning-and-task-breakdown` once approval is on the table.

### Spec = contract. Update or supersede — never silently rewrite

- Small drift mid-build — note, thumbs up, continue
- Big drift — pause, update, re-confirm sign-off
- Different feature emerging — supersede with a new spec, link old → new

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
Phase 0 dialogue: [N questions asked, approach picked, or "skipped — user authorized"]
Phase 1 draft:    [path to docs/specs/<feature>.md]
Phase 2 self-review: [pass / findings fixed inline]
Phase 3 approval: [user-approved on YYYY-MM-DD] or [awaiting approval]
Open questions still blocking: [list, or "none"]
Implementation start condition: [what must be true to begin]
```

Don't build until Phase 3 lands on "user-approved".

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Spec slows me, iterate in code" | Iterating in code = redoing spec implicitly in PR cycles with more cleanup. |
| "Simple change" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). "Simple" projects are where unexamined assumptions cause the most wasted work. Write a 5-line spec; the dialogue takes 60 seconds. |
| "I already know what the user wants — skip the dialogue" | If you knew, the spec template wouldn't have TBDs in it. Run Phase 0; one round of multi-choice picks costs the user 30 seconds and prevents the 30-minute rework. |
| "I'll just pre-fill the template and let the user correct it" | Drafting first puts the user in editing-mode (reactive) instead of shaping-mode (generative). Phase 0 dialogue first, draft after — the order matters. |
| "Self-review is busywork, ship the draft" | Self-review catches placeholder/contradiction/scope/ambiguity that the user shouldn't be the one to find. Spec quality is Lead's job, not user's. |
| "Time pressure" | Tech debt compounds. |

Default: run all four phases anyway.
