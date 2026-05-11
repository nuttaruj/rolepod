# Triage — deep rules

Read when: task >5 files / multi-agent / drift suspected / scope unclear.

Core rules (Q1-Q4, Hard stops, Plan workflow) in `~/.claude/CLAUDE.md`. This file = deep details.

Related skills: `planning-and-task-breakdown`, `incremental-implementation`, `spec-driven-development`.

## Run BEFORE every task + at each handoff

### Step 0 — Verify-first

Per CLAUDE.md + `verify-first.md`. Pattern-match alone = forbidden. State assumption + risk if can't verify.

### Step 1 — Rollback reflex

Error right after my last action? **Undo first.** Don't chain downstream fixes.

### Step 2 — Triviality test

Run Q1-Q4. Multi-file / verification / "find all callers of X" / business logic = **MUST delegate**.

### Step 3 — Scope cap

Agents truncate at ~30-40 tool_uses. **Cap each: ≤12 tool_uses + ≤5 files.** Bigger → split into agents or waves.

### Step 4 — Nuclear check

Before `rm -rf` / volume prune / `git checkout --` / force push:
1. Announce action + reason
2. Try lightest reversible alternative first
3. Wait for user confirm (unless CLAUDE.md authorized)

## Lead drift — STOP and re-triage

### Triggers

- 3+ files read in a row
- 2+ files edited in a row without delegating
- "context already loaded" rationalization = bias, ignore
- Diagnosis done + (≥3 files OR ≥5 edits) remain → diagnosis IS brief, hand off

### Self-check every 5 tool calls

"Specialist cheaper / more focused?" Yes → hand off via Agent tool.

### Why

Lead context = expensive + shared. Specialist = isolated + fresh + cheaper. Lead doing 10 reads burns shared budget on specialist work.

## Mid-implement scope creep

Run when impl grew beyond plan / surprise files touched:

```
M1: Touched files outside plan?     yes → stop + re-plan or revert
M2: Added abstraction not in plan?  yes → cut or justify
M3: User intent shifted mid-task?   yes → confirm
M4: Impl > 2x plan estimate?        yes → reassess (wrong approach?)
```

Catch BEFORE pre-commit gate.

## Phase abort — stop and reframe

Explore reveals task is wrong scope:
- Reported bug = symptom of bigger issue
- Feature conflicts with existing constraint
- Required change blocked by unrelated bug
- Scope 5-10x user's description

→ STOP. Report: what found / what needs reframing / proposed new scope.

## Escalation when stuck (Sonnet/Haiku Lead)

Before hard stop, in order:

1. **Fresh angle** — re-frame, drop assumptions
2. **MemPalace** — `mempalace_kg_query` for past similar
3. **Specialist subagent** — different context might unstick
4. **Advisor (Opus)** — consult bigger model
5. **Hard stop** — ask user (CLAUDE.md)

Advisor only when Lead ≠ Opus. See `advisor.md`. Try 1-3 first.

### When advisor fails

Unavailable / unhelpful / quota:
1. 2nd specialist with different angle
2. Suggest `/clear` + restart
3. Hard stop

## Subagent briefing checklist

Brief MUST include:
- **Paths** (file paths + line numbers when known)
- **Lines** (specific ranges)
- **Criteria** (success / "done" conditions)
- **Caps** (≤12 tool_uses, ≤5 files, time budget)

Vague brief → guess → wasted round.

### Subagent failure handling

- Empty / error → re-brief with more context (1 retry)
- Partial → Lead inspects, decides keep or restart
- Wrong direction → abort, re-brief with constraints
- Timeout → split into 2 smaller agents

After 2 failures → escalate (advisor / hard stop).

## Test plan in Plan phase

Non-trivial work MUST include:

```
Test plan:
- Unit: <fn> — <case>
- Integration: <flow> — <interaction>
- Edge cases: <list>
- Existing tests to verify: <list>
```

Vague ("add tests") → reject. Full guide: `testing.md`.

## Goal-driven execution

| Vague | Goal-driven |
|-------|-------------|
| "Add validation" | Tests for invalid inputs → pass |
| "Fix bug" | Reproducing test → pass |
| "Refactor X" | Tests pass before AND after |
| "Make it faster" | Metric (p95 / bundle) + threshold |
| "Improve UX" | Measurable behavior change |

Multi-step → `[step] → verify: [check]` per row.

## Interview pattern (big features)

```
I want to build [brief]. Interview me using AskUserQuestion tool.
Cover: technical impl, UI/UX, edge cases, tradeoffs.
Don't ask obvious questions, dig into hard parts.
Write spec to SPEC.md when done.
```

After SPEC.md → fresh session for impl.

## Common mistakes — DO NOT

- Self-do "context already loaded" — false economy
- 3rd agent when first 2 failed — re-frame with user
- Skip nuclear-check announcement
- Brief specialist with "fix the bug" — give paths + criteria
- Specialist >12 tool_uses
- Ignore phase-abort because plan exists
- Skip mid-implement creep check
