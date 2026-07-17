---
name: using-rolepod
description: Use at the start of every request to route work into Rolepod's workflow spine before planning, editing, delegating, verifying, reviewing, or shipping. Determines phase, required skills, skip rules, and evidence needed.
when_to_use: every user request unless the task is a clearly trivial answer that requires no repo state, no action, no recommendation, and no workflow decision
tier: 0
phase: router
---

# Using Rolepod — workflow router

Rolepod routes every task through one workflow spine:

```
Define → Plan → Build → Verify → Review → Ship
```

Lead reads this skill on the first turn of each request. Pick the phase, fire the required skill, then resume normal work inside that phase. Specialists (frontend / backend / billing / security / etc.) are chosen **after** the phase is clear, not before.

## Iron Rule

<EXTREMELY-IMPORTANT>
Before plan / edit / recommendation / answer → identify task type + required phase + required skill.

User explicit instruction wins. If user says "skip spec", "answer only", "just write the code" → obey, state which gate was skipped, proceed.

Default: route through the spine. Skipping is allowed only when (a) the task is trivial-answer-only, (b) user explicitly authorizes the skip, (c) the request is a question with no action attached, OR (d) the Skip rule below passes (diff ≤5 lines + 1 file + 0 logic-bearing lines + not high-risk).
</EXTREMELY-IMPORTANT>

## Router modes

This skill auto-fires on every request and runs in one of two modes.

**Auto-router mode (default)** — fires on normal requests. Picks the FIRST needed phase only; does not run every phase. May skip Define / Plan / Review / Ship when task size and risk justify it (see Skip rule). The user invokes nothing — routing is automatic. The Quick router table below is the single routing source.

**Force-full-lifecycle mode** — the user explicitly asks for the full workflow. Run Define → Plan → Build → Verify → Review → Ship with no phase skips unless the user later overrides.

## Force-full-lifecycle mode — `/rolepod-full`

Switch from auto-router to force-full mode when the user's message opens with any of these:

- `/rolepod-full <task>` — cross-CLI invocation of the `rolepod-full` skill
- `$rolepod-full <task>` — Codex skill-picker style
- Natural language: `force full lifecycle`, `run full rolepod lifecycle`
- `rolepod mode: full lifecycle` — this exact phrasing only

Bare `/rolepod`, bare `rolepod mode`, bare `run all phases`, and bare `no skip` are NOT force-full triggers — they fall through to auto-router. `/rolepod` is not needed for normal use; a normal prompt auto-routes.

The `rolepod-full` skill is the explicit entrypoint — it loads this skill in force-full mode; the execution backend table lives in `references/force-full-lifecycle.md`. If the user invoked `rolepod-full`, you are already in force-full mode; run it here.

### Force-full behavior

Force-full runs all six phases in order with no skips — even a one-line fix — with external adversarial reviewers when configured. The full phase-by-phase detail, the execution backend table, the start banner, careful-mode rigor, and the force-full rationalizations live in `references/force-full-lifecycle.md`. Load it when entering force-full mode.

## Boundary

Owns:
- Phase selection, skip decision, force-full detection, next skill.

Does not own:
- Detailed spec content, task planning, implementation, verification, review findings, or branch fate.
- Specialist / domain decisions before the phase is clear.

Hand off:
- Once the phase is chosen, the phase skill owns its own gates.

## Quick router

Match the user intent to the FIRST skill that fires. The skill itself decides what comes next. The **Model tier** column hints which agent tier is appropriate when the work delegates — the tier legend below is the operating rule; the full policy is `docs/model-tier-policy.md` in the rolepod source repo (not shipped with the plugin).

| User intent (verbs / phrases) | Phase | First skill fires | Model tier |
|---|---|---|---|
| "build / add / create / make / design" + vague target | **Define** | `write-spec` | cheap (PM/spec) |
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
| edit / implement / fix on **security / auth / billing / token / payment / migration** (a "plan / design" ask on these → Plan row below) | **Define (high-risk)** | `write-spec` → `write-plan` → `implement-plan` → `review-code` | **strong** |
| architecture decision (DB schema / API contract / module split) | **Plan** | `write-plan` → `system-architect` agent when available | **strong** |
| "is this done / fixed / does it work / verify" | **Verify** | `check-work` | balanced |
| "review / check this / look at the diff" | **Review** | `review-code` | **strong** (review) |
| "audit / sweep / map / find all X" on **the whole repo** | **Review (repo-wide)** | **scope-then-spawn** method (see below) → `review-code` | balanced |
| "ship / merge / push / PR / ready / go live" | **Ship** | Finish ritual below (`check-work` → `review-code` → `finish-work`) | **strong** (final review) |
| explain-only / conceptual question (no artifact) | (no phase) | answer directly — needs a wide repo / online sweep first → ONE cheap read-only scout returns a research report (always-on Code search rule) | cheap |
| unclear doc artifact / proposal / ADR scope | **Define** | `write-spec` | cheap |
| clear doc edit / add runbook section / update README | **Build** | `implement-plan` | cheap |
| "context too large / compact / resume / handoff / manage session" / stuck after repeated attempts | (cross-cut) | `manage-context` | cheap |

If no row matches: ask the user what phase the task is in. Don't pattern-match yourself into Build.

### Model tier hint reading

- **cheap** = haiku-class. Docs, PM, business analysis, customer-facing copy.
- **balanced** = sonnet-class (default). Normal implementation.
- **strong** = opus-class. Architecture, billing, security, migration code, and final-pass / adversarial code review (a review context, not a separate tier).

The Lead picks the tier at dispatch time from the row's hint (agent files carry no model pin — the hint column is the policy). Escalate a tier only when the task proves harder than routed (BLOCKED redispatch) or the user explicitly asks; never silently downgrade a **strong** row.

## Scope-then-spawn — repo-wide audit / sweep

For any task touching the whole repo (audit, refactor sweep, dead-code hunt, dependency map, "find every usage of X"): scope the file list first, narrow to the risky subset, then spawn agents only on that subset — never fan one agent per file across hundreds. The 3-step flow, tool order, and exceptions live in `references/scope-then-spawn.md`.

## State machine — phase → exit evidence → next

Router fires the **first** skill per phase. Phase exits only when its **exit evidence** is on the table (or user explicitly authorizes skip). Next phase reads from the **Next allowed** column — no jumping.

| Phase | Required first skill | Exit evidence | Next allowed |
|---|---|---|---|
| **Define** | `write-spec` | written spec OR approved one-line design (≤5-line task) OR explicit "skip spec" | Plan |
| **Plan** | `write-plan` (+ agent routing + cohesion contract if multi-agent) | ordered task list with done-condition + verify command per task; dependencies marked | Build |
| **Build** | `implement-plan` (+ `debug-issue` for bug intent) | changed files + tests added (or explicit no-test justification) + red→green evidence | Verify |
| **Verify** | `check-work` | fresh command output / screenshot / curl / log evidence; OR explicit "verify impossible because X" risk note | Review (high-risk / multi-file) OR Ship (low-risk) |
| **Review** | `review-code` | findings fixed OR rejected with line-anchored reason; no unresolved blocker | Ship |
| **Ship** | `finish-work` | S+T+F+P gates green (P = PR scope, one concern per PR); required CI lanes pass; user approval when policy requires; 4-option finish menu presented (merge / open PR / keep open / discard) | **end** |

**Router decides the first move only.** Each downstream skill owns its own gates; using-rolepod doesn't re-explain them.

## Skip rule

Skip a phase WHEN ANY of these holds (state explicitly in response):

- task is pure question / explanation / lookup (no file change)
- OR diff ≤5 lines + 1 file + 0 logic-bearing lines + not on high-risk path
- OR user explicit: "skip spec" / "just commit" / "answer only" / "no plan" / "ship as-is"

**Verify never fully skips** — `verify-first` is always-on. Trivial fixes drop the heavyweight verify (full suite, browser drive), not the lightweight one (re-read file, confirm edit landed).

## Stop conditions

- Coding before Define on ambiguous request → STOP, run `write-spec`.
- Claiming done before Verify → STOP, run `check-work`.
- 2nd parallel agent spawn without contract → STOP, run `write-plan` and write the cohesion contract first.
- Sub-agent attempting `git commit` / `git push` / `gh pr merge` → not allowed; Lead commits after the reviewer pass.
- High-risk path (auth/billing/migrations/crypto/payments) with 0 reviewer agents dispatched → STOP, dispatch qa-tester + security-engineer, plus an external CLI reviewer on a model different from the Lead's if one is installed (routing: review-code's `external-review-routing.md`).
- 3rd agent on same issue OR 3rd PR on same surface in one session → STOP, ask user (hard-stop rule).
- Diff mixes 2+ unrelated concerns at push/merge time → STOP, split into separate PRs (`finish-work` P1-P4 gate).
- Concurrent sessions: if SessionStart warns "concurrent session(s) detected in this worktree" → before editing a SHARED file, spawn an isolated worktree first (`git worktree add ../<repo>-task-<ts> <branch> && cd`) and continue there. rolepod guards against same-file stomp between concurrent sessions; disjoint and solo edits flow free. Override: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` for intentional shared/read-only review sessions.

## Finish ritual (Ship phase exit)

When the user says "done" / "finished" / "complete" / "ready" — or when the task obviously reached a natural stopping point — fire **in order**:

1. `check-work` — produce concrete evidence the change works (test output / screenshot / curl).
2. `review-code` — if multi-file or high-risk, pick adversarial reviewers per their domain match: an external CLI whose model differs from the Lead's, plus qa-tester.
3. `finish-work` — owns the 4-option finish menu (merge / open PR / keep open / discard); never auto-pick — the branch decision is the user's.

## Output pattern

```
Routing: <phase> → <skill>
Reason: <one sentence>
Skipping: <phases + why>, or "none"
Next step: <concrete action>
```

Use the full Routing / Reason / Skipping / Next-step block for non-trivial work, explicit `/rolepod-full`, and any case where the routing decision could surprise the user. For trivial answer-only tasks, skip the block — answer naturally and concisely.

Example — vague feature:
```
Routing: Define → write-spec
Reason: "build a React todo list" = vague target, no spec.
Skipping: none.
Next step: 4-question interview to pin acceptance criteria.
```

Example — typo fix:
```
Routing: Build → direct edit (gate-light)
Reason: typo, ≤5 lines, 1 file, 0 logic, not high-risk.
Skipping: Define + Plan + heavyweight Verify. Lightweight Verify runs.
Next step: edit + re-read + commit.
```

Example — done claim:
```
Routing: Ship → finish ritual
Reason: user said "is this done?"
Skipping: none — runs check-work → review-code → finish-work.
Next step: run tests, paste pass output, present 4-option menu.
```

## Optional plugin skills (backend awareness)

If the user has installed a sibling plugin under **Extension Protocol v1** (spec: `docs/EXTENSION-PROTOCOL.md` in the rolepod source repo), prefer its skills over manual orchestration. The parent writes `<git-root>/.rolepod/parent-active` at SessionStart so children switch to with-rolepod mode and route evidence into `.rolepod/evidence/` for `check-work` to aggregate. Currently recognised:

- **`rolepod-uiproof`** (v0.6+) — `/verify-ui`, `/audit-a11y`, `/visual-diff`, `/scaffold-e2e`, `/check-errors`. Used by `check-work` (verify + a11y + visual), `debug-issue` (browser repro / console errors), `review-code` (WCAG + visual regression).
- **`rolepod-wplab`** (v1.9+) — 14 WP skills + 82 MCP tools. Used by `check-work` (`/wp-health-check`), `debug-issue` (`/wp-diagnose`), `implement-plan` (`/wp-edit-*`, `/wp-scaffold`), `review-code` (`/wp-changes`).
- **`rolepod-dblab`** (v0.1+) — `/db-introspect`, `/db-query`, `/db-explain`, `/db-migrate-verify`, `/db-write`. Used by `check-work` (DB state as PASS/FAIL evidence), `debug-issue` (live data state as root cause), `review-code` / `finish-work` (`/db-migrate-verify` on migration / auth / billing paths). Seam with wplab: a WordPress DB → `wplab` (WP-semantic); any other database → `dblab` (raw engine).

When a child is not installed, the phase skill falls back to: (a) [Playwright MCP](https://github.com/microsoft/playwright-mcp), (b) [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) (sharper console / network / perf), or (c) manual instruction. Phase skills carry the explicit chain.

### Domain detection — when to suggest a child

| Signal | Suggest |
|---|---|
| `wp-config.php` at repo root | `rolepod-wplab` |
| `package.json` lists `playwright`, `cypress`, `react`, `vue`, `svelte`, `next`, `nuxt`, `astro` | `rolepod-uiproof` |
| `alembic.ini` at repo root, or `sqlalchemy` / `psycopg` / `psycopg2` / `asyncpg` in `requirements.txt` / `pyproject.toml` (non-WordPress DB) | `rolepod-dblab` |
| `.rolepod-uiproof/`, `.rolepod-wplab/`, or `.rolepod-dblab/` exists | the matching child already in use |

Detect availability by inspecting whether the slash command appears in the available skill list, or by treating tool-call absence as a fallback signal.

## Examples

Non-blocking — read when a request does not obviously match a Quick-router row:
- `examples/routing-transcripts.md` — eight worked routing transcripts (vague feature, clear edit, bug, done-claim, repo-wide audit, `/rolepod-full`, refactor, and a pattern-matched-into-Build correction). Each shows the user message, the routing decision, and the next step.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "Simple task, skip the spine" | Trivial-answer-only skips are explicit. Coding 5+ lines = run the spine. |
| "I already know what to build" | Even right answers without a spec drift mid-implementation. Write the 5-line spec; 30 seconds. |
| "User just wants a fix" | They want a *correct* fix. `debug-issue` finds the root; symptom patches recur. |
| "Tests are obvious, I'll add later" | Later never comes. TDD adds the test now or admits in writing it won't have one. |
| "Solo work, no contract needed" | The moment a second agent (or future-you in a fresh session) touches the surface, contract pays off. |
| "Reviewer takes too long" | Skip review = ship bugs. An external-CLI adversarial pass takes ~30s. |

## Don't

- Spawn specialist agents (frontend / backend / billing / etc.) before the phase is clear.
- Use `finish-work` as a placeholder ("I'll add it later"). It's the last skill, fires only at Ship.
- Replace `check-work` with the agent's confidence ("looks right to me").
- Skip Define just because the user typed in a hurry. Ask 1-2 questions.
- Treat this skill as documentation. It's a router — pick a row, fire the skill.

## Influence

Sharpens the workflow spine that already exists in the per-CLI doctrine doc (CLAUDE.md / AGENTS.md / GEMINI.md / Cursor always-on rule) so that small models route the same way large ones do. Pairs with `write-plan` for specialist selection and `finish-work` for the final gate.
