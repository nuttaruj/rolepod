---
description: Force the full rolepod 6-phase lifecycle for this task — Define → Plan → Build → Verify → Review → Ship. Use when you know the task warrants the full workflow and don't want Lead's router to skip phases based on size heuristics.
disable-model-invocation: true
---

# Rolepod — Force Full Lifecycle

You are receiving an explicit user request to run the **complete 6-phase lifecycle** regardless of how small or routine the task appears. Lead's router (`using-rolepod`) normally trims phases for trivial work; this command overrides that judgment.

## What this means

User has invoked `/rolepod <task-description>`. Read the task, then run **every phase in order, no skips**:

```
Define → Plan → Build → Verify → Review → Ship
```

Even if the task looks like a one-line fix, a typo, or a tiny config change — user has explicitly opted out of the skip rules. They want the full ceremony.

## Phase-by-phase

### 1. Define — `spec-driven-development`

Run **Phase 0 discovery dialogue** first:
- Explore project context (read relevant files, recent commits)
- Ask clarifying questions one at a time via the native question UI (`AskUserQuestion` on Claude Code; plain-text 2-4 options + Recommended on Codex/Gemini)
- Propose 2-3 approaches with tradeoffs
- Present design sections incrementally for approval
- Self-review the spec (placeholder / contradiction / scope / ambiguity / skim test)
- Get user approval before drafting code

Choose the persistence tier (in-chat brief vs `docs/specs/<feature>.md`) per the spec-driven-development HARD-GATE table. Default to file when in doubt.

### 2. Plan — `planning-and-task-breakdown`

Break the approved spec into ordered, verifiable tasks with bite-sized steps (2-5 min each, single observable action). Use the canonical TDD pattern for logic tasks: `write failing test → run red → implement → run green → commit`. Save plan to `docs/plans/<feature>-plan.md` if scope warrants.

If multi-agent is needed, also fire `parallel-contract-orchestration` to write a cohesion contract before any agent spawn.

### 3. Build

Execute the plan task-by-task. If delegating to subagents, fire `subagent-task-execution` for the two-stage review pattern (implementer → spec-compliance reviewer → code-quality reviewer). If the task is bug-flavored, route through `systematic-debugging` (reproduce → trace → failing test → minimal fix).

Apply gates per commit: S1-S5 (simplicity), T1-T6 (test), F1-F5 (failure mode).

### 4. Verify — `post-change-verify`

Iron Law: NO COMPLETION CLAIM WITHOUT FRESH VERIFICATION EVIDENCE IN THIS MESSAGE. Run the relevant test / curl / screenshot / log command, paste output, then claim done.

### 5. Review — `code-review-and-quality` (+ `reviewer-flow` for high-risk)

Route to qa-tester floor + adversarial reviewers (Codex / Gemini / security-engineer / universal-reviewer) per `reviewer-flow` for high-risk surface (auth / billing / migration / payment / public API). For low-risk single-file, in-chat self-review is enough.

### 6. Ship — `pre-merge-gate` → `finishing-a-development-branch`

Fire `pre-merge-gate` (S + T + F + P gates). Then present the 4-option branch finish menu: merge / open PR / keep / discard. User picks.

## What to skip

Nothing. The user explicitly invoked `/rolepod` to skip nothing. If a phase would normally be skip-eligible under router rules (≤5 lines / single file / zero logic / not high-risk), still run it — abbreviated is fine, omitted is not.

## What still applies

- `verify-first` for any factual claim
- Hooks (subagent-commit block, precommit-gate, gate-reminder, cohesion-contract-check) — these fire regardless
- User override mid-flow: if user says "skip review" or "just ship", obey them — they're free to opt back into the skip rules they explicitly opted out of earlier

## Output pattern (announce at start)

```
Routing: Force full lifecycle via /rolepod
Phase: Define (entering Phase 0 discovery dialogue)
Skipping: none (user opted out of router skip rules)
Next step: <first question or context read>
```

Then run the spine.

## Common rationalizations to reject

| Excuse | Reality |
|--------|---------|
| "Task is trivial, Define is overkill" | User invoked `/rolepod` precisely to disable that judgment. Run it. |
| "User probably meant just Build" | If they wanted just Build they'd type the task without `/rolepod`. Read the directive literally. |
| "I'll merge Define + Plan into one turn to save time" | Each phase has its own exit evidence. Compressing them collapses the gates. Run them sequentially. |

## Pairs with

- `/rolepod-all` — same idea but spawns a real multi-process Claude Code agent team to run the phases in parallel (Claude Code v2.1.32+ + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` required). Use `/rolepod` for single-Lead execution, `/rolepod-all` for genuinely parallel cross-domain work.
- `/rolepod-careful` — overlapping but different: forces Careful mode (≤3 files / commit + mandatory peer review + Codex+Gemini adversarial) for high-risk surface. `/rolepod` is about *phases*; `/rolepod-careful` is about *rigor inside Build/Verify/Review*. They compose.
