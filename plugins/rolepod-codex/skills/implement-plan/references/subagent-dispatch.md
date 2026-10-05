<!-- Deep playbook for dispatching task owners from implement-plan. -->
<!-- Loaded on demand from SKILL.md steps 2-4. -->
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

A write mandate goes only to the role that owns the path. Prefer the CLI's native named role; when unavailable, use the portable role dispatch contract in `using-rolepod/references/model-tiers.md`. Do not treat a prompt role name as native dispatch metadata or hook evidence. The plan-file exception under `docs/rolepod/plans/` is described in `write-plan` step 8.
- Never a test- or review-only role: `qa-tester` / `security-engineer` write tests and markdown only; `universal-reviewer` / `scout` write markdown only.

Use the least powerful model that can handle the role (Model selection below).

## The brief

`plan-lint.sh --brief <N> <plan> [contract] [--main]` prints Goal / Tier / Blocked by / Read first / Files allowed + forbidden / Change / Command / Done when / Reviewers by tier (`none` for a docs-only diff or an R2/R3 task — its track-end review covers it, or the two lenses when it is its track's only code task; the R4 round-1 set for an R4 task) / Bounds. The Lead adds only **Read first** and facts the brief lacks; the owner starts there and never re-surveys what the Lead already mapped.

The owner writes its decision brief to its task file, docs/rolepod/tasks/<plan>/task-NN.md (its Handoff section: at most ~15 lines, only what a Blocked-by task consumes — signatures, invariants). Owners and reviewers never edit the plan file; the Lead's own points go under ## Lead notes of that task file.

## Implementer status taxonomy

The implementer manifest declares `COMPLETED | PARTIAL | BLOCKED` (the enum every agent brief and `agent-protocol.md` teach) plus a **Concerns** section. A role's own Return carries its concerns as `Assuming:` lines, residuals and `NEEDS:` lines — read them as Concerns; `MISSING TARGET` / `SPEC CONFLICT` arrive under `BLOCKED`. Handle each with a specific protocol. A subagent that returns a QUESTION rather than a status is not `BLOCKED` — answer it inline and redispatch. A `COMPLETED` whose Command tail shows a failing test is not `COMPLETED` — reject it and re-brief before anything below.

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
- R2/R3 task that is its track's only code task: its owner dispatches the two lenses in ONE message before returning and fixes each BLOCKER / MAJOR with proof and runs `review-code` Fix-verify; the track takes no track-end review.
- R2/R3 task in a track with two or more code tasks: the track-end review covers it once the track finishes. Each such track's R2/R3 tasks get no in-task review; one fresh owner (the role owning most code in that track) runs the two lenses in ONE message over the track diff after all tasks commit. When pool is on and the diff holds an R3 or R4 task, those lenses run external (`review-code` Pick reviewers); the Lead's brief carries the pool-on lens line. The owner fixes each BLOCKER / MAJOR with proof and runs `review-code` Fix-verify. Over ~800 changed lines or ~15 files it splits into size slices (`implement-plan` Review).
- An owner's own dispatches are all waited on: return your brief only after each child's report is in — a child's end wakes you (the Claude desktop app sends it to the Lead, which relays it; on Codex, `wait_agent` returns it), so end a turn only to wait for one, its last line `WAITING: <report paths>`; no `name`, fork or remote isolation (such a child reports to the Lead). No way to wait → `REVIEW NEEDED:` and the Lead dispatches a fresh owner to run the review.
- R4 task → use the active session mode carried in the plan/task brief from startup or first manual `using-rolepod` entry; never reread configured mode at Build. Configured-mode inspection is distinct and cannot replace the active profile. **Lite** (any tier, including R4): exactly two fresh isolated universal-reviewer lenses (`spec`, `standards`) in parallel on the same frozen diff/snapshot/hash; separate reports and no cross-report access; aggregate after both return; no security or adversarial reviewer. No agents → Lead does both lenses and records the limitation. Missing formal spec → user's supplied goal/acceptance is the spec input; still both lenses. **Standard**: `security-engineer` + two lenses. **Full**: those plus adversarial (external CLI with `--adversarial` when pool usable, else internal universal-reviewer `mode: adversarial` at strong; external fails → internal then). Full/Standard R4 protocol cannot override Lite. Pass the carried `ROLEPOD_SESSION_MODE`/`ROLEPOD_SESSION_SOURCE` when invoking `plan-lint.sh` or a helper without guaranteed native mode environment. User-visible flows verified once at `check-work`, never per task.
- A standalone R2 brief (no plan) → the owner dispatches the two `universal-reviewer` lenses itself, never a self-review.

Tracks, size slices, ship-group drift passes and session split → the `run-tracks` skill; no `run-tracks` → run the tracks one after another on the base checkout (`implement-plan` step 5 fallback).

## Model selection

Use the least powerful model that can handle the role. Cost compounds across N tasks × M reviews.

| Role | Signals | Model tier |
|---|---|---|
| **Explorer / scout** | Read-only wide sweep — repo or online sources; returns a research report (conclusion + file:line / URL pointers), never dumps; never edits. Dispatch the `scout` agent when available — it carries the report contract and tool restriction | Fast / cheap |
| **Implementer — mechanical** | 1-2 files, complete spec, isolated logic, no API contract change | Fast / cheap |
| **Implementer — integration** | Multi-file, pattern matching, debugging touch | Standard |
| **Implementer — architecture / judgment** | Broad codebase, design tradeoffs, new abstraction | Most capable |
| **Reviewer — fresh-context pass** | One read-only pass (spec + standards); role's pinned tier: `universal-reviewer` = balanced, `security-engineer` = strong (universal-reviewer = strong only in `mode: adversarial`) | Role's tier |
| **Ship-group drift pass** | Cross-task drift (symbol / type / contract), when plan names a group holding an R4 task; role `security-engineer` | Most capable |

`BLOCKED` after a fast-model dispatch → re-dispatch the same task at one tier up before escalating to the human.

**Orchestration harnesses** (a Workflow script, ultracode, Codex `ultra`): the tier per stage is `using-rolepod`'s `references/model-tiers.md` Fleets; the mechanics are its `references/fanout-<cli>.md`.

An `isolation: 'worktree'` agent holds tracked files only: a gitignored test harness is missing there, so the brief names how the Command gets in, or the writer runs on main with disjoint files.

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

Tracks, size slices, ship-group drift passes and session split → the `run-tracks` skill; no `run-tracks` → run the tracks one after another on the base checkout (`implement-plan` step 5 fallback).

## Subagent commit policy

The subagent **never** commits. It returns a manifest; the Lead commits. Two reasons:
1. **Atomic accept/reject** — Lead reviewing the manifest can reject without `git reset`. Subagent commits create work that must be undone.
2. **Subagent context boundary** — committing requires knowing the working tree state across tasks. The subagent only sees its own slice. Commit decisions belong to the controller.

This is the opposite of some external subagent-driven patterns where the implementer commits its own work. Stay with Lead-commits — it is load-bearing for bounded delegation.

**Lead hop — one, not three.** The Lead validates the task receipt, checks its named evidence pointers and proof lines, and spot-checks ONE claim — the Proof, or (R4) one finding in the reviewer report — then commits the task in the track worktree. Chat carries status and pointers, not copied findings. Opens source only for that spot-check, never for an axis walk or second review. Spot-check fails → send the exact discrepancy back to the owner; do not commit. An R4 report is missing, failed, or empty → when reviewer agents are available, ask the assigned reviewer to fill its named report in the same round; otherwise retain the no-agent fresh-owner `review-code` Axes fallback and record it as a LIMITATION. A brief that cannot be summarized in one sentence is defective; send it back.

**Two calls per task.** `scripts/ticket.sh start <plan> <N>` (this skill's folder) prints the brief, the track worktree (shared by all tasks in the track), the dispatch line and a `ship:` line. When the owner returns, the Lead fills the ship line (the commit check, subject, note) and runs it as ONE Bash call — integrate (Proof + commit check) → commit → log. `ticket.sh log --note` is one line (sha, verdict, pointer), at most 300 chars; the detail is in the task file. A red step stops the chain and nothing commits. The Lead reads product code only when a step fails. When all tasks in a track commit and the track-end review clears, the Lead runs `ticket.sh finish <worktree>` once to merge the full track; `finish` then prints `ready now:` with each fan-in task the merge unblocked. A single-track plan under another session's live lock gets its brief from `plan-lint.sh --brief <N> <plan> [contract] --plan-worktree` (`start` does this itself).

**Close what finished.** Before cleanup, ensure the canonical task receipt and every required named proof remain readable from base. If required proof is local-only and would disappear with the worktree, preserve it at its named private path before removal; proof already complete at base needs no export. Preserve a receipt left in the worktree to the brief's named base path first; a differing destination or failed copy stops cleanup and is reported as unresolved. Do not copy findings into a merged report or create another handoff. Then remove the task worktree and branch after merge, and close finished owner/reviewer sessions where resumable. Keep one alive only for a planned follow-up. Stop reported background work after integration.
