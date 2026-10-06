---
name: using-rolepod
description: Use when a user request arrives, before any planning, editing, delegating, verifying, reviewing or shipping; when a request reads or may change repo state, asks for an action or a recommendation, or opens a workflow decision.
---

# Using Rolepod — workflow router

Turns each request into a tier and the first skill of `Define → Plan → Build → Verify → Review → Ship` (R4 also reviews each task inside Build); that skill owns what follows.

Workflow mode = the active session mode carried from startup or the first `using-rolepod` entry; a helper call gets `ROLEPOD_SESSION_MODE` / `ROLEPOD_SESSION_SOURCE`. No `Active Rolepod workflow profile` line in your context → run `scripts/workflow-mode.sh` once and carry its mode; a sub-agent reads its brief's `Workflow mode:` line. Carry the mode and its source into every brief and compaction summary; never persist a loaded-skill stamp to disk. Per-CLI refresh boundaries and configured-mode inspection → `references/session-mode.md`; no file → this paragraph alone is enough.
Route each request on its intent, scope and tier. A tool call, config change or skill reload never reselects mode or reroutes; re-evaluate routing only when intent, scope or tier changes. A manual or mid-task entry inspects current intent and visible artifacts and resumes the owning phase when they still match; a compacted session resumes from verified disk state and the user's latest corrections — it never restarts Define or replaces an approved plan.
The user's explicit instruction wins ("skip spec", "answer only", "just write the code", "just commit", "no plan", "ship as-is"): obey, and say which step was skipped.

## Skip when

- A clearly trivial answer that needs no repo state, no action, no recommendation and no workflow decision → answer it.

### 1. Commission or conversation

- **Conversation** — an idea question in any language ("what do you think", "would X be better?"), a hypothetical, a comparison, no imperative aimed at the repo → R0: discuss trade-offs with honest pushback; no spec, no plan, no artifact. When the idea firms up, offer once: "want this as a spec?"
- **Commission** — an imperative aimed at the repo in any language (fix / add / build / change), named files or features, acceptance-shaped wording → step 2.
- **Ambiguous** → treat it as conversation and ask in one line whether to build.

Done when: a conversation is answered in the user's register, or a commission goes to step 2.

### 2. Tier it — the rigor ladder

| Tier | Signature | Path |
|---|---|---|
| **R0** answer only | question, lookup, conversation — no file change | answer; verify facts, reason freely on opinions |
| **R1** trivial edit | a docs-only diff, any size — or ≤5 lines in 1 file with zero logic lines (comment, blank, user-facing text in a string; never a URL, path, key, regex, query or a value code branches on), not high-risk, ≤3 tool calls | direct edit; the edit echo is the verify; no review |
| **R2** one file + test | 1 source file + its own test, clear scope, logic, ≈≤30 lines, not high-risk | its step 3 skill still fires (bug → `debug-issue`, else `orchestrating-plans`); a 3-5 line chat checklist (goal, done-when, verify command) replaces spec + plan; the test does not count toward the one-source-file limit; a task owner builds it on main (failing test first, verify, the commit check, the two review lenses); the Lead never pre-explores, then commits |
| **R3** multi-file | several source files, vague scope, or sequencing / delegation | an approved spec/change list already enumerates ≤3 ordered tasks and each task's files, verify command, and dependencies; single owner, no parallel work or high-risk path, and no mid-plan compaction → Build → `orchestrating-plans` with the inline checklist. Otherwise use the full spine |
| **R4** high-risk | a high-risk path — auth, tokens, billing, credits, secrets, data deletion, … (the full list: Stop conditions) — any size, one constant included | the full spine; review intensity comes from `workflow.mode` and follows `review-code` (Lite has two universal-reviewer lenses only; Standard and Full follow their own contracts); never downgrade risk; 1 file, ≤5 lines, comment / blank only → R2 |

- Unsure about risk or dependencies → the higher tier. Unsure about size → inspect affected regions and `git status` once work starts.
- The task grows (a second source file, hidden logic, a risk path) → re-tier up at once, never down: print the new Route line before the next edit or dispatch; a risk path (credits, auth, …) → R4 and its review floor.
- Tier is per task; the commission's highest tier sets the spine (Define → Plan) only.
- Verify never fully skips: R1/R2 drop the full suite and browser drive, never the echo or the checklist command.

Done when: one tier is chosen from observed scope.

### 3. Pick the first skill

The Lead routes, scopes, briefs (3-5 lines: goal, region / files, done-when — a changed rule also names the nearest inputs whose result stays the same — Command), spot-checks and commits; a skill whose steps read code regions, run commands or iterate is run by the owner of the path. Without sub-agents, the Lead runs it.
R2 and up, with sub-agents: after the Route line the Lead loads the named skill and dispatches the owner it names, never reads code regions, edits a source file or runs the fix loop itself, even when it looks small; the owner dispatches and re-checks its own reviewers, and the Lead reads its decision brief, never relays review rounds.

Red flags — the thought means stop:

| Thought | Instead |
|---|---|
| "Let me read the code first" | brief from the symptom or the plan; the owner reads |
| "It's small, faster to fix myself" | size is the tier's call: R1 only; else re-tier and dispatch |
| "It grew, but I'm nearly done" | new Route line first; a risk path → R4 and its floor |
| "I'll send the findings on to the owner" | the owner runs its own reviewers and re-checks |
| "A handoff / project doc says otherwise" | it wins only on project facts; workflow steps come from the skills |

The FIRST matching row fires:

| Intent | Route |
|---|---|
| another CLI's opinion or review (codex / agy / cursor / opencode / claude); set up or change cross-family | `cross-family` (no `cross-family` → a review ask → `review-code` internal strong pass; a setup ask → say cross-family is not installed) |
| fix bug / failing test / regression | Build → `debug-issue` first at every tier; it decides after root cause whether `write-spec` or `write-plan` follows |
| why does X fail / what causes this error, bug or metric / number change, no fix asked | Build → `debug-issue` report-only: answer from cause and evidence, read-only; save an artifact only when the user requested one |
| build / add / design with a vague target (UI, product, doc, ADR included) | Define → `write-spec` |
| build X to a spec whose Success criteria cover it | the R3 row's spec-as-plan eligibility met → Build → `orchestrating-plans` with the inline checklist; otherwise Plan → `write-plan` |
| add / change Y at R3+ where the spec does not cover Y, or no spec exists | Define → `write-spec` (a new dated delta spec); eligible R2 → `orchestrating-plans` with the step 2 checklist; other R3 → `write-plan` |
| execute an approved plan / use agents in parallel | Build → `orchestrating-plans` |
| architecture (DB schema, API contract, module split) | Define → `write-spec` (Approaches: ONE `system-architect`) |
| where to deepen / refactor for testability, whole repo | tell the user to type /deepen-codebase ($deepen-codebase on Codex) |
| prototype / layout options / does this state model feel right | spec settled → `write-prototype`; else `write-spec` first |
| do a clear change test-first / TDD / red-green | Build → `tdd-flow`, run by the path owner: R2+ → `orchestrating-plans`, Owner <path role>, who loads `tdd-flow`; R1 or no sub-agents → the Lead runs it (no `tdd-flow` → `implement-plan`, failing test first at the seam) |
| refactor / simplify / clean up | Build → `simplify-code`, run by the path owner (`orchestrating-plans`, Owner <path role>; R1 or no sub-agents → the Lead runs it) → `check-work` |
| slow / latency / bundle size / N+1 / p95 | Build → `orchestrating-plans`, Owner `performance-engineer` in ONE brief (baseline number, change, re-measure) → `check-work` reads its before / after numbers (no sub-agents → the Lead runs it) |
| clear UI edit (design, screenshot, exact acceptance) | Build → `orchestrating-plans`, Owner `frontend-developer` (iOS / Android / React Native / Flutter → `mobile-developer`; design system / CSS / a11y → `ui-ux-designer`) |
| write test cases / report a bug, no fix wanted | Verify → `qa-tester` agent (no agent → the Lead writes the case table); a found bug → `debug-issue` report-only, answer/read-only unless a saved artifact was requested |
| is this done / does it (or the UI) work / verify | Verify → `check-work` |
| audit UX / a11y of one page or flow | Verify → ONE `ui-ux-designer` brief: a browser observation + `review-code` `references/axes.md` (UI); no browser reachable → the Lead observes and the designer audits that observation (no sub-agents → the Lead runs both) |
| edit / fix on a high-risk path | Define → `write-spec` → `write-plan` → `orchestrating-plans` (per-task review) |
| clear doc edit; CI, Docker, deploy, infra config | Build → `orchestrating-plans`, Owner `content-strategist` (`audience:` set) / `devops-sre`; R1 → the Lead |
| review / look at the diff; audit / find all X across the repo | Review → `convening-code-review`; a whole-repo sweep scopes first (step 4) |
| ship / merge / PR / done, or the work's natural end | Ship → `finish-work` (`review-code` first if a review is missing) |
| rolepod stats / evidence report / which models ran | `rolepod-stats` |
| explain / conceptual question | answer; a wide repo or online sweep → a `scout` first, one per independent question, all in ONE message (no agent → the Lead greps) |
| context too large / compact / resume / stuck; write a handoff, or continue from the handoff | `manage-context` |

No row matches → `examples/routing-transcripts.md`; still none → ask the user which phase.

Done when: one row matched, or the user named the phase.

### 4. State the route

```
Tier: R3 (multi-file) | R4 (high-risk)
Routing: <phase> → <skill>
Reason: <one sentence>
Skipping: <phases + why>, or "none"
Next step: <concrete action>
```

- R0 / R1 — no line.
- R2 — `Route: R2 (one source file + its own test) → <skill> · Owner <path role> · <reason>`, then the checklist as the owner's brief.
- Eligible spec-as-plan R3 — `Route: R3 (spec-as-plan) → Build → orchestrating-plans`; give the inline checklist as the owner's brief. Apply step 2's complete eligibility conditions; any missing condition, including mid-plan compaction, routes to the plan artifact. R4 always does.
- Other R3 / R4 or a surprising route — the full block; `Next step:` names the owner (or `write-spec` / `write-plan`, which assign owners).
- Each tier carries its gloss: R0 answer only · R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk.
- Dispatching the owner, picking a model class or running a fleet → `references/model-tiers.md` (class per role, portable role dispatch, Fleets; mechanics `references/fanout-<cli>.md`); no file → the native role, else a fresh isolated child given the role's text; implementation balanced, one strong slot for the judge; no child facility → the Lead runs the loop.
- A repo-wide sweep, or the 3rd same-shaped fix in one loop → `references/scope-then-spawn.md` (scope first, then one batch); no file → count the instances, then ONE cheap-class batch with the fixed ones as examples.
- A sibling plugin is installed, or the central framework has an unconnected official MCP → `references/plugins-and-mcp.md`; no file → prefer the plugin; name the MCP to the user once.

Done when: the route is stated (R2 and up), the named skill is loaded, and the owner it names is dispatched (no sub-agents → the Lead runs the skill).

## Stop conditions

- Coding before Define on an ambiguous request → `write-spec`. Claiming done before Verify → `check-work`.
- A 2nd parallel writer without an ownership map → `write-plan` first. A Workflow script that gives each writer a disjoint slice is its own map; read-only fleets are exempt.
- High-risk paths — auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security (override: `.rolepod/risk-paths`). A high-risk path is code that handles one of these — reads, refreshes, stores, sends or logs it, a third-party credential included — not only code that changes its rules.
  A high-risk path with no reports from the active mode's R4 set at commit or ship → STOP (review-code Pick reviewers; Lite = the two lenses).
- A merge the user authorized while a required CI lane still runs → the Lead waits on it (`finish-work` CI lanes), never hands the wait to the user.
- Four failed fixes for one unresolved repro or criterion → stop and ask; one Second opinion after two (`debug-issue` Second opinion); review rounds count separately. The count carries across owners and phases. A 4th PR on one surface in a session → STOP, ask the user. Parallel verifiers, panels and discovery rounds inside one Workflow do not count.
- A diff mixing unrelated concerns at push → split the PRs (`finish-work` Pre-merge gate).
- Concurrent sessions share the REF as well as the files: a sibling / concurrent session warning at session start → before editing a SHARED file, work in `git worktree add .worktrees/<task> -b <branch>` (disjoint edits flow free); work held for authorization stays on its own branch, never merged into a SHARED branch before the answer; push rules → `finish-work` Finish menu ("Before any push").

## Next phase

- The skill the route names; it owns everything downstream.
- If that skill is not available, run its step as the Lead and say so in the Skipping line.
