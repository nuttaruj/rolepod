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

## Files to touch
<Concrete paths with a short change description>
- `path/to/file` — <what changes>

## Tasks
<Ordered, independently verifiable tasks. Keep the planned contract here; record status by checkbox and deviations under Changes during build.>

### Task 1: <title>
- **Delivers:** <observable outcome>
- **Blocked by:** <Task N (the contract or output consumed), or none>
- **Track:** <track id from ## Tracks — delete this line when the plan has no ## Tracks>
- [ ] **Files:** <paths this task touches>
- **Read first:** <2-3 files and the pattern to copy>
- [ ] **Change:** <what to do, concretely — at most 3 bullets. An exact-string
      edit spec (old → new) goes in a fenced block under this task, never
      inline in the bullet. A clause of the spec's agreed contract this task
      builds or consumes (interface, data shape, compatibility rule, invariant)
      is quoted here or in Done when — the owner sees only the brief.>
- [ ] **Test / evidence:** <test or evidence type, assertion, and seam from Testing decisions; explain any new seam. Docs, comments, config-text, and string-only changes use a mechanical check. Edge / error / race cases need a criterion or R4 floor.>
- **Proof:** <one reviewer-checkable claim> :: `<command that proves it>` (optional)
- [ ] **Expected failing signal:** <failure observed before the fix; omit if not test-first>
- [ ] **Command:** <exact, runnable check covering this task; not the whole-repo suite>
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
      auth / permissions / tokens / secrets / crypto (the WRITE) → backend-developer;
        its High-risk surfaces line routes security-engineer (who writes tests only)
      .github/workflows, Dockerfile, compose, vercel/wrangler/fly/railway config,
        deploy/ infra/ terraform/, release scripts, monitoring → devops-sre
      docs, README, runbooks, i18n / locales, emails, marketing copy,
        blog → content-strategist (`audience: dev | user | prospect`)
      ios / android / expo / react-native → mobile-developer
      LLM / RAG / embeddings / prompts → ai-ml-engineer
      analytics / dashboards / pipelines / ETL → data-scientist
      profiling, p95/p99, bundle size, query plans → performance-engineer
      E2E / UI flow the spec names → no task; check-work verifies it once
        the feature is built (a slice's unit tests belong to its owner)
- **Done when:** <pass/fail condition; a changed rule also names the nearest inputs whose result stays the same>
- **On fail:** <non-default recovery, if any. Omit to use the Failure policy below.>

### Task 2: <title>
<same shape — checkbox each step>

## High-risk surfaces touched
<Name each touched auth / billing / payments / credits / migration / data deletion / secrets / tokens / crypto / permissions / security surface and every task that touches it. State None when applicable.>
- <surface> → Task <N>

## Spec coverage (both directions)
<Map each requirement to a task and each task to its source requirement. Move unrequested work to Follow-ups. Verify a named user-visible flow once at Verify.>
- <spec requirement> → Task <N>

## Parallel layout
<Sequential — one owner (reason optional), or Parallel — contract: <path>. Task order lives in Blocked by.>

## Tracks
<Optional — only when the plan runs as tracks (a track = tasks that run in order
 in one worktree); none → delete this section. One line per track; every task
 names its track in `**Track:**`. Tasks that edit the same file share one track;
 Blocked by crosses tracks only at a track's first task. feature = this plan's
 file name without its date.>
- <A> — <short name>: Task <N>, Task <M> · branch <feature>/<a>-<short-slug>

## Ship groups
<Optional — only when tasks share a seam (a contract or interface): one line
 per group; none → delete this section. implement-plan runs one drift pass
 per group; finish-work's Reviewer gate looks for its report.>
- **Ship group:** <name> — Task <N>, Task <M> — seam: <the shared contract / interface>

## Done criteria
<The whole-plan finish line. Every task done AND this is true.>

## Failure policy
Default: a failing **Command** → debug-issue (reproduce → minimal fix →
re-run the same Command). Count failed fixes for the same unresolved repro or
criterion across owners and phases. After 2 failures, get one Second opinion;
attempts 3 and 4 require a fresh trace and use its advice. No usable advisor
means stop before another fix; after 4 failed fixes, stop and ask the user.
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
 implement-plan writes here instead of expanding scope; finish-work carries
 every line out with a destination (next spec / issue / dropped + why).>
