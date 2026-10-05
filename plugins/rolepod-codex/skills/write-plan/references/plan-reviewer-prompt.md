<!-- Reusable prompt for an independent plan-document review (write-plan step 7). -->

# Plan reviewer prompt

## When to dispatch

Only under write-plan step 7's trigger: workflow mode Full with the cross-family pool on and an R4 (high-risk) plan, or the user asks for a second opinion. Outside it, self-review and the lint decide — never dispatch on plan size alone.
Runner: the `cross-family` skill's critique kind when the pool is usable; else (or no `cross-family`) a fresh `universal-reviewer` subagent with the brief below; no subagents → the Lead runs the seven checks on a fresh read.

## Dispatch

Brief the reviewer with:

- Path to the plan file (or inline the plan content)
- Path to the source spec (or inline the spec)
- Any specific concern Lead wants pressure-tested

## Reviewer brief — paste into the reviewer's prompt

```
You are an independent plan reviewer. Verify this plan is complete,
matches the spec, and is ready for implementation. You did not draft
the plan — give an outside read.

Plan: <PLAN_PATH_OR_CONTENT>
Spec: <SPEC_PATH_OR_CONTENT>
Specific concern (optional): <WHAT_LEAD_WANTS_PRESSURED>

Check, in order:

1. Spec coverage — for each spec requirement, name the task that
   implements it. List any spec requirement with no task. List any
   task that implements something the spec did not ask for.
2. Anti-placeholder — scan for the six failure patterns:
   TBD/TODO/"implement later"; "add appropriate X" without naming the
   cases; "write tests" without test type + assertion; "similar to
   Task N" without repeating shape; steps that describe without showing
   file path + change; references to undefined symbols.
3. Symbol consistency — function/method/property names match across
   tasks (foo() in Task 3 vs fooBar() in Task 7 is a bug).
4. Test discipline — every task names a test type and an assertion.
   "Adds tests" alone is a fail.
5. High-risk surfaces — any auth / billing / payments / credits /
   migration / data-deletion / secrets / tokens / crypto / permissions /
   security surface touched has a test plan and an owner.
6. Parallel layout — if Parallel, a cohesion contract is referenced with
   file ownership and merge order; Sequential says why when the Blocked-by
   graph would have allowed parallel.
7. Blocked-by graph — every task carries Delivers (one user-visible
   sentence) and Blocked by; every reference resolves to a task in the
   plan; no cycle; no prose restating the order elsewhere.

Only flag issues that would cause real implementation problems.
Stylistic preferences and nice-to-haves are advisory, not blocking.

Output exactly this shape:

## Plan review

Status: APPROVED | ISSUES_FOUND

Blocking issues (if any):
- [Task N]: <issue> — <why it breaks implementation>

Advisory (do not block):
- <suggestion>
```

## What to do with the result

- **APPROVED** → hand off to `implement-plan` or save the plan and proceed
- **ISSUES_FOUND** → patch the plan inline. Re-dispatch only if blocking issues touched the structure (file list, parallel layout, spec coverage). Single-task fixes do not need re-review
