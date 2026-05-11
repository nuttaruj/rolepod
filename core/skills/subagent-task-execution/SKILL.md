---
name: subagent-task-execution
description: Two-stage per-task review pattern when Lead delegates an implementation task to a subagent — fresh implementer subagent writes the code, then a separate spec-compliance reviewer subagent and a separate code-quality reviewer subagent each evaluate it in independent contexts. Mark the task done only when both reviewers pass. Use when Lead is about to delegate a non-trivial implementation task and the cost of a silent regression or spec drift is higher than the cost of two extra review rounds.
---

# Subagent Task Execution

The default delegation pattern — Lead briefs one subagent, subagent writes code, Lead glances at the diff and ships — has two failure modes that compound:

1. **Self-review blindness** — the implementer's review of their own work is biased toward "it works for the case I just thought of."
2. **Spec drift** — implementer subtly reshapes the task to match what was easy to write, not what was asked.

This skill makes both failures expensive by interposing two **separate** reviewer subagents with **fresh context**. The implementer cannot persuade the reviewers; the reviewers cannot persuade each other; only Lead reconciles.

## When to use

Use the two-stage pattern when ALL hold:

- Lead is delegating to a subagent (not doing the work itself)
- The task touches business logic, public APIs, data integrity, security, money, or migrations
- The cost of a silent regression > cost of two extra review rounds (~5-10 min added)

Skip the pattern when:

- The change is mechanical (rename, lint fix, doc tweak)
- The task is exploratory ("see if this approach works")
- A single-agent self-review caught a bug already and the fix is 1-line

## The four-step pattern

### Step 1 — Implementer subagent

Lead spawns a fresh subagent with the implementer prompt template (`templates/implementer-prompt.md`). The implementer:

- Sees only the task brief + relevant code paths
- Does NOT see Lead's prior thinking, the user's chat history, or any reviewer template
- Returns: changed files + summary + self-stated risks

The implementer's context is destroyed at task end. Future reviewers cannot inherit its biases.

### Step 2 — Spec compliance reviewer (fresh subagent)

Lead spawns a second subagent with the spec reviewer prompt (`templates/spec-reviewer-prompt.md`). This reviewer:

- Sees the original task brief (the spec)
- Sees the implementer's diff
- Does NOT see the implementer's self-justification
- Answers one question: **does the diff satisfy the brief verbatim?**

Spec drift findings = list of `[spec line] not satisfied by [diff line/location]`. No code-quality comments — that's the next reviewer's job.

### Step 3 — Code quality reviewer (third fresh subagent)

Lead spawns a third subagent with the code-quality prompt (`templates/code-quality-reviewer-prompt.md`). This reviewer:

- Sees only the diff (not the brief, not the spec reviewer's output)
- Evaluates: simplicity, idiom match, anti-spaghetti, defensive-bloat, naming
- Does NOT evaluate spec compliance — assumes that's already verified

Why separate from spec reviewer: combining them produces "the spec is met but the code is gnarly, hmm…" — the reviewer hedges. Separate prompts force separate verdicts.

### Step 4 — Lead reconciles, marks done

Lead reads both reviewer reports:

- Both clean → mark task done, commit
- Spec reviewer flagged drift → either fix and re-run both reviewers, or re-spec with the user
- Quality reviewer flagged smell → fix and re-run only the quality reviewer (spec hasn't changed)
- Reviewers disagree (rare) → Lead is the tiebreaker. Don't spawn a 4th reviewer to break ties — that's reviewer-shopping.

## Round caps

- Implementer: 1 round (if it can't produce a passing diff in one round, the brief is wrong — re-brief)
- Spec reviewer: ≤2 rounds (drift fix + verify)
- Quality reviewer: ≤3 rounds (smell fix iterations)
- Hard total cap: 6 subagent invocations per task. Higher → escalate (advisor / hard stop).

## Templates

Three prompt templates ship with this skill:

- `templates/implementer-prompt.md` — brief shape for the implementer
- `templates/spec-reviewer-prompt.md` — spec-compliance reviewer brief
- `templates/code-quality-reviewer-prompt.md` — code-quality reviewer brief

Templates are committed so they're reusable across tasks and so the pattern is auditable in PRs (reviewer who reads the PR can see exactly what prompts produced each artifact).

## Pairs with

- `parallel-contract-orchestration` — when multiple implementer subagents run in parallel, each goes through its own two-stage review.
- `using-worktrees` — implementer + reviewers can share a worktree (read-only for reviewers).
- `test-driven-development` — the spec reviewer's verification of "brief satisfied" is strongest when the brief includes failing tests the implementer must turn green.

## Influence

Adapted from [obra/superpowers](https://github.com/obra/superpowers) `subagent-driven-development/SKILL.md`. The two-reviewer split (spec vs quality) is the load-bearing idea. Round caps and prompt-template commitment are rolepod additions.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The task is small, one reviewer is enough" | Spec drift is independent of size — a 10-line diff can quietly answer a different question than the brief asked. |
| "I trust this implementer, skip reviewers" | Trust is not a review. The reviewer's job is to catch what trust missed. |
| "Both reviewers will say the same thing, save tokens" | They won't — that's the whole design. Spec-clean code can still be gnarly; clean code can still miss spec. |
| "I'll review it myself instead of spawning a reviewer" | Lead context is polluted by the brief-writing phase. The reviewer's fresh context catches what Lead can no longer see. |
| "Three subagents per task is too many" | The compounding cost of one missed regression in production exceeds 100 extra reviewer rounds. |

Default when rationalizing: run all three. The total added latency is small; the asymmetric cost of skipping is large.
