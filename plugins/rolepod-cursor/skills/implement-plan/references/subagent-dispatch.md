<!-- Deep playbook for dispatching task owners from implement-plan. -->
<!-- Loaded on demand from SKILL.md steps 2-3: picking the owner, reading its status, the ship recipe. -->
<!-- Lead-as-controller pattern: controller curates context; subagent stays focused. -->

# Subagent dispatch

The Lead is a **controller**. A subagent gets only the context the controller curates — never the Lead's session history, never the plan file path. Pass full task text inline; that is the contract. Read the plan, extract each task's text inline into the session's task tracker (`TodoWrite` or the CLI's equivalent), and dispatch from there.

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

A write mandate goes only to the role that owns the path. Prefer the CLI's native named role; when unavailable, use the portable role dispatch contract and the model tier per role in `using-rolepod/references/model-tiers.md`. Do not treat a prompt role name as native dispatch metadata or hook evidence. The plan-file exception under `docs/rolepod/plans/` is described in `write-plan` step 8.
- Never a test- or review-only role: `qa-tester` / `security-engineer` write tests and markdown only; `universal-reviewer` / `scout` write markdown only.

An `isolation: 'worktree'` agent holds tracked files only: a gitignored test harness is missing there, so the brief names how the Command gets in, or the writer runs on main with disjoint files.

## Implementer status taxonomy

The receipt declares `COMPLETED | PARTIAL | BLOCKED` (the enum every agent brief and `agent-protocol.md` teach) plus a **Concerns** section. A role's own Return carries its concerns as `Assuming:` lines, residuals and `NEEDS:` lines — read them as Concerns; `MISSING TARGET` / `SPEC CONFLICT` arrive under `BLOCKED`.

### `COMPLETED`, Concerns listed

Read the concerns first. Classify each:
- **Correctness concern** (e.g., "I'm not sure this handles the empty case") → resolve before review. Either confirm coverage exists or send back to the implementer with the case named.
- **Scope concern** (e.g., "this change spilled into module Y") → resolve before review. Confirm scope or roll back the spillover.
- **Observation** (e.g., "this file is getting large") → note in plan follow-ups; proceed to review.

### `PARTIAL`

Review the completed slice, then redispatch the stated remainder as its own narrowed brief — fresh context, same model. Do not merge an unreviewed partial into the next task's diff.

### `BLOCKED`

Never re-dispatch unchanged. Read "what is needed" and change at least one variable:
1. **More context** — the brief was incomplete (a missing file path, API contract, constraint); expand the brief and redispatch the same model, fresh context. The subagent is not at fault; the controller's brief was.
2. **Stronger model** — task complexity exceeded the model tier; redispatch at the next tier.
3. **Smaller scope** — the task is genuinely two tasks; split it in the plan and redispatch the smaller one.
4. **Escalate** — the plan itself is wrong; return to `write-plan`.

### A spec conflict across tasks

Two different tasks (or a `SPEC CONFLICT` report plus a reviewer rejection) tripping on the same spec section means the spec is the suspect, not the workers. Pause the affected tasks only, route the contradiction through `write-spec` (amend + user approval gate), re-brief the affected slice; unaffected tracks keep running.

## Ship recipe

**Lead hop — one, not three.** The Lead validates the task receipt, checks its named evidence pointers and proof lines, and spot-checks ONE claim — the Proof, or (R4) one finding in the reviewer report — then commits the task in the track worktree. Chat carries status and pointers, not copied findings. Opens source only for that spot-check, never for an axis walk or second review. Spot-check fails → send the exact discrepancy back to the owner; do not commit. An R4 report is missing, failed, or empty → when reviewer agents are available, ask the assigned reviewer to fill its named report in the same round; otherwise retain the no-agent fresh-owner `review-code` Axes fallback and record it as a LIMITATION. A brief that cannot be summarized in one sentence is defective; send it back.

**Two calls per task.** `scripts/ticket.sh start <plan> <N>` (this skill's folder) prints the brief, the track worktree (shared by all tasks in the track), the dispatch line and a `ship:` line. When the owner returns, the Lead fills the ship line (the commit check, subject, note) and runs it as ONE Bash call — integrate (Proof + commit check) → commit → log. `ticket.sh log --note` is one line (sha, verdict, pointer), at most 300 chars; the detail is in the task file. A red step stops the chain and nothing commits. The Lead reads product code only when a step fails. When all tasks in a track commit and the track-end review clears, the Lead runs `ticket.sh finish <worktree>` once to merge the full track; `finish` then prints `ready now:` with each fan-in task the merge unblocked. A single-track plan under another session's live lock gets its brief from `plan-lint.sh --brief <N> <plan> [contract] --plan-worktree` (`start` does this itself).

Tracks, size slices, ship-group drift passes and session split → the `run-tracks` skill; no `run-tracks` → run the tracks one after another on the base checkout (`implement-plan` step 5 fallback).
