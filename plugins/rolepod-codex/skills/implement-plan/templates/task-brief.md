<!-- Task brief — GENERATED: `plan-lint.sh --brief <N> <plan> [contract]`. -->
<!-- Lead adds Read first; the owner executes ONLY this brief, never commits. -->

# Task <N>: <title>
Plan: <path> · Spec: <path>

## Goal
<the task's Delivers line>

## Blocked by
<what this task consumes from each blocker>

## Read first
<2-3 files + the pattern to copy, named by the Lead — start here, never re-survey the repo>

## Files allowed
- <the task's Files ∪ the contract's ownership slice for this owner>

## Files forbidden
- <other Files-to-touch paths · do-not-touch list · everything else>

## Change
<the task's Change bullets, verbatim>

## Test / evidence
<test type + the assertion that proves it>

## Command
`<exact command — copy-paste runnable>`

## Done when
<pass/fail condition>

## Write
`self` | `external` (another CLI drafts; the owner still runs the loop)

## Reviewers
`universal-reviewer` (+ `security-engineer` on a high-risk path; + `qa-tester` (E2E) when the slice changes what a user sees) — `none` for a docs-only diff

## Bounds
- Edit Files allowed; an unowned path → touch + `Also touched:`; another owner's path → `NEEDS:` line. Never commit or push — leave the tree staged.
- Ticket loop per agent-protocol (Command → Reviewers → fix → round 2 = flagging reviewer → brief).
- Budget: build ≤40 tool calls, loop ≤120; past it → PARTIAL, never grind.
- Read the brief, not the plan; open a source only for a named residual. New idea → Follow-ups.
