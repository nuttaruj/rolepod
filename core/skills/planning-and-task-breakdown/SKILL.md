---
name: planning-and-task-breakdown
description: Break a goal or spec into ordered, verifiable tasks. Use when work feels too big for a single session, when dependencies are unclear, or when the next step isn't obvious. Pair with spec-driven-development for new features.
---

# Planning and Task Breakdown

Big work fails when nobody can name what to do next. This skill turns "build the thing" into a list of moves where each one has a clear "done" condition and the order is defensible.

## When to use

- Spec exists but execution is fuzzy
- Task feels like it needs >2 hours of focus and the path is unclear
- Multiple files / modules / systems have to change together
- Dependencies between steps matter (DB before API before UI)
- About to start coding and you can't describe the first commit
- Work spans multiple sessions / days

Skip when: the change is one file and one verify step, the goal is vague enough that breakdown is premature (refine the goal first), or you're in pure exploration.

## The breakdown loop

```
Goal → Outcome → Tasks → Order → Verify-as-you-go
```

### 1. Goal — what changes for the user / system

State the goal in one sentence, ending in a verifiable outcome.

- Bad: "Improve the onboarding flow"
- Good: "New users can complete signup in under 60 seconds without contacting support"

If you can't state the goal this way, the problem is upstream — go back to specifying.

### 2. Outcome — what proves we're done

For each goal, list the proof. Tests, metrics, screenshots, log lines. Concrete.

- Signup time p50 ≤ 45s in production
- 0 support tickets tagged "signup" in the first week post-launch
- E2E test passes for happy path + 3 known failure modes

### 3. Tasks — the moves

Each task gets:

- **Verb-led title** — "Add email verification endpoint", not "Email verification"
- **One-line definition of done** — what state the world is in when the task is closed
- **Effort estimate** — small (<2h), medium (half day), large (>1 day, should be split)
- **Dependencies** — what must be true before starting this

Hard rule: every task has a `verify:` clause. If you can't say how you'd know it's done, it's not a task — it's a wish.

### 4. Order — sequence by dependency, not preference

- **Risky/uncertain first** — discovery happens in the work, and bad news late is the worst kind.
- **Foundational first** — schema before API, API before client.
- **Independent tasks parallel** — flag them; in a team setting, they unblock multi-person work.
- **Polish last** — animations, copy refinement, edge-case messaging come after the load-bearing parts work.

If the order is "all must happen at once," the breakdown is wrong — find a slice that ships value alone.

### 5. Verify-as-you-go

After each task: run its verify clause, get a green signal, then move on. Don't batch verifications to the end. A failure caught at task 3 is cheap; the same failure caught at task 11 is expensive because tasks 4-10 may have built on it.

## Task template

```
[ ] T-NN: [verb-led title]
    Done when: [observable state]
    Verify: [test / command / metric]
    Effort: S | M | L
    Depends on: T-MM (or "none")
    Notes: [anything load-bearing the future-you needs]
```

## Slicing — vertical not horizontal

Bad slice: "Build the database layer", "Build the API layer", "Build the UI". Each layer ships nothing alone, and you discover requirements problems only at the end.

Good slice: "End-to-end happy path for one user, one resource type, one button" — then add resource types, edge cases, and polish in subsequent slices. Each slice is shippable.

## How to apply

1. Write the goal sentence with a measurable outcome.
2. List 3-7 vertical slices that each move the outcome forward.
3. Inside the first slice, write tasks at the size where each is small or medium effort.
4. Identify dependencies. Order by risk + foundation.
5. Pick the first task. Verify before claiming done. Repeat.
6. Re-plan after every slice — what you learn updates the remaining work.

## Common mistakes

- Tasks named after files ("update auth.ts") instead of outcomes ("require email verification at signup")
- "Definition of done" that's actually "definition of started" ("Begin work on X")
- Estimates skipped — leads to surprises, no learning loop
- Polish slices first because they feel productive
- Plan written once, never updated — first day's plan rarely survives day three
- Splitting horizontally (all DB → all API → all UI) — high risk, low value-per-slice
- Tasks too big to verify ("Refactor billing") — break until each is testable
- Marking tasks done without running the verify clause

## Quick reference

| Smell | Likely cause | Fix |
|-------|--------------|-----|
| "Done" but tests fail | Verify skipped | Make verify clause a hard gate |
| Task taking 3x estimate | Hidden dependency | Stop, re-plan, surface the dependency |
| Plan still has 20 items after 5 done | Tasks were too small to track | Group future tasks into slices |
| Don't know what's next | Plan stale | Re-plan now, before more code |
| Several "almost done" tasks | Vertical-slice violation | Pick one, finish it, then next |

## Output format

```
Goal: [one sentence + measurable outcome]
Slices: [N vertical slices]

Slice 1: [name] — ships [user-visible value]
  T-01: [task] | done when: ... | verify: ... | S
  T-02: [task] | done when: ... | verify: ... | M | depends T-01
  ...

Slice 2: ...
```

Hand the plan back to the user before starting work. Plans that survive contact with reality always start as plans someone agreed to.
