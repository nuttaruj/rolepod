<!-- Rolepod task brief — GENERATED from the plan: `plan-lint.sh --brief <N> <plan> [contract]`. -->
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
`self` | `external` (another CLI drafts via `rolepod-cross-family --kind implement`; the owner still runs the loop)

## Reviewers
`qa-tester`, `universal-reviewer` (+ `security-engineer` on a high-risk path) — `none` only for a docs-only diff

## Bounds
- Edit only Files allowed; never commit or push — leave the tree staged.
- Ticket loop per agent-protocol: Command → Reviewers in ONE message → fix → round 2 = the flagging reviewer only (max 2) → decision brief.
- Read the brief, not the plan; open a source only for a named residual. A new idea → Follow-ups, never scope.
