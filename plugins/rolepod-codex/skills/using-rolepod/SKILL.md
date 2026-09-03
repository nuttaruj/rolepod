---
name: using-rolepod
description: Use at the start of every request to route work into Rolepod's workflow spine before planning, editing, delegating, verifying, reviewing, or shipping. Determines phase, required skills, skip rules, and evidence needed.
when_to_use: every user request unless the task is a clearly trivial answer that requires no repo state, no action, no recommendation, and no workflow decision
tier: 0
phase: router
---

# Using Rolepod — workflow router

Rolepod routes every task through one spine: `Define → Plan → Build → Verify → Review → Ship`. Lead reads this skill on the first turn of each request: pick the phase, fire the required skill, resume normal work inside it. Specialists are chosen **after** the phase is clear, not before.

## Iron Rule

<EXTREMELY-IMPORTANT>
Before plan / edit / recommendation / answer → identify task type + required phase + required skill.

User explicit instruction wins. If user says "skip spec", "answer only", "just write the code" → obey, state which gate was skipped, proceed.

Default: route through the spine. Skipping is allowed only when (a) the task is trivial-answer-only, (b) user explicitly authorizes the skip, (c) the request is a question with no action attached, OR (d) the Rigor ladder below assigns R1/R2 — reduced ceremony, never reduced verify.
</EXTREMELY-IMPORTANT>

## Router modes

Auto-fires on every request. **Auto-router (default)**: picks the FIRST needed phase only — never runs every phase; skips per the Rigor ladder; the user invokes nothing; the Quick router table is the single routing source. **Force-full-lifecycle**: the user explicitly asks for the full workflow — all six phases, no skips unless the user later overrides.

## Commission vs conversation — detected HERE, never flagged by the user

Nobody types "answer only" in real use — classifying the message is this skill's job (those phrases stay as overrides, not requirements):

- **Conversation** — idea questions in ANY language ("what do you think", "would X be better?", "wouldn't it be nice if…"), hypothetical framing, thinking-out-loud, comparisons, no imperative aimed at the repo → R0: discuss naturally — perspectives, trade-offs, honest pushback; NO spec, NO plan, NO artifact. The idea firms up mid-chat → offer ONCE in one line ("want this as a spec?"), never auto-convert.
- **Commission** — an imperative aimed at the repo in any language (fix / add / build / change and their equivalents), named files or features, acceptance-shaped wording → tier normally (R1-R4).
- Ambiguous → treat as conversation and ask in ONE line whether to build — a wrongly-formal answer costs more than one question. Pattern-matching musing into Define is the same disease as pattern-matching yourself into Build.

## Force-full-lifecycle mode — `/rolepod-full`

Triggers (message opens with): `/rolepod-full <task>` · `$rolepod-full <task>` (Codex) · `force full lifecycle` / `run full rolepod lifecycle` · `rolepod mode: full lifecycle` (exact). The `rolepod-full` skill is the explicit force-full entrypoint — it loads this skill in force-full mode.

Bare `/rolepod`, bare `rolepod mode`, bare `run all phases`, and bare `no skip` are NOT force-full triggers — they fall through to auto-router; a normal prompt auto-routes.

Force-full runs all six phases in order with no skips — even a one-line fix — with external adversarial reviewers when configured. Phase-by-phase detail, execution backend table, start banner, careful-mode rigor: `references/force-full-lifecycle.md` — load it when entering this mode.

## Boundary

Owns phase selection, skip decision, force-full detection, next skill — nothing downstream (spec content, planning, implementation, verification, review findings, branch fate). Once the phase is chosen, the phase skill owns its own gates.

## Quick router

Match the user intent to the FIRST skill that fires. The skill itself decides what comes next. The **Model tier** column hints which agent tier is appropriate when the work delegates — the tier legend below is the operating rule; the full policy is `docs/model-tier-policy.md` in the rolepod source repo (not shipped with the plugin).

| User intent (verbs / phrases) | Phase | First skill fires | Model tier |
|---|---|---|---|
| "build / add / create / make / design" + vague target (commission only — musing / hypothetical framing → Conversation mode above) | **Define** | `write-spec` | cheap (PM/spec) |
| "build X to spec" + spec exists | **Plan** | `write-plan` | cheap–balanced |
| "execute plan / work the plan / implement plan.md" | **Plan→Build** | `write-plan` → `implement-plan` | balanced |
| "write test cases / test this feature / report a bug" — QA hand-off, no fix wanted | **Verify (QA)** | `qa-tester` agent (spec-first test-case design); a found bug → `debug-issue` report-only exit | cheap–balanced |
| "fix bug / failing test / broken / regression / why does X fail" | **Build (bug)** | `debug-issue` | balanced |
| "refactor / simplify / clean up" | **Build (refactor)** | `simplify-code` → `check-work` | balanced |
| "use agents / multi-agent / in parallel / parallel-safe" | **Plan** | `write-plan` (agent routing + cohesion contract) | balanced |
| vague UI / dashboard / product-design request | **Define** | `write-spec` | cheap (PM/spec) |
| clear UI edit (existing design / screenshot / exact acceptance criteria) | **Build (UI)** | `implement-plan` → `check-work` | balanced |
| browser verification / "does the UI work?" | **Verify** | `check-work` | balanced |
| "audit UX / UI / a11y" of a page or flow (single surface) | **Verify→Review (UI audit)** | `check-work` §3 ladder observes → `review-code` UI axis (`ui-ux-designer` when available; `/audit-a11y` when uiproof installed) | balanced |
| edit / implement / fix on **auth / billing / payments / credits / migration / data deletion / secrets / tokens / crypto / permissions / security** (a "plan / design" ask on these → Plan row below) | **Define (high-risk)** | `write-spec` → `write-plan` → `implement-plan` → `review-code` | balanced build · **strong** review |
| architecture decision (DB schema / API contract / module split) | **Plan** | `write-plan` → `system-architect` agent when available | **strong** |
| "is this done / fixed / does it work / verify" | **Verify** | `check-work` | balanced |
| "review / check this / look at the diff" | **Review** | `review-code` | **strong** (review) |
| "audit / sweep / map / find all X" on **the whole repo** | **Review (repo-wide)** | **scope-then-spawn** method (see below) → `review-code` | balanced |
| "ship / merge / push / PR / ready / go live" | **Ship** | Finish ritual below (`check-work` → `review-code` → `finish-work`) | **strong** (final review) |
| explain-only / conceptual question (no artifact) | (no phase) | answer directly — needs a wide repo / online sweep first → ONE `scout` agent returns a research report (always-on Code search rule) | cheap |
| unclear doc artifact / proposal / ADR scope | **Define** | `write-spec` | cheap |
| clear doc edit / add runbook section / update README | **Build** | `implement-plan` | cheap |
| "context too large / compact / resume / handoff / manage session" / stuck after repeated attempts | (cross-cut) | `manage-context` | cheap |

If no row matches: ask the user what phase the task is in. Don't pattern-match yourself into Build — nor musing into Define.

### Model tier hint reading

- **Tier legend + apex.** **cheap** = haiku-class (docs, PM, copy) · **balanced** = sonnet-class — ALL implementation, high-risk paths included (the net = strong Lead at dispatch + strong adversarial review floor, never the dev's tier) · **strong** = opus-class — architecture, final-pass / adversarial review; within strong, **apex** = the strongest tier the CLI exposes (fable-class where available; "strongest available", never a fixed model), reserved for review-code's apex triggers (irreversible-no-rollback, novel design, cross-system invariants, review churn, user ask) — strong is the default rung, apex fires on trigger only, and the whole ladder spans the user's opted-in model set, never a full aggregator catalog (exposure ≠ authorization; a costlier rung is a cost decision to surface first). The Lead picks the tier at dispatch (agent files carry no model pin); escalate only on BLOCKED redispatch or user ask.
- **Never silently downgrade a strong row.** `inherit` equals strong ONLY when the Lead itself is strong-class; a balanced/cheap-class Lead dispatching a strong row passes an explicit **strong-class** override (Task `model` param / Workflow `opts.model` / effort) — inherited-from-balanced IS the silent downgrade. Claude Code floor: the dispatch hook lifts a model-less security-engineer / universal-reviewer Agent call to `opus` under a low Lead — Workflow `agentType` stages get no such lift; pin `model` there — on ONE call, never the fan-out.
- **Scripted orchestration, same policy** (workflow / ultracode): tier per stage — sweep = cheap, build = balanced, verify/judge = strong — never inherit the Lead's model across the whole fleet without a stated reason; prefer rolepod agentTypes so the tier rides along. **The coordinator lives outside the Lead**: ≥3 dependent dispatches = a Workflow pipeline (stages chain without the Lead), not a Lead loop of dispatch → wait → dispatch — every Lead round-trip re-reads the whole context at the Lead's price. On Claude Code the stated reason is a script comment `// tier-reason: <why>` — a strong-class Lead's fan-out is DENIED at dispatch (fleet-tier gate) when it sets no per-stage `model:`/`agentType:`, pins ONE balanced tier on ≥2 stages, or runs a judge/verify/rank stage with no strong tier — unless that comment states why. Under a balanced/cheap Lead the same gate denies a high-risk judge stage with no strong tier (`agentType` of a strong role renders inherit = the Lead; it does not count) AND denies a strong pin on a fan-out / ≥2 stages / a sweep — **one strong slot**: the security reviewer or one final adjudicator (reads the verdicts, not the repo) at strong, every fan-out (per-finding verify, per-file sweep) at balanced/cheap. Same shape on every CLI — Codex / Gemini / Cursor / opencode have no fleet hook, doctrine carries it: a native subagent spawned from a plain prompt inherits the Lead, so the one judgment slot gets the strong id (rolepod role files pin it; an un-pinned Codex spawn — Ultra's proactive delegation included — resolves `agents.default_subagent_model` then the parent, so set that default to the balanced id and keep the strong slot a named role), never the whole fan-out.
- **Log EVERY dispatch** — ad-hoc research fan-outs included, not just phase work: append `{"ts":"<iso8601>","phase":"dispatch","tier":"<class>","override":"<model / effort sent, or none>"}` to `<git-root>/.rolepod/evidence/phase-log.jsonl` (fail-open outside a git repo); on Claude Code a PostToolUse hook auto-appends a raw `provenance:"hook-auto"` line as the floor — the class-labeled line stays the Lead's job; `make stats` audits the trail and names silent downgrades.

**Lead-tier fit nudge — once per session, tier classes only, never a model name.** Classify your OWN model into a class (by family knowledge; cannot tell → skip the nudge). Strong-class Lead + three consecutive R1/R2 routes → note ONCE: routine session — a balanced-class Lead plus rolepod's escalation valves (cross-model consults, strong-tier reviewers, BLOCKED redispatch) covers this; switch via the CLI's model picker if saving matters. Balanced-class Lead + an R4 / architecture route → note ONCE that strong-tier consults and reviewers are pulled in automatically, and a strong-class Lead is worth it only when that is the day's main work.

## Scope-then-spawn — repo-wide audit / sweep

Whole-repo task (audit, sweep, "find every usage of X"): scope the file list first, narrow to the risky subset, spawn agents only on that subset — never one agent per file across hundreds. Flow + tool order: `references/scope-then-spawn.md`.

## 2-strike convergence — emergent fix loops

Scope-then-spawn covers sweeps known upfront. This covers the sweep that
*emerges* mid-flight: plan-less fix → check → fix work where each check reveals
the next fix. The first 2 same-shaped fixes are discovery — the Lead is
learning the pattern, self-do is correct and needs the Lead's judgment. The
3rd instance of the SAME shape (no new decision, just the learned fix applied
again) is the convergence signal — **stop, don't fix it inline**:

1. Enumerate the remainder (`rg` for the pattern / failing-test list).
2. Brief writes itself: the 2 fixed instances ARE the examples — pattern,
   before/after diff, verify command.
3. Dispatch the remainder as ONE batch to an implementer at the mechanical
   tier (subagent-dispatch role table); the Lead reviews the manifest, not
   each file.

Still emergent (fix #3 changed the approach, each fix reshapes the next) → not
converged; keep self-doing and re-test at the next repeat. Either way, a long
check loop (run suite, read verbose output) is delegable on its own — "run X,
report failures compactly" is always mechanical-tier work even when the fixes
are not.

Rationalization table: "faster to just fix it myself" — true for THIS file,
false for the sweep; by instance 3 the pattern is brief-ready and every
further inline fix pays top-tier price for zero new judgment.

## State machine — phase → exit evidence → next

Router fires the **first** skill per phase. Phase exits only when its **exit evidence** is on the table (or user explicitly authorizes skip). Next phase reads from the **Next allowed** column — no jumping.

| Phase | Required first skill | Exit evidence | Next allowed |
|---|---|---|---|
| **Define** | `write-spec` | written spec OR approved one-line design (≤5-line task) OR R2 inline checklist OR explicit "skip spec" | Plan |
| **Plan** | `write-plan` (+ agent routing + cohesion contract if multi-agent) | ordered task list with done-condition + verify command per task; dependencies marked (R2: the 3-5 line inline checklist in chat IS the plan) | Build |
| **Build** | `implement-plan` (+ `debug-issue` for bug intent) | changed files + tests added (or explicit no-test justification) + red→green evidence | Verify |
| **Verify** | `check-work` | fresh command output / screenshot / curl / log evidence; OR explicit "verify impossible because X" risk note | Review (high-risk / multi-file) OR Ship (low-risk, plan exhausted) OR Build (plan has unchecked tasks) |
| **Review** | `review-code` | findings fixed OR rejected with line-anchored reason; no unresolved blocker | Ship (plan exhausted) OR Build (plan has unchecked tasks) |
| **Ship** | `finish-work` | pre-merge gates green: S+T+F + Evidence + Reviewer + PR scope (one concern per PR); required CI lanes pass (no CI configured → their local equivalents, finish-work §2); user approval when policy requires; 4-option finish menu presented (merge / open PR / keep open / discard) | **end** |

**Router decides the first move only.** Each downstream skill owns its own gates; using-rolepod doesn't re-explain them.

## Rigor ladder — R0-R4

Match ceremony to the task; the ladder replaces a binary skip/full choice. Uncertain between two tiers → take the higher. A task that grows mid-flight (second file, hidden logic, risk path) → re-tier UP immediately, never down.

| Tier | Signature | Path |
|---|---|---|
| **R0** | pure question / explanation / lookup / conversation — no file change | answer directly IN THE USER'S REGISTER (conversational ask → conversational answer); no spine, no routing block — verify claims of fact, reason freely on opinions and ideas |
| **R1** | diff ≤5 lines + 1 file + 0 logic-bearing lines + not high-risk + expected ≤3 tool calls (a test loop or exploration ahead → R2+, even for 1 file) | direct edit + lightweight verify; no block |
| **R2** | 1 file, clear scope, logic-bearing, ≈≤30 changed lines, not high-risk | **inline plan** — 3-5 line checklist + verify command in chat, no spec/plan artifact → build → verify; one-line routing note |
| **R3** | multi-file OR vague scope OR needs sequencing / delegation | full spine, full routing block |
| **R4** | high-risk path (see Stop conditions) | full spine + adversarial review floor — NEVER downgrades, whatever the diff size |

User explicit ("skip spec" / "just commit" / "answer only" / "no plan" / "ship as-is") overrides the tier. **Verify never fully skips** — `verify-first` is always-on: R1/R2 drop the heavyweight verify (full suite, browser drive), not the lightweight one (re-read file, run the checklist's verify command).

## Stop conditions

- Coding before Define on ambiguous request → STOP, run `write-spec`.
- Claiming done before Verify → STOP, run `check-work`.
- 2nd parallel agent spawn without contract → STOP, run `write-plan` and write the cohesion contract first.
- Sub-agent attempting `git commit` / `git push` / `gh pr merge` → not allowed; Lead commits after the reviewer pass.
- High-risk path (auth / billing / payments / credits / migration / data deletion / secrets / tokens / crypto / permissions / security; project override: `.rolepod/risk-paths`) with 0 reviewer agents dispatched → STOP. Dispatch: (1) qa-tester + security-engineer — always; (2) an external CLI reviewer on a model family different from the Lead's — when one is installed (routing: review-code's `external-review-routing.md`).
- 3rd agent on same issue OR 3rd PR on same surface in one session → STOP, ask user (hard-stop rule).
- Diff mixes 2+ unrelated concerns at push/merge time → STOP, split into separate PRs (`finish-work` PR-scope gate).
- Concurrent sessions: if SessionStart warns "concurrent session(s) detected in this worktree" → before editing a SHARED file, spawn an isolated worktree first (`git worktree add ../<repo>-task-<ts> <branch> && cd`) and continue there. rolepod guards against same-file stomp between concurrent sessions; disjoint and solo edits flow free. Override: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` for intentional shared/read-only review sessions.

## Finish ritual (Ship phase exit)

User says "done / finished / ready" or the task reaches its natural end → fire in order: `check-work` (concrete evidence) → `review-code` (adversarial reviewers per domain when multi-file / high-risk) → `finish-work` (4-option menu; never auto-pick — the branch decision is the user's).

## Output pattern

```
Routing: <phase> → <skill>
Reason: <one sentence>
Skipping: <phases + why>, or "none"
Next step: <concrete action>
```

Routing output by tier — the block's size follows the rigor ladder:

- **R0 / R1** — no block; answer or edit naturally.
- **R2** — one line: `→ <skill> · R2 · <reason>`, then the inline checklist.
- **R3 / R4**, `/rolepod-full`, or any routing that could surprise the user — full block.

Every tier decision (R0 excepted) appends one line to `<git-root>/.rolepod/evidence/phase-log.jsonl` — `{"ts":"<iso8601>","phase":"route","tier":"R1-R4","skill":"<first skill>"}`, fail-open outside a git repo. A skip that is not logged is a skip that cannot be audited.

## Optional plugin skills (backend awareness)

Sibling plugins under **Extension Protocol v1** — `rolepod-uiproof` (browser + mobile UI / a11y / visual), `rolepod-wplab` (WordPress), `rolepod-dblab` (databases) — are preferred over manual orchestration when installed; evidence routes into `.rolepod/evidence/` for `check-work` to aggregate. Detect by their slash commands in the skill list, or by domain signals (`wp-config.php` → wplab; `playwright` / `react` / `vue` in `package.json` → uiproof; mobile UI — `*.xcworkspace` / `*.xcodeproj` / `build.gradle`(`.kts`) / `AndroidManifest.xml` / `pubspec.yaml` / `react-native` → uiproof too, web-only caveats in the spec; `alembic.ini` / `sqlalchemy` → dblab; a `.rolepod-<child>/` dir → already in use). The per-phase integration detail and the not-installed fallback chains live in the phase skills themselves (`check-work`, `debug-issue`, `implement-plan`, `review-code`); spec: `docs/EXTENSION-PROTOCOL.md` in the rolepod source repo.

## Vendor MCP awareness — recommend, never wrap

When a framework or service is CENTRAL to the current task (the thing being
tested, deployed, or driven — not a passing mention) and the vendor ships an
official MCP server that is not connected in this session, tell the user ONCE:
name + one line of what it adds + where to get it. Examples of the class:
Playwright MCP, Chrome DevTools MCP, Maestro MCP (mobile flows), Sentry,
Stripe, Postman. Rules:

- **Verify live before recommending** — WebSearch/WebFetch the vendor's current
  docs; MCP ecosystems move fast and a from-memory claim may name a server that
  was renamed, deprecated, or never existed. No verify → no recommend.
- **Once per session, at a natural pause** — never mid-task, never repeated.
  User declines or ignores → drop it permanently.
- **Recommend, never wrap** — vendor MCPs are installed and maintained by the
  user directly (same policy as rolepod-brain / GitNexus); rolepod never builds
  composite tools around them.
- Not a blocker: proceed with the CLI/Bash path regardless — the suggestion is
  an upgrade note, not a dependency.

## Examples

Non-blocking — read when a request does not obviously match a Quick-router row:
- `examples/routing-transcripts.md` — eight worked routing transcripts (vague feature, clear edit, bug, done-claim, repo-wide audit, `/rolepod-full`, refactor, and a pattern-matched-into-Build correction). Each shows the user message, the routing decision, and the next step.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "Simple task, skip the spine" | Tier it (R0-R4). R1 skips ceremony by rule, R2 still gets an inline plan + verify; calling a task "simple" without tiering is how scope hides. |
| "User just wants a fix" | They want a *correct* fix. `debug-issue` finds the root; symptom patches recur. |
| "Tests are obvious, I'll add later" | Later never comes. TDD adds the test now or admits in writing it won't have one. |
| "Reviewer takes too long" | Skip review = ship bugs. An external-CLI adversarial pass takes ~30s. |

## Don't

- Spawn specialists before the phase is clear · use `finish-work` as a placeholder (it fires only at Ship) · replace `check-work` with confidence ("looks right to me") · skip Define just because the user typed in a hurry — ask 1-2 questions.
- Treat this skill as documentation. It's a router — pick a row, fire the skill.
