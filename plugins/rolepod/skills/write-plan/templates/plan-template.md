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
 verifiable. A task whose title needs "and" is two tasks. A task block is
 what was PLANNED — it never absorbs build-time narrative: status is the
 checkbox, a deviation is one line under ## Changes during build.>

### Task 1: <title>
- **Delivers:** <one sentence — what a user can do or see once this lands.
      Behaviour, not layers. The line a human reads.>
- **Blocked by:** <Task numbers that must land first, each with what this task
      consumes from it — `Task 2 (its snapshot)` — or "none". This field IS the
      plan's order — nothing restates it in prose; an edge naming nothing is a
      convenience edge: drop it.>
- [ ] **Files:** <paths this task touches>
- **Read first:** <2-3 files + the pattern to copy; the owner starts here, never re-surveys>
- [ ] **Change:** <what to do, concretely — at most 3 bullets. An exact-string
      edit spec (old → new) goes in a fenced block under this task, never
      inline in the bullet.>
- [ ] **Test / evidence:** <test type (unit / integration / contract / E2E / smoke /
      repro) + the assertion that proves it + the **seam** — the public interface the
      test exercises; the owner writes the failing test there first, never against
      internals. No test can express the behaviour yet → 1-3 acceptance criteria the
      reviewer walks, and the Command is the nearest mechanical check (lint /
      typecheck / smoke) — never skipped. Tests cover logic, UI, behaviour: a doc,
      comment, config-text or string-literal change gets NO test (render / lint is
      its check). One test per rule at its owner, one smoke per call site — never a
      test per copy of the rule.>
- **Proof:** <the one claim a reviewer of this task would check by hand> :: `<the command that proves it — exits 0 when the claim holds; an absence check is ! grep>` (optional — it becomes the Lead's spot-check)
- [ ] **Expected failing signal:** <for test-first tasks — the error the test
      shows before the fix. Omit if not test-first.>
- [ ] **Command:** <the tests covering this task's files — every test file that names a file this task
      changes (grep the test dir for each file name, so a removal leaves no stale pin for the release to
      find) — runnable copy-paste as-is; never the whole-repo suite; the owner runs it after each edit and
      last before returning>
- **Owner:** <The role the domain map assigns to this task's Files — path first,
      then concern. `Lead` for R1-sized work or when the user said
      self-do; from R3 up the map decides. A vertical slice has ONE owner: the role
      of its dominant layer (the risk, else most files) builds the whole slice,
      thin ends in other layers included; two full-depth layers → two slices
      joined by Blocked by. Map:
      backend / API routes / services / models / migrations → backend-developer
      components / pages / hooks / state / *.tsx *.vue *.svelte → frontend-developer
      visual polish / design system / a11y / CSS → ui-ux-designer
      billing / payments / credits / subscriptions / invoices → billing-engineer
      auth / permissions / tokens / secrets / crypto (the WRITE) → backend-developer,
        Reviewer security-engineer (security-engineer writes tests only)
      .github/workflows, Dockerfile, compose, vercel/wrangler/fly/railway config,
        deploy/ infra/ terraform/, release scripts, monitoring → devops-sre
      docs, README, runbooks, i18n / locales, emails, marketing copy,
        blog → content-strategist (`audience: dev | user | prospect`)
      ios / android / expo / react-native → mobile-developer
      LLM / RAG / embeddings / prompts → ai-ml-engineer
      analytics / dashboards / pipelines / ETL → data-scientist
      profiling, p95/p99, bundle size, query plans → performance-engineer
      E2E / UI test task → qa-tester (a slice's unit tests belong to its owner)
      another CLI drafts (pool opt-in) → `Owner: <role> · write: external`>
- **Done when:** <pass/fail condition>
- **On fail:** <non-default recovery, if any. Omit to use the Failure policy below.>

### Task 2: <title>
<same shape — checkbox each step>

## High-risk surfaces touched
<auth / billing / payments / credits / migration / data deletion / secrets /
 tokens / crypto / permissions / security. "None" is valid — but state it
 deliberately.>

## Spec coverage (both directions)
<Every spec requirement → the task that implements it; a requirement with no
 task is a plan failure. Every task → the spec line that asked for it; a task
 no spec line asked for is scope creep — cut it or move it to a follow-up list.>
- <spec requirement> → Task <N>

## Parallel layout
<ONE line — the decision, not the order (order lives in each Blocked by).
 "Sequential — single owner." — valid even when the graph would allow
 parallel; say why in a clause. Or "Parallel — contract: <path>" when more
 than one agent edits code (templates/cohesion-contract-template.md pins
 ownership and merge order).>

## Done criteria
<The whole-plan finish line. Every task done AND this is true.>

## Failure policy
Default: a failing **Command** → debug-issue (reproduce → minimal fix →
re-run the same Command). Stop and escalate to the user after 2 failed
attempts on one task (debug-issue's one cross-model consult and its single
advisor-informed attempt happen inside this stop — never a 4th attempt), or
on oscillation (a fix for one task reopens another). A task needing a
different fallback states it in its **On fail:**.
<This default is body text, NOT a hint — keep it in the filled plan (the
 circuit-breaker must survive in the artifact so the build loop runs without
 the always-on core). Add plan-specific deviations below it, then delete
 this hint.>

## Risks
<What could go wrong, and the fallback.>

## Changes during build
<Append-only, written while implementing — never edited into the task blocks
 above. One line per deviation: "Task N — what changed, why". Empty until
 the build starts.>

## Follow-ups
<Append-only. Ideas and scope that surfaced during planning or build and were
 NOT built — one line each: what, why parked, the spec line it would need.
 implement-plan writes here instead of expanding scope; finish-work carries
 every line out with a destination (next spec / issue / dropped + why).>
