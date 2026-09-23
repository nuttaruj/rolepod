<!-- Deep playbook for dispatching implementer subagents from implement-plan. -->
<!-- Loaded on demand from SKILL.md §4 + §5 + §7. -->
<!-- Lead-as-controller pattern: controller curates context; subagent stays focused. -->

# Subagent dispatch

The Lead is a **controller**. A subagent gets only the context the controller curates — never the Lead's session history, never the plan file path. Pass full task text inline; that is the contract. Read the plan, extract each task's text inline into the session's task tracker (`TodoWrite` or the CLI's equivalent), and dispatch from there.

## Delegation economics

The Lead is usually the priciest model in the session, and every token that
enters its context is re-read on every later turn — a subagent's context dies
with the task. The route and the plan's **Owner:** line decide who builds —
R1/R2 stays with the Lead through its red→green loop; R3+ dispatches to the
named owner; a task with no Owner runs Q1-Q4 (SKILL.md §4). The Lead spends
its own tokens on decisions — briefs, manifests, diffs, verdicts — never on
wide mechanical loops (grep sweeps, bulk file reads, a long fail-retry
cycle); those run in a disposable context at a cheaper tier.

## Why fresh context per task

Fresh subagent per task — reusing one across tasks leaks Task N's mental model (symbols, half-finished trade-offs) into Task N+1's diff as naming drift and stray refactors.

**The dispatch prompt = the brief + what it lacks.** Point the owner at the brief and add only facts that neither the brief nor the owner's own skill holds: a worktree path that differs, absolute paths of private docs, a trap measured in this repo. Never restate the workflow (test-first, review rounds, commit policy, edit tools) — the skill carries it, and every restated rule pushes the task's goal further down the owner's context.

## Implementer status taxonomy

The implementer manifest declares `COMPLETED | PARTIAL | BLOCKED` (the enum every agent brief and `agent-protocol.md` teach) plus a **Concerns** section. Handle each with a specific protocol. A subagent that returns a QUESTION rather than a status is not `BLOCKED` — answer it inline and redispatch.

### `COMPLETED`, Concerns empty

Implementation complete, tests green, self-review clean, no doubts flagged.

**Action:** proceed to §6 review.

### `COMPLETED`, Concerns listed

Work complete, but the implementer flagged doubts in the manifest's Concerns section.

**Action:** read concerns first. Classify each:
- **Correctness concern** (e.g., "I'm not sure this handles the empty case") → resolve before review. Either confirm coverage exists or send back to implementer with the case named.
- **Scope concern** (e.g., "this change spilled into module Y") → resolve before review. Confirm scope or roll back the spillover.
- **Observation** (e.g., "this file is getting large") → note in plan follow-ups; proceed to review.

Never proceed to review with unresolved correctness or scope concerns.

### `PARTIAL`

Some of the task is done; the manifest states what remains.

**Action:** review the completed slice (§6 review on the diff so far), then redispatch the stated remainder as its own narrowed brief — fresh context, same model. Do not merge an unreviewed partial into the next task's diff.

### `BLOCKED`

The implementer cannot complete the task; the manifest states what blocks and what is needed.

**Action:** never re-dispatch unchanged. Read "what is needed" and change at least one variable:
1. **More context** — the brief was incomplete (a missing file path, API contract, constraint); expand the brief and redispatch the same model, fresh context. The subagent is not at fault; the controller's brief was.
2. **Stronger model** — task complexity exceeded the model tier; redispatch at the next tier
3. **Smaller scope** — task is genuinely two tasks; split in the plan and redispatch the smaller one
4. **Escalate** — the plan itself is wrong; return to `write-plan`

Re-dispatching unchanged = Hard stop.

## Fresh-context review per task

A delegated task gets one read-only pass in ONE message: `universal-reviewer` (spec + standards, or the concern-matched row) + `security-engineer` on a high-risk path (when a usable pool exists, the external replaces `universal-reviewer`) + `qa-tester` when the slice changes what a user sees. A seam-free single-file delegated task still gets this pass; a Lead-built R2 dispatches it, never a self-review.

### Ship-group drift pass

After all per-task passes clear, a ship-group drift pass runs only over a named group (the plan's **Ship group** line names which tasks run under one final review). When a group exists:
- Dispatch one reviewer on the cumulative diff across the group's tasks
- Role: `security-engineer` if the group holds an R4 task; else `universal-reviewer`
- Scope: cross-task symbol / type / method name drift, API contract mismatch between producer and consumer, unowned files touched by group members, architecture consistency across tasks
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
| **Ship-group drift pass** | Cross-task drift (symbol / type / contract), when plan names the group; role per group (R4 task → `security-engineer`, else `universal-reviewer`) | Most capable |

`BLOCKED` after a fast-model dispatch → re-dispatch the same task at one tier up before escalating to the human.

**Dispatch log.** On Claude Code the PostToolUse hook appends the row for strong-named roles; elsewhere — Workflow fleets, a strong dispatch to a non-strong-named role, hook-less CLIs — the Lead appends one line (inside the next outcome-bearing tool call, never a standalone turn) to `<git-root>/.rolepod/evidence/phase-log.jsonl` — `{"ts":"<iso8601>","phase":"dispatch","tier":"strong","override":"<model / effort sent, or none>"}` (fail-open). `make stats` then shows what share of strong dispatches carried an explicit override — `none` recorded from a non-strong Lead is the silent downgrade made visible. This is the audit layer for what no CLI exposes mechanically: which model a dispatch actually ran.

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

**Orchestration harnesses (workflow / ultracode).** A scripted fan-out defaults every agent to the Lead's own model — on a strong-tier Lead that silently runs the whole fleet at the top tier, and on a balanced-class Lead the INVERSE trap: inherit silently DOWNGRADES the verify/judge stages below what a high-risk diff requires. Apply the table above there too: pass the tier-mapped model (or the rolepod agentType, which carries its tier) per stage — mechanical sweep / scan = cheap, implementation = balanced, per-finding adversarial verify = balanced at high effort, the ONE judge / adjudicator = strong (on a non-strong Lead: an EXPLICIT `opts.model` / effort override — "high-risk review at the session's model" is the silent downgrade the tier policy forbids). Whole-fleet inherit needs a stated reason (e.g. every stage is judgment-heavy) — and never covers the verify/judge stages of an R4 diff. On Claude Code the reason lives IN the script as `// tier-reason: <why>`; without it, a strong-class Lead's fan-out is denied at dispatch (workflow-tier-nudge fleet-tier gate) when it is model-less, pins one balanced tier on every stage, or runs its judge stage below itself; and under ANY Lead, a high-risk fleet whose judge stage carries no strong / role-pin / dynamic tier is denied the same way (the tier follows the work, not the Lead) — and re-submitted with the tiers spread. **A command before a refuter.** Before spawning a per-finding verify agent, ask what a COMMAND can settle — a test, curl, a computed style, a grep — and run it in the same stage (or in the script itself: typed `schema` output plus a code check is the cheapest guardrail); spend an LLM refuter only on the claims no command can check.

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

Fires only when the plan's **Parallel layout** line declares Parallel with a contract path AND that cohesion contract exists. Track order comes from the plan's per-task **Blocked by** plus the contract's merge order — never from the prose. No contract → no parallel dispatch, period — drop to sequential and say why.

1. **Group tasks by track** (contract owner). A track's dependencies are the tasks in other tracks whose interfaces it consumes — the contract's merge order encodes this.
2. **Dispatch every ready track in ONE message** — one Agent call per track, same message, so they run concurrently. Each brief carries the track's tasks, its file-ownership slice (allowed paths = own slice; forbidden = everything else including the do-not-touch list), the frozen shared interfaces verbatim, tests, and done criteria. Copy the allowed/forbidden paths and the interfaces VERBATIM from the contract — a retyped path list is how a brief silently drifts from the ownership the contract pinned (`scripts/plan-lint.sh` proves plan↔contract; the verbatim rule covers contract↔brief).
3. **Pipeline, never barrier** — as each track returns its manifest, run its §6 review immediately; do not wait for slower tracks. The Lead hop applies per slice. Answer implementer questions inline as they arrive.
4. **Merge in contract order** — the integration owner (Lead) merges reviewed slices per the contract's merge order, running the interface provider's tests before merging its consumers. Subagents still never commit.
5. **Ship-group drift pass** when the plan names one (tracks sharing a frozen interface are one group).

Mid-flight conflicts:
- A track needs a file outside its slice → it returns `BLOCKED` with the path; Lead either amends the contract (every owner re-briefed) or drops to sequential. Never silently widen a slice.
- A frozen interface must change → stop every affected track, renegotiate the contract, redispatch. Cheaper than merging two halves built against different contracts.
- One track `BLOCKED` while others run → let the running tracks finish; apply the standard variable changes to the blocked one. Its dependents wait; independent tracks do not.

Cost note: parallel buys wall-clock, not tokens — N tracks cost the same tokens as N sequential tasks plus contract overhead. Dispatch parallel for speed, never to "use more agents".

## Session-split tracks — separate CLI sessions as track owners

The same contract that governs parallel subagents can be executed by SEPARATE CLI sessions, one per track — e.g. an API-heavy track on codex, a UI-heavy track on claude — when the user wants wall-clock parallelism across CLIs. The contract's optional **Session split** section carries the assignment and the per-session kickoff prompt. Differences from subagent tracks:

- **Each session runs its own Lead.** It executes its track's tasks, runs its own per-task reviews, and — unlike a subagent — COMMITS its own slice to a track branch (or worktree). The subagent commit ban binds subagents, not session Leads; the atomicity the ban protects is preserved by branch isolation + contract merge order instead.
- **Disk is the only shared truth.** Plan + contract are CLI-agnostic files; each session flips only its OWN tasks' checkboxes, so the checkbox union merges cleanly at integration. A session that edits another track's tasks, files, or checkboxes has broken the contract.
- **Isolation is mechanical only on some CLIs.** Same-worktree stomp is hook-denied on Claude, doctrine-held elsewhere — prefer a branch or worktree per track whenever slices share any filesystem state (generated files, build artifacts, lockfiles).
- **The integration session** (named in the contract) merges track branches in contract order, runs the interface provider's tests before its consumers, and runs the ship-group drift pass when the plan names one. Per-track self-review never substitutes for that pass — cross-task drift is exactly what no single track can see.
- **A frozen interface change stops every affected session.** Renegotiate in the contract file, re-kickoff the affected tracks. Silent divergence between sessions is the failure mode this whole protocol exists to prevent.

## Subagent commit policy

The subagent **never** commits. It returns a manifest; the Lead commits. Two reasons:
1. **Atomic accept/reject** — Lead reviewing the manifest can reject without `git reset`. Subagent commits create work that must be undone.
2. **Subagent context boundary** — committing requires knowing the working tree state across tasks. The subagent only sees its own slice. Commit decisions belong to the controller.

This is the opposite of some external subagent-driven patterns where the implementer commits its own work. Stay with Lead-commits — it is load-bearing for the bounded-delegation Iron Rule.

**Lead hop — one, not three.** With a reviewer report for the diff, the Lead reads the decision brief, spot-checks ONE finding in the report file (a clean report → one traced claim), and runs the task's Command once — the owner ran only the Check. Opens the source only for that spot-check, never for an axis walk or second review. Spot-check fails → send the findings back to the owner (exact strings where the Lead has them), do not commit; the Lead edits only a NEEDS path or a fact only it holds (the release number), in ONE message. No report (missing / failed / empty) → the Lead runs `review-code` §2 walk, recorded as a LIMITATION. A brief you cannot summarise in one sentence is a brief defect — send it back.

**One call per step.** `rolepod-ticket start <plan> <N>` → brief, worktree, dispatch line; `integrate <worktree> --brief <file>` → runs the Command + Proof, prints the commit command; `finish <worktree>` → merge + cleanup; `log` → the plan entry. The Lead reads product code during integration only when `integrate` fails — a read at a large context costs it all again.

**Close what finished.** After the merge, in the same turn: remove the task's worktree and branch, and close the owner's session (plus any reviewer the Lead dispatched) where the CLI keeps a finished agent resumable. An idle agent costs nothing, but it stays in the user's task list and a stray message wakes it against a worktree that is gone. Keep one alive only while a follow-up to it is planned.
