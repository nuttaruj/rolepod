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

## Explicit-invoke detection — `/rolepod` force-full-lifecycle mode

**Cross-CLI universal trigger.** When the user opens their message with any of these tokens, switch from auto-router mode to **force-full-lifecycle mode** (no phase skips):

- `/rolepod <task>` — Claude / Gemini slash style
- `/using-rolepod <task>` — Codex skill-slash style
- `$using-rolepod <task>` — Codex dollar-skill UI style
- Natural language: `force full lifecycle`, `rolepod mode`, `run all phases`, `no skip`

The auto-trigger of this skill fires on every request regardless of CLI; the **detection above is what changes the mode**. No separate slash command file is needed — Claude/Codex/Gemini all funnel through this skill.

### Force-full-lifecycle behavior

When detected, run **every phase in order, no skips**:

```
Define → Plan → Build → Verify → Review → Ship
```

Even if the task looks like a one-line fix, a typo, or a tiny config change — the user has explicitly opted out of skip rules. They want the full ceremony.

**Phase-by-phase under force-full mode:**

1. **Define — `spec-driven-development`** — Phase 0 discovery dialogue (explore context, ask clarifying questions one at a time via native question UI or plain-text fallback, propose 2-3 approaches, incremental section approval, spec self-review). Pick persistence tier (in-chat brief vs `docs/specs/<feature>.md`) per the skill's HARD-GATE table.
2. **Plan — `planning-and-task-breakdown`** — break approved spec into bite-sized steps (2-5 min each, single observable action). TDD canonical: `write failing test → run red → implement → run green → commit`. If multi-agent, fire `parallel-contract-orchestration` for the cohesion contract.
3. **Build** — execute task-by-task. Subagent delegation goes through `subagent-task-execution` (implementer → spec-compliance reviewer → code-quality reviewer). Bug-flavored tasks route through `systematic-debugging`. Apply S1-S5 / T1-T6 / F1-F5 per commit.
4. **Verify — `post-change-verify`** — Iron Law: no completion claim without fresh verification evidence in this message.
5. **Review — `code-review-and-quality`** + `reviewer-flow` — route to qa-tester floor + adversarial reviewers (Codex / Gemini / security-engineer / universal-reviewer) for high-risk surface. For force-full mode, dispatch reviewers **regardless of path-keyword match** (manual risk escalation).
6. **Ship — `pre-merge-gate` → `finishing-a-development-branch`** — S+T+F+P gates, then 4-option branch finish menu (merge / open PR / keep / discard).

### Careful-mode rigor (default-on in force-full mode)

`/rolepod` invocation also tightens rigor inside Build/Verify/Review:

- **≤3 files per commit** (default workflow allows ≤5)
- **Mandatory peer review** even for small diffs (no skip on ≤5 lines / single file / zero logic)
- **All S1-S5 + T1-T6 gates explicit** every commit (no router skip judgment)
- **Codex + Gemini adversarial reviewers** dispatched regardless of path-keyword match

User can opt back to lighter review mid-flow ("normal review is fine, skip careful rigor") — rigor is default-on, not mandatory-on.

### What still applies under force-full mode

- `verify-first` for any factual claim
- Hooks (subagent-commit block, precommit-gate, gate-reminder, cohesion-contract-check) — fire regardless
- User override mid-flow: if user says "skip review" or "just ship", obey them

### Output pattern (announce at start of force-full mode)

```
Routing: Force full lifecycle via /rolepod (skill explicit-invoke)
Phase: Define (entering Phase 0 discovery dialogue)
Skipping: none (user opted out of router skip rules)
Next step: <first question or context read>
```

### Common rationalizations to reject (force-full mode)

| Excuse | Reality |
|--------|---------|
| "Task is trivial, Define is overkill" | User invoked `/rolepod` precisely to disable that judgment. Run it. |
| "User probably meant just Build" | If they wanted just Build they'd type the task without `/rolepod`. Read the directive literally. |
| "I'll merge Define + Plan into one turn to save time" | Each phase has its own exit evidence. Compressing them collapses the gates. Run them sequentially. |

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
| "audit / full audit / review whole repo / find all X / sweep / map" | **Review (repo-wide)** | **scope-then-spawn** (see below) | balanced |
| "ship / merge / push / PR / ready / go live" | **Ship** | `pre-merge-gate` | **adversarial** (final review) |
| "document / explain the choice / write ADR / runbook" | (cross-cut) | `documentation-and-adrs` | cheap |

If no row matches: ask the user what phase the task is in. Don't pattern-match yourself into Build.

### Model tier hint reading

- **cheap** = haiku-class. Docs, PM, business analysis, customer-facing copy.
- **balanced** = sonnet-class (default). Normal implementation.
- **strong** = opus-class. Architecture, billing, security, migration code.
- **adversarial** = opus-class reviewer. Final-pass code review; security review of high-risk paths.

Agent frontmatter sets the model. Lead doesn't override unless user explicitly asks.

## Scope-then-spawn — repo-wide audit / sweep / "find all X"

Default for any task that touches the **whole repo** (audit, refactor sweep, dead-code hunt, security pass, dependency map, "find every usage of X"). Stops Lead from fanning out parallel agents over hundreds of files when a structural query can narrow the list first.

```
1. Scope    →  list the files / symbols / processes actually in scope
2. Narrow   →  filter to the suspicious / risky / changed subset
3. Spawn    →  parallel agents ONLY on the narrowed list (or self-do)
```

### Tool order — GitNexus if available, fallback otherwise

| Step | GitNexus installed + fresh | GitNexus NOT installed |
|---|---|---|
| Scope | `gitnexus_query("audit target")` → process / cluster list | `rg -l <pattern>` + `find` |
| Narrow | `gitnexus_impact(target, upstream)` + `gitnexus_context(symbol)` → callers + blast radius | `rg` cross-reference + Read on hotspots |
| Spawn | Parallel agents on 5-10 narrowed files | Parallel agents on rg-filtered list |

GitNexus path: sub-second graph query, no per-file LLM read. Cuts token cost ~90% on structural audits.
Fallback path: `rg` + `find` are universal. No GitNexus = no block. Lead doesn't nag the user to install anything.

### When scope-then-spawn does NOT apply

- Single-file change → direct edit, no scoping
- Semantic-only audit (logic bugs, design smell, security reasoning) → GitNexus can't reason about meaning; spawn agents directly but cap the file count and ask user to narrow if >20
- User already named the files → skip step 1

### Anti-pattern

Spawning 1 agent per file across 100+ files for "audit the whole repo" without a scoping pass. Burns tokens, drowns Lead in summaries, misses cross-file patterns GitNexus would surface in one query.

## State machine — phase → exit evidence → next

Router fires the **first** skill per phase. Phase exits only when its **exit evidence** is on the table (or user explicitly authorizes skip). Next phase reads from the **Next allowed** column — no jumping.

| Phase | Required first skill | Exit evidence | Next allowed |
|---|---|---|---|
| **Define** | `spec-driven-development` | written spec OR approved one-line design (≤5-line task) OR explicit "skip spec" | Plan |
| **Plan** | `planning-and-task-breakdown` (+ `team-routing` + `parallel-contract-orchestration` if multi-agent) | ordered task list with done-condition + verify command per task; dependencies marked | Build |
| **Build** | `test-driven-development` (+ `subagent-task-execution` if delegated) (+ `systematic-debugging` for bug intent) | changed files + tests added (or explicit no-test justification) + red→green evidence | Verify |
| **Verify** | `post-change-verify` | fresh command output / screenshot / curl / log evidence; OR explicit "verify impossible because X" risk note | Review (high-risk / multi-file) OR Ship (low-risk) |
| **Review** | `code-review-and-quality` (+ `reviewer-flow` for high-risk routing → Codex / Gemini / security-engineer) | findings fixed OR rejected with line-anchored reason; no unresolved blocker | Ship |
| **Ship** | `pre-merge-gate` then `finishing-a-development-branch` | S+T+F+P gates green (P = PR scope, one concern per PR); required CI lanes pass; user approval when policy requires; 4-option finish menu presented (merge / open PR / keep / discard) | **end** |

**Router decides the first move only.** Each downstream skill owns its own gates; using-rolepod doesn't re-explain them.

## Skip rule

Skip a phase WHEN ALL true (state explicitly in response):

- task is pure question / explanation / lookup (no file change)
- OR diff ≤5 lines + 1 file + 0 logic-bearing lines + not on high-risk path
- OR user explicit: "skip spec" / "just commit" / "answer only" / "no plan" / "ship as-is"

**Verify never fully skips** — `verify-first` is always-on. Trivial fixes drop the heavyweight verify (full suite, browser drive), not the lightweight one (re-read file, confirm edit landed).

## Stop conditions

- Coding before Define on ambiguous request → STOP, run `spec-driven-development`.
- Claiming done before Verify → STOP, run `post-change-verify`.
- 2nd parallel agent spawn without contract → STOP, run `parallel-contract-orchestration` (hook will block anyway).
- Sub-agent attempting `git commit` / `git push` / `gh pr merge` → blocked by `block-subagent-commit.sh`; Lead commits after reviewer pass.
- High-risk path (auth/billing/migrations/crypto/payments) with 0 reviewer agents dispatched → STOP, dispatch qa-tester + (Codex / Gemini / security-engineer if available).
- 3rd agent on same issue OR 3rd PR on same surface in one session → STOP, ask user (hard-stop rule).
- Diff mixes 2+ unrelated concerns at push/merge time → STOP, split into separate PRs (`pre-merge-gate` P1-P4 gate).
- SessionStart warning "Sibling Claude session(s) detected in this worktree" → STOP before any Edit/Write. Spawn isolated worktree first (`git worktree add ../<repo>-task-<ts> <branch> && cd`), continue work there. Override: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` for intentional read-only review sessions.

## Finish ritual (Ship phase exit)

When the user says "done" / "finished" / "complete" / "ready" — or when the task obviously reached a natural stopping point — fire **in order**:

1. `post-change-verify` — produce concrete evidence the change works (test output / screenshot / curl).
2. `code-review-and-quality` — if multi-file or high-risk, route via `reviewer-flow` to pick adversarial reviewers (Codex / Gemini / qa-tester) per their domain match.
3. `finishing-a-development-branch` — present the 4-option decision menu so the user picks the next step explicitly:
   - **merge** to main
   - **open PR** (current branch)
   - **keep branch** open (still iterating)
   - **discard** (work was exploratory)

Never auto-pick. The branch decision is the user's, not Lead's.

## Output pattern

```
Routing: <phase> → <skill>
Reason: <one sentence>
Skipping: <phases + why>, or "none"
Next step: <concrete action>
```

Example — vague feature:
```
Routing: Define → spec-driven-development
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
Skipping: none — runs post-change-verify → code-review-and-quality → finishing-a-development-branch.
Next step: run tests, paste pass output, present 4-option menu.
```

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
