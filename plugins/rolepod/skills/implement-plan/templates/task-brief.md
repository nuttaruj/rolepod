<!-- Rolepod subagent task brief — fill before delegating. Delete the <hints>. -->
<!-- The task owner executes ONLY this brief, runs its own ticket loop, and does not commit. -->

# Task: <one-line goal>

## Goal
<What this task delivers — the outcome, in one or two sentences.>

## Files allowed
<Exact paths the subagent may edit: the task's slice — every layer it touches, nothing beyond.>
- `path/to/file`

## Files forbidden
<Paths the subagent must NOT EDIT (reading one to check a caller is fine) — shared interfaces, other owners' code,
 anything outside this task.>

## Inputs
<Spec / plan reference, the relevant constraints, the existing pattern to match.>

## Test / evidence
<The command to run and the assertion that proves the task done.>
- Command: `<command>`

## Done criteria
<All true: test passes · lint clean · no scope creep beyond Files allowed.>

## Write
<`self`, or `external` — another CLI drafts it (`rolepod-cross-family --kind implement`, pool
 opt-in); the owner still runs the loop.>
- Write: `self`

## Reviewers
<Roles the task owner dispatches on its diff in ONE message — `qa-tester` + `universal-reviewer`,
 or the concern-matched row; `none` only for a docs-only diff.>
- Reviewers: `qa-tester`, `universal-reviewer`

## Bounds
- Max tool calls: <e.g. 12>
- Do NOT commit — return a decision brief (diff stat, Command tail, reviewer verdicts + report paths, residuals); the Lead commits.
- New idea mid-task → write it down, finish this task, do not expand scope.
