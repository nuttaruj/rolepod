---
name: using-rolepod
description: Use at the start of every request to route work into Rolepod's workflow spine before planning, editing, delegating, verifying, reviewing, or shipping. Determines phase, required skills, skip rules, and evidence needed.
when_to_use: every user request unless the task is a clearly trivial answer that requires no repo state, no action, no recommendation, and no workflow decision
tier: 0
phase: router
---

# Using Rolepod — workflow router

One spine: `Define → Plan → Build → Verify → Review → Ship`. The Lead reads this skill on the first turn of each request; a literal follow-up on the same already-routed R0/R1 task with no tool call since resumes inside the current phase; any phase or tier change, or any tool call in between, routes again. Specialists are chosen **after** the phase is clear.

## Iron Rule

<EXTREMELY-IMPORTANT>
Before plan / edit / recommendation / answer → identify task type + required phase + required skill.

User explicit instruction wins. "skip spec", "answer only", "just write the code" → obey, state which gate was skipped, proceed.

Default: route through the spine. Skip only when (a) trivial-answer-only, (b) the user authorizes the skip, (c) a question with no action attached, or (d) the Rigor ladder assigns R1/R2 — reduced ceremony, never reduced verify.
</EXTREMELY-IMPORTANT>

## Commission vs conversation — detected HERE, never flagged by the user

- **Conversation** — idea questions in ANY language ("what do you think", "would X be better?", "wouldn't it be nice if…"), hypothetical framing, thinking-out-loud, comparisons, no imperative aimed at the repo → R0: discuss naturally — perspectives, trade-offs, honest pushback; NO spec, NO plan, NO artifact. The idea firms up → offer ONCE in one line ("want this as a spec?"), never auto-convert.
- **Commission** — an imperative aimed at the repo in any language (fix / add / build / change), named files or features, acceptance-shaped wording → tier normally (R1-R4).
- Ambiguous → treat as conversation and ask in ONE line whether to build. Pattern-matching musing into Define is the same disease as pattern-matching yourself into Build.

## Two modes

**Auto-router (default)** — fires on every request, picks the FIRST needed phase only, skips per the Rigor ladder; the Quick router table is the single routing source.

**Force-full** — triggers, message opens with: `/rolepod-full <task>` · `$rolepod-full <task>` (Codex) · `force full lifecycle` / `run full rolepod lifecycle` · `rolepod mode: full lifecycle` (exact). The `rolepod-full` skill is the explicit entrypoint. Bare `/rolepod`, `rolepod mode`, `run all phases`, `no skip` are NOT force-full triggers — they auto-route.

Force-full runs all six phases in order, even for a one-line fix, with external adversarial reviewers when configured, and skips nothing unless the user later overrides. Phase detail, backend table, start banner, careful-mode rigor: `references/force-full-lifecycle.md` — load on entering this mode.

## Boundary

Owns: phase selection, skip decision, force-full detection, the next skill. Nothing downstream — once the phase is chosen, the phase skill owns its own gates.

## Quick router

Match the intent to the FIRST skill that fires; that skill decides what comes next. Model tier = the class to dispatch when the work delegates (legend below).

| User intent | Phase | First skill fires | Model tier |
|---|---|---|---|
| "build / add / create / make / design" + vague target (commission only — musing → Conversation above) | **Define** | `write-spec` | cheap |
| "build X to spec" + a spec exists whose Success criteria cover the ask | **Plan** | `write-plan` | cheap–balanced |
| "add / change Y" on a feature with a spec whose Success criteria do not cover Y | **Define** | `write-spec` (repeat feature — new dated spec, delta against the prior; never edit the approved file) | cheap |
| "add / change Y" on a feature with NO spec (legacy code) | **Define** | `write-spec` — Current behavior = every consumer of the behavior that moves (grep call sites; code-intel callers when connected), each a plan task or a Non-goal; R2-sized → inline checklist | cheap |
| "execute plan / work the plan / implement plan.md" | **Plan→Build** | `write-plan` → `implement-plan` | balanced |
| "write test cases / test this feature / report a bug" — QA hand-off, no fix wanted | **Verify (QA)** | `qa-tester` agent (spec-first test-case design); a found bug → `debug-issue` report-only exit | cheap–balanced |
| "fix bug / failing test / broken / regression / why does X fail" | **Build (bug)** | `debug-issue` | balanced |
| "refactor / simplify / clean up" | **Build (refactor)** | `simplify-code` → `check-work` | balanced |
| "slow / optimize / latency / bundle size / N+1 / p95" | **Verify→Build (perf)** | `check-work` measures the baseline number first → `implement-plan`, Owner `performance-engineer`; no number, no change | balanced |
| "use agents / multi-agent / in parallel / parallel-safe" | **Plan** | `write-plan` (agent routing + cohesion contract) | balanced |
| vague UI / dashboard / product-design request | **Define** | `write-spec` | cheap |
| clear UI edit (existing design / screenshot / exact acceptance criteria) | **Build (UI)** | `implement-plan`, Owner `frontend-developer` (design-system / CSS / a11y-only → `ui-ux-designer`) → `check-work` | balanced |
| browser verification / "does the UI work?" | **Verify** | `check-work` | balanced |
| "audit UX / UI / a11y" of one page or flow | **Verify→Review** | `check-work` §3 observes → `review-code` UI axis (`ui-ux-designer` when available; `/audit-a11y` when uiproof installed) | balanced |
| edit / implement / fix on **auth / billing / payments / credits / migration / data deletion / secrets / tokens / crypto / permissions / security** (a "plan / design" ask → the architecture row) | **Define (high-risk)** | `write-spec` → `write-plan` → `implement-plan` → `review-code` | balanced build · **strong** review |
| architecture decision (DB schema / API contract / module split) | **Define** | `write-spec` — §3 dispatches ONE `system-architect` for the approach (when available) → `write-plan` | **strong** |
| "is this done / fixed / does it work / verify" | **Verify** | `check-work` | balanced |
| "review / check this / look at the diff" | **Review** | `review-code` | **strong** |
| "audit / sweep / map / find all X" on **the whole repo** | **Review (repo-wide)** | Sweeps (below) → `review-code` | balanced |
| "ship / merge / push / PR / ready / go live" — and any "done / finished / ready" or natural end of the work | **Ship** | `check-work` (evidence) → `review-code` (adversarial reviewers per domain when multi-file / high-risk) → `finish-work` (the finish menu; never auto-pick — the branch decision is the user's) | **strong** (final review) |
| explain-only / conceptual question | (no phase) | answer directly — a wide repo / online sweep first → ONE `scout` returns a research report (the always-on Code search rule) | cheap |
| unclear doc artifact / proposal / ADR scope | **Define** | `write-spec` | cheap |
| clear doc edit / runbook section / README | **Build** | `implement-plan`, Owner `content-strategist` (`audience:` set); R1-sized stays with the Lead | cheap |
| CI workflow / Dockerfile / compose / deploy config / `deploy/` `infra/` `terraform/` / release script | **Build (infra)** | `implement-plan`, Owner `devops-sre`; R1/R2-sized stays with the Lead | balanced |
| "context too large / compact / resume / handoff" / stuck after repeated attempts | (cross-cut) | `manage-context` | cheap |

No row matches → ask the user what phase the task is in. Don't pattern-match yourself into Build — nor musing into Define.

### Model tier

- **Legend.** **cheap** = haiku-class (docs, PM, copy) · **balanced** = sonnet-class — ALL implementation, high-risk paths included (the net is the strong review floor, never the dev's tier) · **strong** = opus-class — architecture, final-pass / adversarial review · **apex** = the strongest tier the CLI exposes, only on review-code's apex triggers. The ladder spans the user's opted-in model set, never a full aggregator catalog. The Lead picks the tier at dispatch; escalate only on BLOCKED redispatch or user ask.
- **Never silently downgrade a strong row.** A strong row dispatches with a strong pin (rolepod role files carry it). A spawn with no pin (plain-prompt subagent, bare Workflow `agent()`) under a balanced / cheap Lead inherits the Lead — inherited-from-balanced IS the silent downgrade — so pass an explicit strong-class override on that ONE call, never on a fan-out.
- **Fleets (Workflow / ultracode / native fan-out): one strong slot.** Sweep = cheap · build = balanced · per-item verify = balanced at high effort · the ONE judge or security reviewer = strong. Never inherit the Lead's model across a fleet; never pin strong on a fan-out (price × N); a downgraded strong role is not the strong slot. A stage that WRITES carries `agentType: 'rolepod:<role>'` — a bare `agent()` may not edit product files.
- **The coordinator lives outside the Lead:** ≥3 dependent dispatches = a Workflow pipeline, not a Lead loop of dispatch → wait → dispatch — every Lead round-trip re-reads the whole context at the Lead's price.
- A hooked CLI enforces the fleet shape at dispatch and names the fix (a single exception is a script comment `// tier-reason: <why>`). Codex / Gemini / Cursor / opencode have no fleet hook — doctrine carries it: a native subagent spawned from a plain prompt inherits the Lead, so the one judgment slot gets the strong id (a named role), never the whole fan-out. A CLI that resolves a default subagent model before the parent (Codex, proactive delegation included) → set that default to the balanced id and keep the strong slot a named role.
- **Effort never lifts the tier.** `/effort`, ultracode, xhigh raise reasoning, not ceremony: R1/R2 get at most ONE Workflow and it is the review (one `qa-tester` read of the diff); design / judge panels and adversarial fan-out are R3+ work; R2 verify stays the checklist command (+ a browser observation for UI), never the full suite.
- **Log every dispatch** — ad-hoc research fan-outs included: `{"ts":"<iso8601>","phase":"dispatch","tier":"<class>","override":"<model / effort sent, or none>"}` to the phase-log (Output pattern below). A hooked CLI writes it for role-pinned Agent calls; the Lead writes it where the hook cannot see the tier — Workflow fleets, a strong dispatch to a non-strong role, and every dispatch on a CLI without hooks. `make stats` audits the trail and names silent downgrades.

**Lead-tier fit nudge — once per session, tier classes only, never a model name.** Classify your OWN model into a class (cannot tell → skip). Strong-class Lead + three consecutive R1/R2 routes → note ONCE that a balanced Lead plus rolepod's escalation valves (cross-model consults, strong reviewers, BLOCKED redispatch) covers routine sessions. Balanced-class Lead + an R4 / architecture route → note ONCE that strong-tier consults and reviewers are pulled in automatically; a strong Lead is worth it only when that is the day's main work.

## Sweeps — never one agent per file

**Seen coming** (repo-wide audit, refactor sweep, "find all X"): scope the file list first, narrow to the risky subset, spawn agents only on that subset. **Emerges mid-flight** (a fix → check → fix loop) — **2-strike convergence**: the first 2 same-shaped fixes are discovery, self-do; the 3rd instance of the SAME shape is the convergence signal — stop, enumerate the remainder, and dispatch it as ONE mechanical-tier batch with the 2 fixed instances as the brief. Both flows, with tool order and the step detail: `references/scope-then-spawn.md`.

## State machine — phase → exit evidence → next

The router fires the **first** skill per phase; a phase exits only on its exit evidence (or an explicit user skip); the next phase reads from **Next allowed** — no jumping.

| Phase | Required first skill | Exit evidence | Next allowed |
|---|---|---|---|
| **Define** | `write-spec` | written spec OR approved one-line design (≤5-line task) OR R2 inline checklist OR explicit "skip spec" | Plan |
| **Plan** | `write-plan` (+ agent routing + cohesion contract if multi-agent) | ordered task list with done-condition + verify command per task; dependencies marked (R2, or the spec-as-plan R3 lane: the inline checklist IS the plan) | Build |
| **Build** | `implement-plan` (+ `debug-issue` for bug intent) | changed files + tests added (or explicit no-test justification) + red→green evidence | Verify |
| **Verify** | `check-work` | fresh command output / screenshot / curl / log evidence; OR explicit "verify impossible because X" risk note | Review (high-risk / multi-file) OR Ship (low-risk, plan exhausted) OR Build (unchecked tasks) |
| **Review** | `review-code` | findings fixed OR rejected with line-anchored reason; no unresolved blocker | Ship (plan exhausted) OR Build (unchecked tasks) |
| **Ship** | `finish-work` | the six pre-merge gates green (finish-work owns the list); required CI lanes pass; user approval when policy requires; the finish menu presented | **end** |

## Rigor ladder — R0-R4

Match ceremony to the task. Uncertain about RISK → the higher tier. Uncertain about SIZE only → read the affected regions of every file in the observed list first (the files the request names + files already read; `git status` once work has started — never an estimate) and take the tier that observed scope supports; an unresolved dependency is scope, not size → higher. A task that grows mid-flight (second source file, hidden logic, risk path) → re-tier UP immediately, never down.

| Tier | Signature | Path |
|---|---|---|
| **R0** | pure question / explanation / lookup / conversation — no file change | answer directly IN THE USER'S REGISTER; no spine, no routing block — verify claims of fact, reason freely on opinions |
| **R1** | diff ≤5 lines + 1 file + 0 logic-bearing lines (comment / blank / docs — or a line whose only change is user-facing text inside a string literal: label, message, i18n value; never a URL, path, key, regex, query, or a value code branches on) + not high-risk + ≤3 tool calls (a test loop or exploration ahead → R2+) | direct edit; the edit tool's echo of the changed lines IS the verify — no re-read turn, no review, no block (docs whose links changed → link check only) |
| **R2** | 1 source file + its own test file, clear scope, logic-bearing, ≈≤30 changed lines, not high-risk | **inline plan** — 3-5 line checklist + verify command + baseline (what already fails on the untouched tree) in chat, no artifact → build → verify → **`qa-tester` review** (balanced, the diff alone — the author never reviews own logic) → ship; one-line routing note |
| **R3** | multi-file OR vague scope OR needs sequencing / delegation | full spine, full routing block |
| **R4** | high-risk path (Stop conditions) | full spine + adversarial review floor — NEVER downgrades, whatever the diff size. One exception: 1 file, ≤5 lines, comment/blank-only (zero logic lines — a changed string literal still counts) → R2 with ONE strong reviewer; the cross-family anchor still applies while a pool is enabled |

User explicit ("skip spec" / "just commit" / "answer only" / "no plan" / "ship as-is") overrides the tier. An effort setting is NOT such an override. **Verify never fully skips**: R1/R2 drop the heavyweight verify (full suite, browser drive), not the lightweight one (R1: the edit echo; R2: the checklist's verify command).

## Stop conditions

- Coding before Define on an ambiguous request → `write-spec`.
- Claiming done before Verify → `check-work`.
- 2nd parallel agent spawn without a contract → `write-plan`, cohesion contract first.
- A subagent attempting `git commit` / `git push` / `gh pr merge` → not allowed; the Lead commits after the reviewer pass.
- High-risk path (the list in the router table; project override: `.rolepod/risk-paths`) with 0 reviewer agents dispatched → STOP. Dispatch (1) `qa-tester` + `security-engineer` — always, except the R4 comment/blank-only carve-out (ONE strong reviewer); (2) an external CLI reviewer — a different CLI than the Lead's, on its own default model — when one is installed (review-code's `external-review-routing.md`).
- 3rd agent on the same issue OR 3rd PR on the same surface in one session → STOP, ask the user.
- Diff mixes 2+ unrelated concerns at push / merge time → split into separate PRs (`finish-work` PR-scope gate).
- Concurrent sessions share the REF as well as the files. SessionStart warns "concurrent session(s) detected in this worktree" → before editing a SHARED file STOP: spawn an isolated worktree (`git worktree add .worktrees/<task> -b <branch>`) and work on your own branch there; disjoint and solo edits flow free. Override: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` for intentional shared / read-only sessions.
- Holding work for authorization → STOP: keep it on its own branch; never merge it into a SHARED branch before the answer comes. Merged there unpushed, it is staged for whoever pushes next (finish-work Iron Rule 1).

## Output pattern

```
Tier: R3 (multi-file) | R4 (high-risk)
Routing: <phase> → <skill>
Reason: <one sentence>
Skipping: <phases + why>, or "none"
Next step: <concrete action>
```

- **R0 / R1** — no block; answer or edit naturally.
- **R2** — one line: `Route: R2 (one file + test) → <skill> · <reason>`, then the inline checklist.
- **R3 / R4**, `/rolepod-full`, or any routing that could surprise the user — the full block.
- **Code + gloss, always** — the reader never opened this file: R0 answer only · R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk.

Every tier decision (R0 excepted) is STATED at line start in that routing line, and lands in the evidence log.

{{INCLUDE: core/fragments/phase-log.md}}
Route line: `{"ts":"<iso8601>","phase":"route","tier":"R1-R4","skill":"<first skill>"}` — a hooked CLI records it from the transcript, so no manual append there. A tier that is not stated cannot be audited.

## Optional plugin skills

Sibling plugins (`rolepod-uiproof` — browser + mobile UI / a11y / visual; `rolepod-wplab` — WordPress; `rolepod-dblab` — databases) are preferred over manual orchestration when installed; their evidence lands in `.rolepod/evidence/` for `check-work`.

Detect by their slash commands, or by domain signals: `wp-config.php` → wplab; `playwright` / `react` / `vue` in `package.json` or a mobile project (`*.xcworkspace`, `build.gradle`, `AndroidManifest.xml`, `pubspec.yaml`, `react-native`) → uiproof; `alembic.ini` / `sqlalchemy` → dblab; a `.rolepod-<child>/` dir → that child is already in use. The phase skills carry the integration and the not-installed fallbacks.

## Vendor MCP awareness — recommend, never wrap

A framework or service CENTRAL to the task ships an official MCP server not connected in this session → tell the user ONCE at a natural pause: name + one line of what it adds + where to get it. Verify live first (the vendor's current docs; no verify → no recommend); declined or ignored → drop it. The user installs vendor MCPs; rolepod never wraps them. Never a blocker — proceed on the CLI / Bash path regardless.

## References

Load only when a request does not obviously match a router row:
- `examples/routing-transcripts.md` — eight worked routing transcripts (vague feature, clear edit, bug, done-claim, repo-wide audit, `/rolepod-full`, refactor, a pattern-matched-into-Build correction).

## Common rationalizations

- "Simple task, skip the spine" → tier it (R0-R4); calling a task "simple" without tiering is how scope hides.
- "User just wants a fix" → they want a *correct* fix; `debug-issue` finds the root, symptom patches recur.
- "Tests are obvious, I'll add later" → later never comes; add the test now or admit in writing it won't have one.
- "Reviewer takes too long" → skip review = ship bugs; the external pass runs in the background while you continue.

## Don't

- Spawn specialists before the phase is clear · use `finish-work` as a placeholder (it fires only at Ship) · replace `check-work` with confidence ("looks right to me") · skip Define because the user typed in a hurry — ask 1-2 questions.
- Treat this skill as documentation. It's a router — pick a row, fire the skill.
