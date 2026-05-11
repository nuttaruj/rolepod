---
name: planning-and-task-breakdown
description: Break a goal or spec into ordered, verifiable tasks. Use when work feels too big for a single session, when dependencies are unclear, or when the next step isn't obvious. Pair with spec-driven-development for new features.
---

# Planning and Task Breakdown

Turn "build the thing" into ordered moves with clear "done" conditions.

## When to use

- Spec exists, execution fuzzy
- Task >2h focus, path unclear
- Multiple files/modules change together
- Dependencies matter (DB before API before UI)
- Can't describe first commit
- Work spans sessions

Skip: one file + one verify step / vague goal (refine first) / pure exploration.

## The breakdown loop

```
Goal → Outcome → Tasks → Order → Verify-as-you-go
```

### 1. Goal — one sentence + verifiable outcome

- Bad: "Improve onboarding flow"
- Good: "New users complete signup <60s without support contact"

Can't state this way → problem upstream, go back to specifying.

### 2. Outcome — concrete proof

Tests, metrics, screenshots, log lines:
- Signup p50 ≤ 45s in prod
- 0 support tickets tagged "signup" first week
- E2E passes happy path + 3 failure modes

### 3. Tasks — verb-led with done condition

Each task:
- **Verb-led title** — "Add email verification endpoint", not "Email verification"
- **Done when** — observable state
- **Effort** — S (<2h) / M (half day) / L (>1 day → split)
- **Depends on** — prerequisite tasks

Hard rule: every task has `verify:` clause. No verify = wish, not task.

### 4. Order — sequence by dependency

- **Risky/uncertain first** — bad news late = worst
- **Foundational first** — schema → API → client
- **Independent parallel** — flag for multi-person work
- **Polish last** — animations, copy, edge messages

"All must happen at once" → breakdown wrong, find shippable slice.

### 5. Verify-as-you-go

After each task: run verify, get green, move on. Don't batch. Failure at task 3 = cheap; at task 11 = expensive (tasks 4-10 built on it).

## Task template

```
[ ] T-NN: [verb-led title]
    Done when: [observable state]
    Verify: [test / command / metric]
    Effort: S | M | L
    Depends on: T-MM (or "none")
    Notes: [load-bearing context for future-you]
```

## Slicing — vertical not horizontal

Bad: "Build DB layer" → "Build API layer" → "Build UI". Ships nothing alone, discovers requirements problems only at end.

Good: "End-to-end happy path for one user, one resource, one button" → then add types, edges, polish. Each slice shippable.

## How to apply

1. Write goal sentence + measurable outcome
2. List 3-7 vertical slices
3. First slice → tasks at S/M effort
4. Identify dependencies, order by risk + foundation
5. Pick first task, verify before done, repeat
6. Re-plan after each slice

## Common mistakes

- Tasks named after files ("update auth.ts") not outcomes
- "Done" = "started" ("Begin work on X")
- Estimates skipped → no learning loop
- Polish slices first because they feel productive
- Plan written once, never updated
- Horizontal split → high risk, low value-per-slice
- Tasks too big to verify ("Refactor billing")
- Marking done without running verify

## Quick reference

| Smell | Cause | Fix |
|-------|-------|-----|
| "Done" but tests fail | Verify skipped | Make verify a hard gate |
| Task 3x estimate | Hidden dependency | Stop, re-plan, surface it |
| 20 items after 5 done | Tasks too small | Group into slices |
| Don't know next | Plan stale | Re-plan now |
| Many "almost done" | Vertical-slice violation | Finish one, then next |

## Output format

```
Goal: [one sentence + measurable outcome]
Slices: [N vertical slices]

Slice 1: [name] — ships [user-visible value]
  T-01: [task] | done when: ... | verify: ... | S
  T-02: [task] | done when: ... | verify: ... | M | depends T-01

Slice 2: ...
```

Hand plan to user before starting work.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Have it in my head" | Invisible to collaborators, lost at /clear. Written tasks survive context resets. |
| "Simple change, no skill needed" | DAPLab: 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — skill surfaces what you didn't think of. |
| "Time pressure" | 5 min saved = 50 min debugging later. |

Default: run skill anyway.
