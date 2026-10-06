<!-- Rolepod session handoff — default path: docs/rolepod/handoff.md. -->
<!-- The next session re-anchors from disk and reads only required linked state. -->

# Handoff Brief — <task>

## Original request
<The user's request, literal quote — plus every correction or scope change
 stated since; the latest instruction is authoritative.>

## Current branch / commit
<Branch name + last commit SHA. Commit first if you are the Lead and the gates
 pass; a subagent never commits — otherwise paste `git status --short` here:
 an accurately described dirty tree is still resumable, and never green a
 test or bypass a gate just to get a commit. The next session resumes from
 disk, not from this session's memory.>

## Resume state
<Repository root, worktree, branch, SHA, and dirty state; owning phase, next
 task and command. Include inline checklist ticks when applicable.>

## Required reads
<Next task and only the predecessor handoff, contract clauses, unresolved
 debug state, or other artifact required for the next decision. Link receipts
 and evidence for files/tests already covered; do not repeat their details;
 without a receipt, keep the required facts here.
 Read the full plan/spec only if scope, acceptance, ownership, or position is
 unclear. `none` when there are no required predecessor artifacts.>

## Files touched
<Paths edited so far + a word on each.>

## Tests run and status
<What was run, green / red, the last known result. Reusing an older run? It
 must still meet `implement-plan` Prove (scope, inputs, environment and provenance still match) before you cite it as current.>

## Constraints still active
<Deadlines, no-touch zones, style rules, decisions the user pinned.>

## Decisions made
<Non-obvious choices made this session and why — so the next session does
 not re-litigate them.>

## Blockers and attempts
<What is stuck, if anything, and what is needed to unblock. Preserve the
 current failed-attempt count and each failed fix; include Second opinion
 state and its ledger pointer. Do not reset these on owner, phase, CLI, or
 session changes.>

## Resume with
<Which owning phase/skill resumes and the next concrete command. This is
 runnable from the standalone skill text without helpers, native hooks, or
 agents; state when any of those are unavailable instead of implying they ran.
 A new native startup uses its captured mode; same-session compact/reload
 keeps the carried mode.>
