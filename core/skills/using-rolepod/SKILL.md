---
name: using-rolepod
description: Use before the first action that creates, edits or deletes a file or runs a state-changing command — local or remote, git or not, follow-ups included.
---

# Using Rolepod — workflow router

Dispatched as a sub-agent with a brief → stop here; the brief and your role name your skills.

Turns a request that changes something into a tier and the first skill of `Define → Plan → Build → Review → Ship`; that skill owns what follows.

No `Active Rolepod workflow profile` line in your context → run `scripts/workflow-mode.sh` once and carry its mode (per CLI: `references/session-mode.md`).
No script and no profile line → Lite.
The user asks to set a mode → `references/session-mode.md`.
Route each request on its intent, scope and tier. A tool call, config change or skill reload never reselects mode or reroutes; re-evaluate routing only when intent, scope or tier changes. A manual or mid-task entry inspects current intent and visible artifacts and resumes the owning phase when they still match; a compacted session resumes from verified disk state and the user's latest corrections — it never restarts Define or replaces an approved plan.

### 1. Tier it — the rigor ladder

| Tier | Signature | Path |
|---|---|---|
| **R1** trivial edit | a docs-only diff, any size — or ≤5 lines in 1 file with zero logic lines (comment, blank, user-facing text in a string; never a URL, path, key, regex, query or a value code branches on), not high-risk, ≤3 tool calls | direct edit; the edit echo is the verify; no review |
| **R2** one file + test | 1 source file + its own test, clear scope, logic, ≈≤30 logic lines, not high-risk | its step 2 skill still fires (bug → `debug-issue`, else `orchestrating-plans`); a 3-5 line chat checklist (goal, done-when, verify command) replaces spec + plan; a task owner builds it on main, then the Lead commits |
| **R3** multi-file | several source files, vague scope, or sequencing / delegation | an approved spec/change list already enumerates ≤3 ordered tasks and each task's files, verify command, and dependencies; single owner, no parallel work, high-risk path, changed acceptance, added source file or mid-plan compaction → Build → `orchestrating-plans` with the inline checklist. Otherwise a clear R3 → step 2's chat design, else the full spine |
| **R4** high-risk | a high-risk path — auth, tokens, billing, credits, secrets, data deletion, … (the full list: Stop conditions) — any size, one constant included | the full spine; review intensity comes from `workflow.mode` and follows `convening-code-review` (Lite has two `rolepod-reviewer` lenses only); never downgrade risk; 1 file, ≤5 lines, comment / blank only → R2 |

- Unsure about risk or dependencies → the higher tier. Unsure about size → inspect affected regions and `git status` once work starts.
- The task grows (a second source file, hidden logic, a risk path) → re-tier up at once, never down: print the new Route line before the next edit or dispatch; a risk path (credits, auth, …) → R4 and its review floor.
- Tier is per task; the request's highest tier sets the spine only.
- R1 / R2 never skip proof: they drop the full suite and browser drive, never the echo or the checklist command.
- Blast radius sets the tier, not the feature's age; effort settings raise thinking, not the tier.

Done when: one tier is chosen from observed scope.

### 2. Pick the first skill

R2 and up, with sub-agents → after the Route line, load the named skill and dispatch the owner it names with a 3-5 line brief: goal, region / files, done-when (a changed rule also names the nearest inputs whose result stays the same), Command. The Lead never reads code regions, edits a source file or runs the fix loop itself, even when it looks small; it reads the owner's decision brief and never relays review rounds.

Red flags — the thought means stop:

| Thought | Instead |
|---|---|
| "Let me read the code first" | brief from the symptom or plan; the owner reads |
| "It's small, I'll fix it myself" | R1 only; else re-tier and dispatch |
| "A handoff / project doc says otherwise" | it wins on project facts only; the skills set the workflow |

The FIRST matching row fires:

| Intent | Route |
|---|---|
| fix bug / failing test / regression | Build → `debug-issue` first at every tier; it decides after root cause whether `write-spec` or `write-plan` follows |
| build / add / design with a vague target (UI, product, doc, ADR included) | Define → `write-spec` |
| build X to a spec whose Success criteria cover it | the R3 row's spec-as-plan eligibility met → Build → `orchestrating-plans` with the inline checklist; otherwise Plan → `write-plan` |
| add / change Y at R3+ where the spec does not cover Y, or no spec exists | eligible R2 → `orchestrating-plans` with the R2 checklist; clear R3 (inside an existing flow, nothing to ask) → a 3-5 line chat design (goal, approach, files, done-when, verify) + the user's yes → `write-plan`; unclear, R4 or doubt → Define → `write-spec` (a new dated delta spec) |
| execute an approved plan / use agents in parallel | Build → `orchestrating-plans` |
| architecture (DB schema, API contract, module split) | Define → `write-spec` (Approaches: ONE `rolepod-builder` with `domain: architecture`) |
| where to deepen / refactor for testability, whole repo | tell the user to type /deepen-codebase ($deepen-codebase on Codex) |
| clear UI edit (design, screenshot, exact acceptance) | Build → `orchestrating-plans`, Owner `rolepod-builder` |
| edit / fix on a high-risk path | Define → `write-spec` → `write-plan` → `orchestrating-plans` |
| rolepod stats / evidence report / which models ran | tell the user to type /rolepod-stats ($rolepod-stats on Codex) |
| context too large / compact / resume / stuck; write a handoff, or continue from the handoff | `manage-context` |

No row matches → `examples/routing-transcripts.md`; still none → ask the user which phase.

Done when: one row matched, or the user named the phase.

### 3. State the route

```
Tier: R3 (multi-file) | R4 (high-risk)
Routing: <phase> → <skill>
Reason: <one sentence>
Skipping: <phases + why>, or "none"
Next step: <concrete action>
```

- R1 — no line.
- R2 — `Route: R2 (one source file + its own test) → <skill> · Owner <path role> · <reason>`, then the checklist as the owner's brief.
- Eligible spec-as-plan R3 (every condition of the R3 row met) — `Route: R3 (spec-as-plan) → Build → orchestrating-plans`, the inline checklist as the owner's brief; any condition missing, and always R4 → the plan artifact.
- Other R3 / R4 or a surprising route — the full block; `Next step:` names the owner (or `write-spec` / `write-plan`, which assign owners).
- Each tier carries its gloss: R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk.
- Owner dispatch, model class or a fleet → `references/model-tiers.md` (mechanics `references/fanout-<cli>.md`); no file → the native role, else a fresh child given the role's text; no child facility → the Lead runs the loop.
- A repo-wide sweep or the 3rd same-shaped fix in a loop → `references/scope-then-spawn.md`; no file → count the instances, then ONE cheap-class batch with the fixed ones as examples.
- A sibling plugin or an unconnected official MCP → `references/plugins-and-mcp.md`; no file → prefer the plugin; name the MCP once.

Done when: the route is stated (R2 and up), the named skill is loaded and its owner dispatched.

## Stop conditions

- A 2nd parallel writer without an ownership map → `write-plan` first. A Workflow script that gives each writer a disjoint slice is its own map; read-only fleets are exempt.

{{INCLUDE: core/fragments/risk-paths.md}}

- A high-risk path with no reports from the active mode's R4 set at ship → STOP (`convening-code-review` Pick the set; Lite = the two lenses).
- A merge authorized while a required CI lane runs → wait as `finish-work` CI lanes says; never end a turn on "ping me" or hand the wait to the user.
- A diff mixing unrelated concerns at push → split the PRs (`finish-work` Pre-merge gate).
- Concurrent sessions share the REF as well as the files: a sibling / concurrent session warning at session start → before editing a SHARED file, work in `git check-ignore -q .worktrees/ || printf '\n.worktrees/\n' >> "$(git rev-parse --git-path info/exclude)"` then `git worktree add .worktrees/<task> -b <branch>` (disjoint edits flow free); work held for authorization stays on its own branch, never merged into a SHARED branch before the answer; push → `finish-work` ("Before any push").

## Next phase

- The skill the route names; it owns everything downstream.
- If that skill is not available, run its step as the Lead and say so in the Skipping line.
