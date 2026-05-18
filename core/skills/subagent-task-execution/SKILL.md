---
name: subagent-task-execution
description: Two-stage per-task review pattern when Lead delegates an implementation task to a subagent — fresh implementer subagent writes the code, then a separate spec-compliance reviewer subagent and a separate code-quality reviewer subagent each evaluate it in independent contexts. Mark the task done only when both reviewers pass.
when_to_use: when Lead is about to delegate a non-trivial implementation task and the cost of a silent regression or spec drift is higher than the cost of two extra review rounds
---

# Subagent Task Execution

Default pattern (Lead briefs subagent, subagent writes, Lead ships) has two failure modes:

1. **Self-review blindness** — implementer's review of own work biased toward "works for case I thought of"
2. **Spec drift** — implementer reshapes task to match what was easy to write

Fix: two **separate** reviewers with **fresh context**. Implementer can't persuade reviewers; reviewers can't persuade each other; only Lead reconciles.

## When to use

ALL must hold:
- Lead delegating (not self-doing)
- Task touches business logic, public APIs, data integrity, security, money, migrations
- Cost of silent regression > cost of two extra rounds (~5-10 min)

Skip:
- Mechanical (rename, lint, doc tweak)
- Exploratory ("see if this approach works")
- Single-agent self-review caught bug + 1-line fix

## The four-step pattern

### Step 1 — Implementer subagent

Fresh subagent, implementer prompt (`templates/implementer-prompt.md`):
- Sees task brief + relevant code paths
- Does NOT see Lead's prior thinking, user chat history, reviewer templates
- Returns: changed files + summary + self-stated risks

Context destroyed at task end → future reviewers don't inherit biases.

### Step 2 — Spec compliance reviewer (fresh subagent)

Spec reviewer prompt (`templates/spec-reviewer-prompt.md`):
- Sees original task brief (spec)
- Sees implementer's diff
- Does NOT see implementer's self-justification
- Answers: **does diff satisfy brief verbatim?**

Findings = `[spec line] not satisfied by [diff line/location]`. No code-quality comments.

### Step 3 — Code quality reviewer (third fresh subagent)

Code-quality prompt (`templates/code-quality-reviewer-prompt.md`):
- Sees only diff (no brief, no spec reviewer's output)
- Evaluates: simplicity, idiom match, anti-spaghetti, defensive-bloat, naming
- Does NOT evaluate spec compliance

Why separate from spec reviewer: combined → "spec met but code gnarly, hmm…" hedge. Separate prompts force separate verdicts.

### Step 4 — Lead reconciles

- Both clean → mark done, commit
- Spec drift → fix and re-run both, or re-spec with user
- Quality smell → fix and re-run only quality reviewer (spec unchanged)
- Reviewers disagree → Lead is tiebreaker. Don't spawn 4th — that's reviewer-shopping.

## Continuous execution — between tasks

<EXTREMELY-IMPORTANT>
Once a plan is approved and execution starts, Lead does NOT pause to chat with the user between tasks. Execute the whole task list end-to-end. "Should I continue?" / "Want me to do the next one?" / progress check-ins waste user attention and tokens — the user already approved the plan, executing it is the agreement.
</EXTREMELY-IMPORTANT>

**Only stop between tasks when:**

- **BLOCKED** — missing dep / failing verify / instruction genuinely unclear and you cannot resolve from spec + code
- **AMBIGUITY** — two valid interpretations and picking the wrong one would burn rework
- **HIGH-RISK BOUNDARY** — about to touch auth / billing / migrations / payments / secret rotation AND plan did not flag this for explicit user gate
- **PLAN DRIFT** — discovered the next task depends on something the spec missed; replanning needed
- **ALL TASKS COMPLETE** — final reconcile + ship handoff

**Don't stop for:**

- Progress summaries (each task already commits + verifies, the git log IS the summary)
- "Just confirming" before next task (plan said do it, do it)
- Asking permission to read more files (read what you need)
- Reporting that a task passed (commit message + verify output already say so)

**Pattern in practice:**

```
Lead: dispatching T-01 implementer...
[implementer subagent runs]
Lead: T-01 implementer done. Dispatching spec reviewer...
[spec reviewer runs]
Lead: T-01 spec pass. Dispatching quality reviewer...
[quality reviewer runs]
Lead: T-01 all green, committed abc1234. Dispatching T-02 implementer...
```

NOT:

```
Lead: T-01 done — want me to start T-02?       ← wasted ask
User: yes
Lead: starting T-02...
```

If user actually needs to interrupt, they will. Default to flow.

## Round caps

- Implementer: 1 round (can't pass in one → brief is wrong, re-brief)
- Spec reviewer: ≤2 rounds (drift fix + verify)
- Quality reviewer: ≤3 rounds (smell fix iterations)
- Hard total: 6 subagent invocations per task. Higher → escalate.

## Templates

Three prompt templates ship with this skill (committed for reuse + PR auditability):
- `templates/implementer-prompt.md`
- `templates/spec-reviewer-prompt.md`
- `templates/code-quality-reviewer-prompt.md`

## Pairs with

- `parallel-contract-orchestration` — each parallel implementer goes through its own two-stage review
- `using-worktrees` — implementer + reviewers share worktree (read-only for reviewers)
- `test-driven-development` — spec reviewer's verification strongest when brief includes failing tests to turn green

## Influence

Two-reviewer split (spec-compliance vs code-quality) is load-bearing — fresh reviewer contexts catch what the implementer rationalized. Round caps + template commitment are rolepod additions on top.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Task small, one reviewer enough" | Spec drift independent of size — 10-line diff can quietly answer different question. |
| "Trust this implementer, skip reviewers" | Trust is not review. Reviewer catches what trust missed. |
| "Both reviewers say same thing" | They won't — design. Spec-clean can still be gnarly; clean can miss spec. |
| "I'll review myself" | Lead context polluted by brief-writing. Fresh reviewer context catches what Lead can't see. |
| "3 subagents per task too many" | One missed regression in prod > 100 extra rounds. |

Default: run all three. Asymmetric cost.
