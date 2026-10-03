---
name: using-rolepod
description: Use at the start of every request to route work into Rolepod's workflow spine before planning, editing, delegating, verifying, reviewing, or shipping.
---

# Using Rolepod — workflow router

Turns each request into a tier and the first skill of `Define → Plan → Build → Verify → Review → Ship` (R4 also reviews each task inside Build); that skill owns what follows.

Route each user request on its intent, scope, and tier. Select workflow mode once at native session startup and carry the active mode/source through every phase, brief, and compaction summary.
When startup capture is unavailable, the first manual `using-rolepod` entry selects mode once; retain it in session context.
A tool call, config change, or skill reload does not reselect mode or reroute. Configured-mode inspection is separate and never overwrites the active session profile.
At a manual or mid-task invocation, inspect current intent and visible artifacts, then resume the owning phase when they still match. Re-evaluate routing only when intent, scope, or tier changes.
After compaction or skill reload within the same session, reload skill text as needed and reuse the carried mode. A fresh native startup/resume/clear supplies its newly captured profile.
When invoking a helper or `plan-lint.sh` later without a guaranteed native mode environment, pass `ROLEPOD_SESSION_MODE` and `ROLEPOD_SESSION_SOURCE` from the carried profile. Do not persist a loaded-skill stamp to disk.

Startup refresh boundaries: Claude captures on startup/resume/clear; Codex captures on startup/resume. Cursor captures through `sessionStart.env` and the visible startup profile; Antigravity captures at first pre-invocation/new conversation identity (same-conversation CLI restart behavior is unverified); OpenCode refreshes on plugin/backend restart, not each new chat.
The user's explicit instruction wins ("skip spec", "answer only", "just write the code", "just commit", "no plan", "ship as-is"): obey, and say which step was skipped.

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
| **R2** one file + test | 1 source file + its test, clear scope, logic, ≈≤30 lines, not high-risk | its step 3 skill still fires (bug → `debug-issue`, else `implement-plan`); a 3-5 line chat checklist (goal, done-when, verify command) replaces spec + plan; a task owner builds it on main (failing test first, verify, the commit check, the two review lenses); the Lead never pre-explores, then commits |
| **R3** multi-file | several files, vague scope, or sequencing / delegation | the full spine |
| **R4** high-risk | a high-risk path (Stop conditions), any size | the full spine; review intensity comes from `workflow.mode` and follows `review-code` (Lite has two universal-reviewer lenses only; Standard and Full follow their own contracts); never downgrade risk; 1 file, ≤5 lines, comment / blank only → R2 |

- Unsure about risk → the higher tier.
- Unsure about size only → read the affected regions of the named files (and `git status` once work started) and tier from that; an unresolved dependency → higher.
- The task grows (a second source file, hidden logic, a risk path) → re-tier up at once, never down: print the new Route line before the next edit or dispatch; a risk path (credits, auth, …) → R4 and its review floor.
- Tier is per task; the commission's highest tier sets the spine (Define → Plan) only.
- Verify never fully skips: R1/R2 drop the full suite and browser drive, never the echo or the checklist command.
- Effort settings (`/effort`, ultracode) raise reasoning, never the tier.

Done when: one tier is chosen from observed scope.

### 3. Pick the first skill

The Lead routes, scopes, briefs (3-5 lines: goal, region / files, done-when — a changed rule also names the nearest inputs whose result stays the same — Command), spot-checks and commits. A skill whose steps read code regions, run commands or iterate is run by the owner of the path, who calls the skill. Without sub-agents, the Lead runs it.
R2 and up, with sub-agents: after the Route line the Lead loads the named skill, then dispatches the owner the line names. The Lead never reads code regions, edits a source file or runs the fix loop itself; that work is the owner's even when it looks small. The owner's reviewers are the owner's to dispatch and re-check; the Lead reads the owner's decision brief, never relays review rounds.

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
| another CLI's opinion, review or draft (codex / agy / cursor / opencode / claude); set up or change cross-family | `cross-family` (no `cross-family` → a review ask → `review-code` internal strong pass; a setup ask → say cross-family is not installed) |
| fix bug / failing test / regression | Build → `debug-issue` first at every tier; after root cause, use `write-spec` only if desired behavior/design is unresolved before edits, and `write-plan` only if sequencing or ownership needs a plan |
| why does X fail / what causes this, no fix asked | Build → `debug-issue` report-only: answer from cause and evidence, read-only; save an artifact only when the user requested one |
| build / add / design with a vague target (UI, product, doc, ADR included) | Define → `write-spec` |
| build X to a spec whose Success criteria cover it | Plan → `write-plan` |
| add / change Y at R3+ where the spec does not cover Y, or no spec exists | Define → `write-spec` (a new dated delta spec); R2-sized → `implement-plan` with the step 2 checklist |
| execute an approved plan / use agents in parallel | Build → `implement-plan` |
| architecture (DB schema, API contract, module split) | Define → `write-spec` (Approaches: ONE `system-architect`) |
| where to deepen / refactor for testability, whole repo | tell the user to type /deepen-codebase ($deepen-codebase on Codex) |
| prototype / layout options / does this state model feel right | spec settled → `write-prototype`; else `write-spec` first |
| do a clear change test-first / TDD / red-green | Build → `tdd-flow`, run by the path owner: R2+ → `implement-plan`, Owner <path role>, who loads `tdd-flow`; R1 or no sub-agents → the Lead runs it (no `tdd-flow` → `implement-plan`, failing test first at the seam) |
| refactor / simplify / clean up | Build → `simplify-code`, run by the path owner (`implement-plan`, Owner <path role>; R1 or no sub-agents → the Lead runs it) → `check-work` |
| slow / latency / bundle size / N+1 / p95 | Build → `implement-plan`, Owner `performance-engineer` in ONE brief (baseline number, change, re-measure) → `check-work` reads its before / after numbers (no sub-agents → the Lead runs it) |
| clear UI edit (design, screenshot, exact acceptance) | Build → `implement-plan`, Owner `frontend-developer` (iOS / Android / React Native / Flutter → `mobile-developer`; design system / CSS / a11y → `ui-ux-designer`) |
| write test cases / report a bug, no fix wanted | Verify → `qa-tester` agent (no agent → the Lead writes the case table); a found bug → `debug-issue` report-only, answer/read-only unless a saved artifact was requested |
| is this done / does it (or the UI) work / verify | Verify → `check-work` |
| audit UX / a11y of one page or flow | Verify → ONE `ui-ux-designer` brief: `check-work` UI verification + `review-code` Axes (UI); no browser reachable → the Lead observes and the designer audits that observation (no sub-agents → the Lead runs both) |
| edit / fix on a high-risk path | Define → `write-spec` → `write-plan` → `implement-plan` (per-task review) |
| clear doc edit; CI, Docker, deploy, infra config | Build → `implement-plan`, Owner `content-strategist` (`audience:` set) / `devops-sre`; R1 → the Lead |
| review / look at the diff; audit / find all X across the repo | Review → `review-code`; a whole-repo sweep scopes first (References) |
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
- R2 — `Route: R2 (one file + test) → <skill> · Owner <path role> · <reason>`, then the checklist as the owner's brief.
- R3 / R4 or a surprising route — the full block; `Next step:` names the owner (or `write-spec` / `write-plan`, which assign owners).
- Each tier carries its gloss: R0 answer only · R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk.

Done when: the route is stated (R2 and up), the named skill is loaded, and the owner it names is dispatched (no sub-agents → the Lead runs the skill).

## Stop conditions

- Coding before Define on an ambiguous request → `write-spec`. Claiming done before Verify → `check-work`.
- A 2nd parallel writer without an ownership map → `write-plan` first. A Workflow script that gives each writer a disjoint slice is its own map; read-only fleets are exempt.
- High-risk paths — auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security (override: `.rolepod/risk-paths`) — with zero required reviewer reports at commit or ship → STOP.
  Reviewer reports follow `workflow.mode`: Lite requires both isolated universal-reviewer lens reports; Standard requires `security-engineer`; Full also requires the adversarial pass (see `review-code`).
  A high-risk path is code that handles one of these — reads, refreshes, stores, sends or logs it, a third-party credential included — not only code that changes its rules.
- A merge the user authorized while a required CI lane still runs → the Lead waits on it (`finish-work` CI lanes), never hands the wait to the user.
- A 3rd sequential attempt to fix the same failure, or a 3rd PR on one surface in a session → STOP, ask the user. Parallel verifiers, panels and discovery rounds inside one Workflow do not count.
- A diff mixing unrelated concerns at push → split the PRs (`finish-work` Pre-merge gates).
- Concurrent sessions share the REF as well as the files. A sibling / concurrent session warning at session start → before editing a SHARED file, work in `git worktree add .worktrees/<task> -b <branch>`; disjoint edits flow free.
- Holding work for authorization → keep it on its own branch; never merge it into a SHARED branch before the answer comes — unpushed there, it ships with whoever pushes next.

## References

- Delegating, picking a model class, or running a fleet → `references/model-tiers.md` (mechanics: `references/fanout-<cli>.md`).
- A repo-wide sweep, or the 3rd same-shaped fix in one loop → `references/scope-then-spawn.md`.
- A sibling plugin is installed, or the task's central framework has an unconnected official MCP → `references/plugins-and-mcp.md`.

## Next phase

- The skill the route names; it owns everything downstream.
- If that skill is not available, run its step as the Lead and say so in the Skipping line.
