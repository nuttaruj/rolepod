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
- [ ] **Command:** <exact command to run the test, if known>
- **Owner:** <Lead, or the specialist agent if delegated>
- **Done when:** <pass/fail condition>

### Task 2: <title>
<same shape — checkbox each step>

## High-risk surfaces touched
<auth / billing / migration / data deletion / security. "None" is valid —
 but state it deliberately.>

## Parallel layout
<If one owner: "Sequential — single owner." plus the task dependency order.
 If more than one agent edits code: name the cohesion contract path and the
 merge order — see templates/cohesion-contract-template.md.>

## Done criteria
<The whole-plan finish line. Every task done AND this is true.>

## Risks
<What could go wrong, and the fallback.>
