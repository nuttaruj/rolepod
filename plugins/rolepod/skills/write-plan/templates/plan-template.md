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
- **Blocked by:** <Task numbers that must land first, or "none". This field
      IS the plan's order — nothing restates it in prose.>
- [ ] **Files:** <paths this task touches>
- [ ] **Change:** <what to do, concretely — at most 3 bullets. An exact-string
      edit spec (old → new) goes in a fenced block under this task, never
      inline in the bullet.>
- [ ] **Test / evidence:** <test type + the assertion that proves it works>
- [ ] **Expected failing signal:** <for test-first tasks — the error the test
      shows before the fix. Omit if not test-first.>
- [ ] **Command:** <exact command to run the check — runnable copy-paste as-is,
      so the build loop can verify this task without guessing>
- **Owner:** <The role the domain map assigns to this task's Files — path first,
      then concern. `Lead` for R1/R2-sized work (≤2 files) or when the user said
      self-do; from R3 up the map decides. Map:
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
      tests only (a test-authoring task) → qa-tester>
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
