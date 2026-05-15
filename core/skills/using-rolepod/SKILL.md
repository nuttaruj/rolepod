---
name: using-rolepod
description: Use at the start of every request to route work into Rolepod's workflow spine before planning, editing, delegating, verifying, reviewing, or shipping. Determines phase, required skills, skip rules, and evidence needed.
when_to_use: every user request unless the task is a clearly trivial answer that requires no repo state, no action, no recommendation, and no workflow decision
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

Default: route through the spine. Skipping is allowed only when (a) the task is trivial-answer-only, (b) user explicitly authorizes the skip, OR (c) the request is a question with no action attached.
</EXTREMELY-IMPORTANT>

## Quick router

Match the user intent to the FIRST skill that fires. The skill itself decides what comes next. The **Model tier** column hints which agent tier is appropriate when the work delegates — see `core/fragments/model-tier-policy.md` for the full policy.

| User intent (verbs / phrases) | Phase | First skill fires | Model tier |
|---|---|---|---|
| "build / add / create / make / design" + vague target | **Define** | `spec-driven-development` | cheap (PM/spec) |
| "build X to spec" + spec exists | **Plan** | `planning-and-task-breakdown` | cheap–balanced |
| "execute plan / work the plan / implement plan.md" | **Plan→Build** | `planning-and-task-breakdown` → `subagent-task-execution` | balanced |
| "fix bug / failing test / broken / regression / why does X fail" | **Build (bug)** | `systematic-debugging` → `test-driven-development` | balanced |
| "refactor / simplify / clean up" | **Build (refactor)** | `code-simplification` → `post-change-verify` | balanced |
| "use agents / multi-agent / in parallel / parallel-safe" | **Plan** | `team-routing` → `parallel-contract-orchestration` | balanced |
| UI / browser / frontend / dashboard work | **Build (UI)** | `frontend-ui-engineering` → `webapp-testing` | balanced |
| **security / auth / billing / token / payment / migration** | **Build (high-risk)** | `security-and-hardening` → `test-driven-development` → `code-review-and-quality` | **strong** |
| architecture decision (DB schema / API contract / module split) | **Plan** | `api-and-interface-design` → `system-architect` agent | **strong** |
| "is this done / fixed / does it work / verify" | **Verify** | `post-change-verify` | balanced |
| "review / check this / look at the diff" | **Review** | `code-review-and-quality` (route via `reviewer-flow` for high-risk) | **adversarial** |
| "ship / merge / push / PR / ready / go live" | **Ship** | `pre-merge-gate` | **adversarial** (final review) |
| "document / explain the choice / write ADR / runbook" | (cross-cut) | `documentation-and-adrs` | cheap |

If no row matches: ask the user what phase the task is in. Don't pattern-match yourself into Build.

### Model tier hint reading

- **cheap** = haiku-class. Docs, PM, business analysis, customer-facing copy.
- **balanced** = sonnet-class (default). Normal implementation.
- **strong** = opus-class. Architecture, billing, security, migration code.
- **adversarial** = opus-class reviewer. Final-pass code review; security review of high-risk paths.

Agent frontmatter sets the model. Lead doesn't override unless user explicitly asks.

## Phase rules

### Define — spec before code

Trigger: new feature, vague request, behavior change without exact implementation, UI/app/tool ask, product idea.

Required skill: `spec-driven-development`.

Exit evidence: written spec OR concise approved design in chat OR explicit user instruction to skip spec.

**Hard rule:** do NOT write implementation code before Define exits, unless user explicitly says skip.

### Plan — break + order

Trigger: spec exists, task spans multiple files, execution order unclear, or multi-agent work possible.

Required skill: `planning-and-task-breakdown`. If multi-agent or shared invariants → also `team-routing` + `parallel-contract-orchestration`.

Exit evidence: ordered task list, done condition per task, verify command per task, dependencies marked.

### Build — TDD by default

Trigger: approved spec / plan, explicit small code task, bug fix after root cause confirmed.

Required skill: `test-driven-development`. If delegated → `subagent-task-execution`.

Exit evidence: changed files + tests added (or explicitly justified absent) + red/green proof.

### Verify — evidence, not vibes

Trigger: about to claim "done" / "fixed" / "works" / "passes"; after every edit; before commit/PR.

Required skill: `post-change-verify`.

Exit evidence: fresh command output, screenshot/browser proof for UI, curl/log for services, OR explicit risk statement when verification impossible.

### Review — adversarial

Trigger: after Build/Verify, before Ship, on high-risk surface, on multi-file work.

Required skill: `code-review-and-quality`. For high-risk → `reviewer-flow` + `security-and-hardening`.

Exit evidence: findings fixed or explicitly rejected with reason, line-anchored risks, no unresolved blocker.

### Ship — pre-merge gate

Trigger: "ship" / "merge" / "push" / "PR" / "ready" / "go live".

Required skill: `pre-merge-gate`.

Exit evidence: S gate passed (simplicity) + T gate passed (tests) + F gate passed (failure-mode) + required CI lanes green + user approval when policy requires.

## Skip rules

Skip the spine WHEN ALL true:

- task is a pure question / explanation / lookup (no file change)
- OR ≤5 lines + single file + zero logic-bearing (comments / whitespace / typechecked rename) + not on high-risk path
- OR user explicit: "skip spec", "just commit", "answer only", "no plan", "ship as-is"

Stating the skip is mandatory. Example: "Skipping Define+Plan: typo fix, ≤5 lines, no high-risk path."

## Stop conditions

- Coding before spec/plan when request is ambiguous → STOP, run Define.
- Claiming done before verification → STOP, run Verify.
- Parallelizing shared work before contract → STOP, run `parallel-contract-orchestration`.
- Shipping before pre-merge gate → STOP, run `pre-merge-gate`.
- High-risk surface (auth / billing / migrations / crypto / payments / external integration) without reviewer → STOP, dispatch qa-tester + (Codex / Gemini / security-engineer when available).

## Output pattern

When the router decides:

```
Routing: <phase> → <skill>
Reason: <one sentence why this phase fits user intent>
Skipping: <list of phases skipped + why>, or "none"
Next step: <concrete action>
```

Example for vague feature:

```
Routing: Define → spec-driven-development
Reason: "build a React todo list" = vague target, no spec yet.
Skipping: none.
Next step: ask 4-question interview to pin acceptance criteria.
```

Example for typo fix:

```
Routing: Build → direct edit (gate-light)
Reason: typo fix, ≤5 lines, single file, no logic, not on high-risk path.
Skipping: Define + Plan (gate-skip rule). Verify still runs — it's mechanical
          (re-read the file, confirm the typo no longer appears). Never skip
          Verify; it always runs, the bar just scales down to "the edit landed".
Next step: edit + read-back to confirm + commit.
```

(Verify never fully drops — `verify-first` is always-on and the F-gate
runs on every change. "Skip Verify" would contradict that rule. What
trivial fixes skip is the *heavyweight* part of Verify — running a full
test suite or driving a browser. The lightweight verify — re-read the
file, confirm the edit took — still runs.)

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "Simple task, skip the spine" | Trivial-answer-only skips are explicit. Coding 5+ lines = run the spine. |
| "I already know what to build" | Even right answers without a spec drift mid-implementation. Write the 5-line spec; 30 seconds. |
| "User just wants a fix" | They want a *correct* fix. systematic-debugging finds the root; symptom patches recur. |
| "Tests are obvious, I'll add later" | Later never comes. TDD adds the test now or admits in writing it won't have one. |
| "Solo work, no contract needed" | The moment a second agent (or future-you in a fresh session) touches the surface, contract pays off. |
| "Reviewer takes too long" | Skip review = ship bugs. Codex/Gemini take ~30s for adversarial pass. |

## Don't

- Spawn specialist agents (frontend / backend / billing / etc.) before the phase is clear.
- Use `pre-merge-gate` as a placeholder ("I'll add it later"). It's the last skill, fires only at Ship.
- Replace `post-change-verify` with the agent's confidence ("looks right to me").
- Skip Define just because the user typed in a hurry. Ask 1-2 questions.
- Treat this skill as documentation. It's a router — pick a row, fire the skill.

## Influence

Sharpens the workflow spine that already exists in CLAUDE.md / AGENTS.md / GEMINI.md so that small models route the same way large ones do. Pairs with `team-routing` (specialist selection inside Build) and `pre-merge-gate` (final gate at Ship).
