<!-- Deep playbook for dispatching implementer subagents from implement-plan. -->
<!-- Loaded on demand from SKILL.md §4 + §6 + §7. -->
<!-- Lead-as-controller pattern: controller curates context; subagent stays focused. -->

# Subagent dispatch

The Lead is a **controller**. A subagent gets only the context the controller curates — never the Lead's session history, never the plan file path. Pass full task text inline; that is the contract.

## Why fresh context per task

Context pollution = the #1 silent failure mode in multi-task execution. The subagent that just shipped Task 1 carries Task 1's mental model — its symbols, its trade-offs, its half-finished considerations. Reusing it on Task 2 leaks that state into the new diff. Symptoms: cross-task naming drift, refactors that touch Task 1 from Task 2, copied patterns that no longer fit.

Fresh subagent per task = no leakage. Cost: extra dispatch overhead. Buy: clean blast radius, faster review.

## Implementer status taxonomy

The implementer manifest declares `COMPLETED | PARTIAL | BLOCKED` (the enum every agent brief and `agent-protocol.md` teach) plus a **Concerns** section. Handle each with a specific protocol.

### `COMPLETED`, Concerns empty

Implementation complete, tests green, self-review clean, no doubts flagged.

**Action:** proceed to §6 spec-compliance review.

### `COMPLETED`, Concerns listed

Work complete, but the implementer flagged doubts in the manifest's Concerns section.

**Action:** read concerns first. Classify each:
- **Correctness concern** (e.g., "I'm not sure this handles the empty case") → resolve before review. Either confirm coverage exists or send back to implementer with the case named.
- **Scope concern** (e.g., "this change spilled into module Y") → resolve before review. Confirm scope or roll back the spillover.
- **Observation** (e.g., "this file is getting large") → note in plan follow-ups; proceed to review.

Never proceed to review with unresolved correctness or scope concerns.

### `PARTIAL`

Some of the task is done; the manifest states what remains.

**Action:** review the completed slice (§6 Stage 1 on the diff so far), then redispatch the stated remainder as its own narrowed brief — fresh context, same model. Do not merge an unreviewed partial into the next task's diff.

### `BLOCKED`

The implementer cannot complete the task; the manifest states what blocks and what is needed.

**Action:** never re-dispatch unchanged. Read "what is needed" and change at least one variable:
1. **More context** — the brief was incomplete (a missing file path, API contract, constraint); expand the brief and redispatch the same model, fresh context. The subagent is not at fault; the controller's brief was.
2. **Stronger model** — task complexity exceeded the model tier; redispatch at the next tier
3. **Smaller scope** — task is genuinely two tasks; split in the plan and redispatch the smaller one
4. **Escalate** — the plan itself is wrong; return to `write-plan`

Re-dispatching unchanged = Hard stop.

## Two-stage review per task

Both stages mandatory for delegated work. Lead-executed tasks collapse to one self-review with a fresh-context pause.

### Stage 1 — spec compliance

The reviewer reads the diff alone and answers: does this match the task spec exactly?

- ✅ approved → proceed to Stage 2
- ❌ issues → list missing requirements and unrequested extras; implementer fixes; re-dispatch Stage 1 (not Stage 2 yet)

Spec compliance is binary. "Close enough" = not done.

**Prompt scaffold:**

```
You are reviewing whether a diff matches a task spec exactly. You did not write
the code. Read both, and answer one question:

Does the diff implement exactly what the spec asks — no missing requirements,
no extras?

Spec: <TASK_SPEC_INLINE>
Diff: <git diff --base=... --head=...>

Output:
- Status: APPROVED | ISSUES_FOUND
- Missing (if any): bullet list, each citing spec line + missing diff
- Extra (if any): bullet list, each citing diff line + why it is out of spec
```

### Stage 2 — code quality

After Stage 1 approves, dispatch a separate code-quality reviewer on the same diff.

- Patterns match existing code?
- DRY / single source of truth?
- Test strength (negative + positive)?
- Smell (dead code / commented blocks / magic constants)?

Stage 2 is **not** a place to surface missed-spec issues — that's Stage 1's job. Reviewer scope: how well-built, not what was built.

**Prompt scaffold:**

```
You are reviewing code quality. You did not write the code. Spec compliance is
already confirmed in a prior pass — focus on how well-built the change is, not
what it does.

Diff: <git diff>
Touched files end-to-end: <paths>

Check: patterns match local style; DRY violations; test assertions strong;
no dead code / magic numbers / commented blocks; symbol names consistent
across diff hunks.

Output severity-ordered findings: BLOCKER / MAJOR / MINOR / NIT.
Approve when nothing remains above MINOR.
```

### Final whole-implementation review

After all per-task reviews pass, dispatch one reviewer on the cumulative diff. Per-task reviews catch local issues; the final pass catches cross-task drift the per-task reviewers cannot see (any one of them only saw their slice).

What it catches:
- Type / symbol / method name drift between tasks (Task 3 named `clearLayers()`; Task 7 called `clearFullLayers()`)
- API contract mismatch between producer and consumer tasks
- Unowned files in a parallel layout (no task claimed them; an implementer touched anyway)
- Architecture creep — pattern X used in Tasks 1-2, pattern Y in Tasks 3-4

Hand off to `check-work` only after the final review clears.

## Model selection

Use the least powerful model that can handle the role. Cost compounds across N tasks × M reviews.

| Role | Signals | Model tier |
|---|---|---|
| **Explorer / scout** | Read-only wide sweep — repo or online sources; returns a research report (conclusion + file:line / URL pointers), never dumps; never edits. Dispatch the `scout` agent when available — it carries the report contract and tool restriction | Fast / cheap |
| **Implementer — mechanical** | 1-2 files, complete spec, isolated logic, no API contract change | Fast / cheap |
| **Implementer — integration** | Multi-file, pattern matching, debugging touch | Standard |
| **Implementer — architecture / judgment** | Broad codebase, design tradeoffs, new abstraction | Most capable |
| **Spec-compliance reviewer** | Comparing diff to spec, binary check | Standard |
| **Code-quality reviewer** | Smell / DRY / pattern match | Standard |
| **Final whole-impl reviewer** | Cross-task drift, contract consistency | Most capable |

`BLOCKED` after a fast-model dispatch → re-dispatch the same task at one tier up before escalating to the human.

## Continuous execution rule

On a multi-task plan, do not pause to check in with the user between tasks. The user asked for the plan to be executed; executing it is the answer. "Should I continue?" prompts and progress summaries are noise — the user can read the manifest stream.

Stop **only** when:
1. `BLOCKED` and Lead cannot resolve via the four variable changes above
2. Spec / plan gap that wasn't visible until implementation revealed it
3. Scope ambiguity that genuinely prevents progress (not a stylistic preference)
4. All tasks complete

Anything else = continue.

## Subagent commit policy

The subagent **never** commits. It returns a manifest; the Lead commits. Two reasons:
1. **Atomic accept/reject** — Lead reviewing the manifest can reject without `git reset`. Subagent commits create work that must be undone.
2. **Subagent context boundary** — committing requires knowing the working tree state across tasks. The subagent only sees its own slice. Commit decisions belong to the controller.

This is the opposite of some external subagent-driven patterns where the implementer commits its own work. Stay with Lead-commits — it is load-bearing for the bounded-delegation Iron Rule.

**Comprehension gate — the Lead reads before it commits.** Green gates
(spec-compliance + code-quality + tests) are necessary, NOT sufficient. Before
committing a delegated diff, the Lead reads it and can explain what changed and
why — a diff you cannot explain is not ready to commit, even with every reviewer
APPROVED. Delegation is bounded work you still own, not a diff you rubber-stamp
because the agents said OK; that gap between what shipped and what you understand
is how a delegated codebase rots. Cannot explain a hunk → send it back with the
question, do not commit past it.

## Quick-reference flow

```
Read plan → extract tasks inline → TodoWrite (or Task tool)

For each task:
  Dispatch implementer (model = task complexity tier)
  Implementer asks Q? → answer inline, redispatch
  Implementer returns: COMPLETED | PARTIAL | BLOCKED (+ Concerns section)
    COMPLETED, no concerns → §6 Stage 1 (spec compliance)
    COMPLETED + concerns   → resolve correctness/scope first → §6 Stage 1
    PARTIAL                → review done slice, redispatch remainder narrowed
    BLOCKED                → change a variable, redispatch
  Stage 1 issues? → implementer fixes → Stage 1 again
  Stage 1 approved → Stage 2 (code quality)
  Stage 2 issues? → implementer fixes → Stage 2 again
  Stage 2 approved → Lead reads the diff + can explain it → commits
  Continue to next task — no check-in

After all tasks:
  Final whole-impl review (most capable model)
  Final approved → hand off to check-work
```
