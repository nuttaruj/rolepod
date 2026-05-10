# Triage — deep rules

Read when: task >5 files / multi-agent plan / drift suspected / scope unclear.

Core rules (Q1-Q4 checklist, Hard stops, Plan mode workflow) live in `~/.claude/CLAUDE.md`. This file = deep details only.

Related skills: `planning-and-task-breakdown`, `incremental-implementation`, `spec-driven-development`

## Run BEFORE every task + at every handoff

### Step 0 — Verify-first (NO guessing)

Apply verify-first principle per `~/.claude/CLAUDE.md` Verify-first section + full guide in `verify-first.md`.
Forbidden: pattern-match alone. Required: state assumption + risk if can't verify.

### Step 1 — Rollback reflex

Error appeared right after my last action? **Undo first.** Don't chain downstream fixes.

### Step 2 — Triviality test

Run Q1-Q4 checklist (canonical in `~/.claude/CLAUDE.md`).

Multi-file edit / verification / "find all callers of X" / business logic = **MUST delegate**.

### Step 3 — Scope cap per agent

Agents truncate at ~30-40 tool_uses.
**Cap each agent: ≤12 tool_uses + ≤5 files.**
Bigger task → split into multiple agents OR multi-wave plan.

### Step 4 — Nuclear check

Before: `rm -rf` / volume prune / `git checkout --` / force push:
1. Announce action + reason
2. Try lightest reversible alternative first
3. Wait for user confirm (unless durable instruction in CLAUDE.md authorized)

## Lead drift — STOP and re-triage

### Triggers

- 3+ files read in a row
- 2+ files edited in a row without delegating
- "context already loaded" rationalization → bias, ignore it
- Diagnosis done + (≥3 files OR ≥5 edits) remain → diagnosis IS the brief, hand off

### Self-check every 5 tool calls

Ask: "specialist cheaper / more focused?"
Yes → hand off via Agent tool.

### Why this matters

Lead context = expensive + shared with future tasks. Specialist context = isolated + fresh + cheaper.
Lead doing 10 file reads = burning shared budget on work specialist would do for 1/3 cost.

## Mid-implement scope creep check

Run when: implementation grew beyond plan / surprise files touched.

```
M1: Touched files outside plan?           yes → stop + re-plan or revert
M2: Added abstraction not in plan?        yes → cut or justify
M3: User intent shifted mid-task?         yes → confirm with user
M4: Implementation > 2x plan estimate?    yes → reassess (might be wrong approach)
```

Catch creep BEFORE pre-commit gate (cheaper to fix early).

## Phase abort — when to stop and reframe

Explore phase reveals task is wrong scope:
- Bug user reported = symptom of bigger issue
- Feature request conflicts with existing constraint
- Required change blocked by unrelated bug
- Scope is 5-10x what user described

→ STOP exploring. Report to user with: what found / what needs reframing / proposed new scope.
Don't proceed with original plan as if the discovery didn't matter.

## Escalation path when stuck (Sonnet/Haiku Lead)

Before hitting hard stop → try escalation in order:

1. **Fresh angle** — re-frame problem, drop assumptions
2. **MemPalace** — `mempalace_kg_query` for past similar problem
3. **Specialist subagent** — different context, might unstick
4. **Advisor (Opus)** — consult bigger model for judgment call
5. **Hard stop** — ask user (canonical list in CLAUDE.md)

Advisor only when Lead ≠ Opus. See `advisor.md`.
Don't skip to advisor — try 1-3 first. Advisor = Opus tokens (cost).

### When advisor itself fails

Advisor unavailable / unhelpful / quota exceeded:
1. Spawn 2nd specialist subagent with different angle
2. Suggest user run `/clear` + restart with better prompt
3. Hard stop — ask user for input

## Subagent briefing checklist

When delegating to specialist, brief MUST include:
- **Paths** (file paths, line numbers when known)
- **Lines** (specific line ranges to focus)
- **Criteria** (success conditions, what "done" looks like)
- **Caps** (≤12 tool_uses, ≤5 files, time budget)

Vague brief → specialist guesses → wrong work → wasted round.

### Subagent failure handling

Specialist returns:
- Empty / error → re-brief with more context (1 retry)
- Partial work → Lead inspects, decides keep or restart
- Wrong direction → abort, re-brief with explicit constraints
- Timeout → split task, run 2 smaller agents

After 2 specialist failures → escalate (advisor / hard stop).

## Test plan in Plan phase

Plan output MUST include test plan for non-trivial work:

```
Test plan:
- Unit: <fn> — <case>
- Integration: <flow> — <interaction>
- Edge cases: <list>
- Existing tests to verify: <list>
```

Vague ("add tests") → reject, demand specific cases. Full guide: `testing.md`.

## Goal-driven execution

Vague task → convert to verifiable goal **before** coding:

| Vague | Goal-driven |
|-------|-------------|
| "Add validation" | Write tests for invalid inputs → make pass |
| "Fix bug" | Write reproducing test → make pass |
| "Refactor X" | Tests pass before AND after |
| "Make it faster" | Define metric (p95 latency / bundle size) + threshold |
| "Improve UX" | Define measurable behavior change |

Multi-step → state plan as `[step] → verify: [check]` per row.
Strong success criteria let you loop independently; weak ("make it work") causes constant clarification.

## Let Claude interview user (big features)

For larger features → ask Claude to interview user:

```
I want to build [brief]. Interview me using AskUserQuestion tool.
Cover: technical impl, UI/UX, edge cases, tradeoffs.
Don't ask obvious questions, dig into hard parts.
Write spec to SPEC.md when done.
```

Once SPEC.md exists → start fresh session for implementation. Clean context + written spec.

## Common mistakes — DO NOT

- Self-do "because I already loaded context" — false economy
- Spawn 3rd agent when first 2 failed — re-frame with user
- Skip nuclear-check announcement for `rm -rf` / `git reset --hard`
- Brief specialist with "fix the bug" — give paths + criteria
- Let specialist run >12 tool_uses — split
- Ignore phase-abort signal because plan exists
- Skip mid-implement creep check, find bloat at pre-commit instead
