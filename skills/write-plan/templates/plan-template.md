<!-- Rolepod plan template — the canonical Plan-phase artifact. -->
<!-- Keep the execution contract complete. Omit conditional sections when not applicable; delete remaining hints. -->
<!-- Tasks use - [ ] checkboxes so progress survives session compaction. -->

# <Feature> Plan

**Goal:** <one sentence describing the outcome>
**Architecture:** <2-3 concise sentences describing the approach>
**Stack:** <key libraries / frameworks / services this plan depends on>

---

## Source spec
<Approved spec path, or the clear goal that supplies requirements>

## Tasks
<One task per review gate. Keep the planned contract here; record status by checkbox and deviations under Changes during build.>

### Task 1: <title>
- **Delivers:** <observable outcome>
- **Blocked by:** <Task N (the contract or output consumed), or none>
- **Track:** <track id from ## Tracks — delete this line when the plan has no ## Tracks>
- [ ] **Files:** <paths this task touches>
- **Read first:** <2-3 files and the pattern to copy>
- [ ] **Change:** <ordered stages, one indented `- [ ] <step>` each (no timed micro-steps;
      no bold label or field name first). An exact-string
      edit spec (old → new) goes in a fenced block under this task, never
      inline in the bullet. A clause of the spec's agreed contract this task
      builds or consumes (interface, data shape, compatibility rule, invariant)
      is quoted here or in Done when — the owner sees only the brief.>
- [ ] **Test / evidence:** <test or evidence type, assertion, and seam from Testing decisions; explain any new seam.>
- **Proof:** <one reviewer-checkable claim> :: `<command that proves it>` (optional)
- [ ] **Expected failing signal:** <failure observed before the fix; omit if not test-first>
- [ ] **Command:** <exact, runnable check covering this task>
- **Owner:** <The role you pick for this task's Files from the agent listing — each
      description names its scope. `Lead` for R1-sized work or when the user said
      self-do. A vertical slice has ONE owner: the role of its dominant layer (the
      risk, else most files) builds the whole slice, thin ends in other layers
      included; two full-depth layers → two slices joined by Blocked by. A
      high-risk write goes to the path's owner and the High-risk surfaces line
      names the task.>

- **Done when:** <pass/fail condition; a changed rule also names the nearest inputs whose result stays the same>
- **On fail:** <non-default recovery, if any. Omit to use the Failure policy below.>

### Task 2: <title>
<same shape — checkbox each step>

## High-risk surfaces touched
<Name each touched surface on the high-risk list (`using-rolepod` Stop conditions) and every task that touches it. State None when applicable.>
- <surface> → Task <N>

## Spec coverage (both directions)
<Each requirement → the task that proves it (one task may prove several); each task → its source requirement. Move unrequested work to Follow-ups.>
- <spec requirement> → Task <N>

## Parallel layout
<Sequential — one owner (reason optional), or Parallel — contract: <path>. Task order lives in Blocked by.>

## Tracks
<Optional — only when the plan runs as tracks; none → delete this section. One line per track. `<feature>` = plan file name without date.>
- <A> — <short name>: Task <N>, Task <M> · branch <feature>/<a>-<short-slug>

## Ship groups
<Optional — only when tasks share a seam (a contract or interface): one line
 per group; none → delete this section. A seam list for the final branch
 review, not a review.>
- **Ship group:** <name> — Task <N>, Task <M> — seam: <the shared contract / interface>

## Done criteria
<The whole-plan finish line. Every task done AND this is true.>

## Failure policy
Default: a failing **Command** → debug-issue (reproduce → minimal fix →
re-run the same Command). Count failed fixes for the same unresolved repro or
criterion across owners and phases. After 2 failures, get one Second opinion;
attempts 3 and 4 require a fresh trace and use its advice. No usable advisor
means stop before another fix; after 4 failed fixes, stop: an owner returns BLOCKED with the attempts; the Lead asks the user.
Keep review rounds separate; they never reset fix attempts. Also stop on
oscillation (a fix for one task reopens another). A task needing a
different fallback states it in its **On fail:**.
<This default is body text, NOT a hint — keep it in the filled plan (the
 circuit-breaker must survive in the artifact so the build loop runs without
 the always-on core). Add plan-specific deviations below it, then delete
 this hint.>

## Risks
<What could go wrong, and the fallback.>

## Changes during build
Changes during build holds one line per task (`- Task N (`sha`): <verdict> -> <task file>`, at most 300 chars) and one line per deviation; review rounds, findings and handoffs live in the task file, never here. Empty until the build starts.

## Follow-ups
<Append-only. Ideas and scope that surfaced during planning or build and were
 NOT built — one line each: what, why parked, the spec line it would need.
 The Lead writes here instead of expanding scope; owners note it in the receipt; finish-work carries
 every line out with a destination (next spec / issue / dropped + why).>
