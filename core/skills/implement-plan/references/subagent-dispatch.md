<!-- Deep playbook for dispatching task owners from implement-plan. -->
<!-- Loaded on demand from SKILL.md Delegate, Parallel tracks and Review. -->
<!-- Lead-as-controller pattern: controller curates context; subagent stays focused. -->

# Subagent dispatch

The Lead is a **controller**. A subagent gets only the context the controller curates — never the Lead's session history, never the plan file path. Pass full task text inline; that is the contract. Read the plan, extract each task's text inline into the session's task tracker (`TodoWrite` or the CLI's equivalent), and dispatch from there.

## Delegation economics

The Lead is usually the priciest model in the session, and every token that
enters its context is re-read on every later turn — a subagent's context dies
with the task. The route and the plan's **Owner:** line decide who builds —
R1 stays with the Lead; R2 goes to the owner on main from a 3-5 line brief; R3+ dispatches to the
named owner; a task with no Owner runs the Q1-Q4 delegation test (SKILL.md Delegate). The Lead spends
its own tokens on decisions — briefs, manifests, diffs, verdicts — never on
wide mechanical loops (grep sweeps, bulk file reads, a long fail-retry
cycle); those run in a disposable context at a cheaper tier.

## Why fresh context per task

Fresh subagent per task — reusing one across tasks leaks Task N's mental model (symbols, half-finished trade-offs) into Task N+1's diff as naming drift and stray refactors.

**The dispatch prompt = the brief + what it lacks.** Point the owner at the brief and add only facts that neither the brief nor the owner's own skill holds: a worktree path that differs, absolute paths of private docs, a trap measured in this repo. Never restate the workflow (test-first, review rounds, commit policy, edit tools) — the skill carries it, and every restated rule pushes the task's goal further down the owner's context.

## Picking the owner

Closest specialist by path / concern / strategy:
- `frontend-developer` / `ui-ux-designer` — UI, interaction
- `backend-developer` — API, business logic, DB models
- `mobile-developer` — iOS, Android, RN, Flutter
- `billing-engineer` — billing, credits, subscription
- `ai-ml-engineer` — LLM, RAG, SDK, prompt cache
- `data-scientist` — analytics, pipelines, dashboards
- `devops-sre` — infra, CI/CD, containers, deploy, release
- `performance-engineer` — latency, profiling, load test, bundle size, query speed
- `content-strategist` — written output; pass `audience: dev|user|prospect`

A write mandate goes only to the role that owns the path:
- Never a generic platform agent (`general-purpose` / `default` / `claude`, or a bare Workflow `agent()`; a writing stage carries `agentType: 'rolepod:<role>'`).
- Never a test- or review-only role: `qa-tester` / `security-engineer` write tests and markdown only; `universal-reviewer` / `scout` write markdown only.

Use the least powerful model that can handle the role (Model selection below).

## The brief

`plan-lint.sh --brief <N> <plan> [contract]` prints Goal / Tier / Blocked by / Read first / Files allowed + forbidden / Change / Command / Done when / Write / Reviewers by tier (`none` for a docs-only diff) / Bounds. The Lead adds only **Read first** and facts the brief lacks; the owner starts there and never re-surveys what the Lead already mapped.

## External write

`Owner: <role> · write: external` (pool opt-in, per task):
1. The owner, in its own worktree, writes the failing test at the seam first.
2. Pool on → `cross-family` kind implement drafts the change that must turn that test green, scoped to the task's Files allowed; then the owner runs its own loop (Command, reviewers, fixes).
3. Pool off or `cross-family` absent → the owner writes the task itself.

The member never reviews its own draft, and the Lead never runs the SKILL.md Review for that task.

## Implementer status taxonomy

The implementer manifest declares `COMPLETED | PARTIAL | BLOCKED` (the enum every agent brief and `agent-protocol.md` teach) plus a **Concerns** section. Handle each with a specific protocol. A subagent that returns a QUESTION rather than a status is not `BLOCKED` — answer it inline and redispatch. A `COMPLETED` whose Command tail shows a failing test is not `COMPLETED` — reject it and re-brief before anything below.

### `COMPLETED`, Concerns empty

Implementation complete, tests green, self-review clean, no doubts flagged.

**Action:** proceed to Review.

### `COMPLETED`, Concerns listed

Work complete, but the implementer flagged doubts in the manifest's Concerns section.

**Action:** read concerns first. Classify each:
- **Correctness concern** (e.g., "I'm not sure this handles the empty case") → resolve before review. Either confirm coverage exists or send back to implementer with the case named.
- **Scope concern** (e.g., "this change spilled into module Y") → resolve before review. Confirm scope or roll back the spillover.
- **Observation** (e.g., "this file is getting large") → note in plan follow-ups; proceed to review.

Never proceed to review with unresolved correctness or scope concerns.

### `PARTIAL`

Some of the task is done; the manifest states what remains.

**Action:** review the completed slice (Review on the diff so far), then redispatch the stated remainder as its own narrowed brief — fresh context, same model. Do not merge an unreviewed partial into the next task's diff.

### `BLOCKED`

The implementer cannot complete the task; the manifest states what blocks and what is needed.

**Action:** never re-dispatch unchanged. Read "what is needed" and change at least one variable:
1. **More context** — the brief was incomplete (a missing file path, API contract, constraint); expand the brief and redispatch the same model, fresh context. The subagent is not at fault; the controller's brief was.
2. **Stronger model** — task complexity exceeded the model tier; redispatch at the next tier
3. **Smaller scope** — task is genuinely two tasks; split in the plan and redispatch the smaller one
4. **Escalate** — the plan itself is wrong; return to `write-plan`

## Review per task

Who reviews follows the task's tier (SKILL.md Review):
- R2/R3 task in a plan → no reviewer in the loop; the Lead's ONE combined review over the plan diff covers it: two `universal-reviewer` lenses in ONE message (`lens: spec` · `lens: standards`, or the concern-matched row), the external instead at the pool's tier.
- R4 task → the owner dispatches one read-only pass in ONE message: `security-engineer` + ONE strong pass (the external with a usable pool, else `universal-reviewer`). User-visible flows are verified once at `check-work`, never per task.
- A standalone R2 brief (no plan) → the owner dispatches the two `universal-reviewer` lenses itself, never a self-review.

### Ship-group drift pass

A ship-group drift pass runs only over a named group (the plan's **Ship group** line names which tasks run under one final review). A group of R2/R3 tasks only → the combined review over the plan diff is that pass. A group holding any R4 task → a separate drift pass after its R4 per-task passes clear:
- Dispatch one reviewer on the cumulative diff across the group's tasks
- Role: `security-engineer`
- Scope: cross-task symbol / type / method name drift, API contract mismatch between producer and consumer, unowned files touched by group members, architecture consistency across tasks
- A normal review of the cross-task seams at the role's own lens (security included), not an adversarial round
- Never a re-review of a task's own diff (that reviewer already passed it)

Tracks sharing a frozen interface are one group. No group named → no drift pass. Hand off to `check-work` only after the group clears.

## Model selection

Use the least powerful model that can handle the role. Cost compounds across N tasks × M reviews.

| Role | Signals | Model tier |
|---|---|---|
| **Explorer / scout** | Read-only wide sweep — repo or online sources; returns a research report (conclusion + file:line / URL pointers), never dumps; never edits. Dispatch the `scout` agent when available — it carries the report contract and tool restriction | Fast / cheap |
| **Implementer — mechanical** | 1-2 files, complete spec, isolated logic, no API contract change | Fast / cheap |
| **Implementer — integration** | Multi-file, pattern matching, debugging touch | Standard |
| **Implementer — architecture / judgment** | Broad codebase, design tradeoffs, new abstraction | Most capable |
| **Reviewer — fresh-context pass** | One read-only pass (spec + standards); role's pinned tier: `universal-reviewer` / `security-engineer` = strong | Role's tier |
| **Ship-group drift pass** | Cross-task drift (symbol / type / contract), when plan names a group holding an R4 task; role `security-engineer` | Most capable |

`BLOCKED` after a fast-model dispatch → re-dispatch the same task at one tier up before escalating to the human.

**Retry-at-higher-effort (checkable stages).** When a stage's outcome is
mechanically checkable (tests, verifier, schema), dispatch it at LOW effort
and re-run only the failures one effort step up — before any other recovery.
Anthropic's own measurement (SWE-bench Pro): low-then-retry-at-default held
the pass rate of all-default at about half the cost. Two conditions: a real
failure signal (a checker that passes bad work forwards the failure instead
of catching it), and it never applies to the verify/judge stages of a
high-risk diff — those keep the tier floor below. The tier ladder above
(re-dispatch one TIER up on `BLOCKED`) is for capability gaps; this effort
ladder is for depth gaps — try the cheaper rung first.

**Orchestration harnesses (workflow / ultracode).** A scripted fan-out defaults every agent to the Lead's own model. On a strong-tier Lead that silently runs the whole fleet at the top tier; on a balanced-class Lead the INVERSE trap: inherit silently DOWNGRADES the verify/judge stages below what a high-risk diff requires.

Apply the table above there too — pass the tier-mapped model (or the rolepod agentType, which carries its tier) per stage:
- mechanical sweep / scan = cheap;
- implementation = balanced;
- per-finding adversarial verify = balanced at high effort;
- the ONE judge / adjudicator = strong. On a non-strong Lead that is an EXPLICIT `opts.model` / effort override — "high-risk review at the session's model" is the silent downgrade the tier policy forbids.

Pin every fan-out `agent()` call — a `model:` class or a rolepod `agentType:`; a bare fan-out runs the whole fleet at the Lead's price, and no script comment excuses it. A stage that writes carries `agentType: 'rolepod:<role>'` — a bare `agent()` cannot edit product files. A high-risk fleet's judge stage carries a strong tier under any Lead: the tier follows the work, not the Lead.

**A command before a refuter.** Before spawning a per-finding verify agent, ask what a COMMAND can settle — a test, curl, a computed style, a grep — and run it in the same stage (or in the script itself: typed `schema` output plus a code check is the cheapest guardrail). Spend an LLM refuter only on the claims no command can check.

## Continuous execution rule

On a multi-task plan, do not pause to check in with the user between tasks. The user asked for the plan to be executed; executing it is the answer. "Should I continue?" prompts and progress summaries are noise — the user can read the manifest stream.

Stop **only** when:
1. `BLOCKED` and Lead cannot resolve via the four variable changes above
2. Spec / plan gap that wasn't visible until implementation revealed it —
   and aggregate the signal: two different tasks (or a `SPEC CONFLICT`
   report plus a reviewer rejection) tripping on the same spec section
   means the spec is the suspect, not the workers. Pause the affected
   tasks only, route the contradiction through `write-spec` (amend + user
   approval gate), re-brief the affected slice; unaffected tracks keep
   running.
3. Scope ambiguity that genuinely prevents progress (not a stylistic preference)
4. All tasks complete

Anything else = continue.

## Parallel-track dispatch

The plan's layout is the dispatch signal. Every unblocked task goes out in ONE message, each task owner in its OWN worktree named for the task (the brief prints the command). The Lead keeps working while task owners build, integrates each as it returns (SKILL.md Review) and merges in the contract's order. Two tracks reach for the same file → stop: run them sequentially, or rewrite the contract. A parallel-layout plan run one track at a time needs a stated reason.

Fires only when the plan's **Parallel layout** line declares Parallel with a contract path AND that cohesion contract exists. Track order comes from the plan's per-task **Blocked by** plus the contract's merge order — never from the prose. No contract → no parallel dispatch, period — drop to sequential and say why.

1. **Group tasks by track** (contract owner). A track's dependencies are the tasks in other tracks whose interfaces it consumes — the contract's merge order encodes this.
2. **Dispatch every ready track in ONE message** — one Agent call per track, same message, so they run concurrently. Each brief carries the track's tasks, its file-ownership slice (allowed paths = own slice; forbidden = everything else including the do-not-touch list), the frozen shared interfaces verbatim, tests, and done criteria. Copy the allowed/forbidden paths and the interfaces VERBATIM from the contract — a retyped path list is how a brief silently drifts from the ownership the contract pinned (`scripts/plan-lint.sh` proves plan↔contract; the verbatim rule covers contract↔brief).
3. **Pipeline, never barrier** — as each track returns its manifest, integrate it (SKILL.md Review) immediately; do not wait for slower tracks. The Lead hop applies per slice. Answer implementer questions inline as they arrive.
4. **Merge in contract order** — the integration owner (Lead) merges reviewed slices per the contract's merge order, running the interface provider's tests before merging its consumers. Subagents still never commit.
5. **Ship-group drift pass** when the plan names one (tracks sharing a frozen interface are one group).

Mid-flight conflicts:
- A track needs a file outside its slice → it returns `BLOCKED` with the path; Lead either amends the contract (every owner re-briefed) or drops to sequential. Never silently widen a slice.
- A frozen interface must change → stop every affected track, renegotiate the contract, redispatch. Cheaper than merging two halves built against different contracts.
- One track `BLOCKED` while others run → let the running tracks finish; apply the standard variable changes to the blocked one. Its dependents wait; independent tracks do not.

Cost note: parallel buys wall-clock, not tokens — N tracks cost the same tokens as N sequential tasks plus contract overhead. Dispatch parallel for speed, never to "use more agents".

## Session-split tracks — separate CLI sessions as track owners

The same contract that governs parallel subagents can be executed by SEPARATE CLI sessions, one per track — e.g. an API-heavy track on codex, a UI-heavy track on claude — when the user wants wall-clock parallelism across CLIs. The contract's optional **Session split** section carries the assignment and the per-session kickoff prompt. Differences from subagent tracks:

- **Each session runs its own Lead.** It executes its track's tasks, runs its own reviews (R2/R3: one combined review over its track; R4: per task), and — unlike a subagent — COMMITS its own slice to a track branch (or worktree). The subagent commit ban binds subagents, not session Leads; the atomicity the ban protects is preserved by branch isolation + contract merge order instead.
- **Disk is the only shared truth.** Plan + contract are CLI-agnostic files; each session flips only its OWN tasks' checkboxes, so the checkbox union merges cleanly at integration. A session that edits another track's tasks, files, or checkboxes has broken the contract.
- **One branch or worktree per track.** Prefer it whenever slices share any filesystem state (generated files, build artifacts, lockfiles); two sessions in one worktree stomp each other.
- **The integration session** (named in the contract) merges track branches in contract order, runs the interface provider's tests before its consumers, and runs the ship-group drift pass when the plan names one. Per-track self-review never substitutes for that pass — cross-task drift is exactly what no single track can see.
- **A frozen interface change stops every affected session.** Renegotiate in the contract file, re-kickoff the affected tracks. Silent divergence between sessions is the failure mode this whole protocol exists to prevent.

## Subagent commit policy

The subagent **never** commits. It returns a manifest; the Lead commits. Two reasons:
1. **Atomic accept/reject** — Lead reviewing the manifest can reject without `git reset`. Subagent commits create work that must be undone.
2. **Subagent context boundary** — committing requires knowing the working tree state across tasks. The subagent only sees its own slice. Commit decisions belong to the controller.

This is the opposite of some external subagent-driven patterns where the implementer commits its own work. Stay with Lead-commits — it is load-bearing for bounded delegation.

**Lead hop — one, not three.** The Lead reads the decision brief, spot-checks ONE claim — the Proof, or (R4) one finding in the reviewer's report file — then runs the ship line. Opens the source only for that spot-check, never for an axis walk or second review. Spot-check fails → send the findings back to the owner (exact strings where the Lead has them), do not commit; the Lead edits only a NEEDS path or a fact only it holds (the release number), in ONE message. No report on an R4 task (missing / failed / empty) → the Lead runs the `review-code` Axes walk, recorded as a LIMITATION. A brief you cannot summarise in one sentence is a brief defect — send it back.

**Two calls per task.** `rolepod-ticket start <plan> <N>` prints the brief, the worktree, the dispatch line and a `ship:` line. When the owner returns, the Lead fills the ship line (the commit check, subject, note) and runs it as ONE Bash call — integrate (Proof + commit check) → commit → finish → log. A red step stops the chain and nothing commits. The Lead reads product code only when a step fails.

**Close what finished.** After the merge, in the same turn: remove the task's worktree and branch, and close the owner's session (plus any reviewer the Lead dispatched) where the CLI keeps a finished agent resumable. An idle agent costs nothing, but it stays in the user's task list and a stray message wakes it against a worktree that is gone. Keep one alive only while a follow-up to it is planned.
