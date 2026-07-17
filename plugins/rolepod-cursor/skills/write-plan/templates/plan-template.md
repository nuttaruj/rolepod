<!-- Rolepod plan template — the canonical Plan-phase artifact. -->
<!-- Fill every section. Delete the <hints>. implement-plan executes this. -->
<!-- Tasks use - [ ] checkboxes so progress survives session compaction. -->

# <Feature> Plan

**Goal:** <one sentence — what this builds, the outcome>
**Architecture:** <2-3 sentences — chosen approach in one breath>
**Stack:** <key libraries / frameworks / services this plan depends on>

---

## Source spec
<Link or one-line pointer to the approved spec this plan implements.>

## Files to touch
<Concrete paths, not categories. One line each, with a word on what changes.>
- `path/to/file` — <what changes>

## Tasks
<Ordered, smallest reversible unit first. Each task is independently
 verifiable. A task whose title needs "and" is two tasks.>

### Task 1: <title>
- [ ] **Files:** <paths this task touches>
- [ ] **Change:** <what to do, concretely>
- [ ] **Test / evidence:** <test type + the assertion that proves it works>
- [ ] **Expected failing signal:** <for test-first tasks — the error the test
      shows before the fix. Omit if not test-first.>
- [ ] **Command:** <exact command to run the check — runnable copy-paste as-is,
      so the build loop can verify this task without guessing>
- **Owner:** <Lead, or the specialist agent if delegated>
- **Done when:** <pass/fail condition>
- **On fail:** <non-default recovery, if any. Omit to use the Failure policy below.>

### Task 2: <title>
<same shape — checkbox each step>

## High-risk surfaces touched
<auth / billing / payments / credits / migration / data deletion / secrets /
 tokens / crypto / permissions / security. "None" is valid — but state it
 deliberately.>

## Parallel layout
<If one owner: "Sequential — single owner." plus the task dependency order.
 If more than one agent edits code: name the cohesion contract path and the
 merge order — see templates/cohesion-contract-template.md.>

## Done criteria
<The whole-plan finish line. Every task done AND this is true.>

## Failure policy
Default: a failing **Command** → debug-issue (reproduce → minimal fix →
re-run the same Command). Stop and escalate to the user after 3 failed
attempts on one task (debug-issue's one cross-model consult and its single
advisor-informed attempt happen inside this stop — never a 5th attempt), or
on oscillation (a fix for one task reopens another). A task needing a
different fallback states it in its **On fail:**.
<This default is body text, NOT a hint — keep it in the filled plan (the
 circuit-breaker must survive in the artifact so the build loop runs without
 the always-on core). Add plan-specific deviations below it, then delete
 this hint.>

## Risks
<What could go wrong, and the fallback.>
