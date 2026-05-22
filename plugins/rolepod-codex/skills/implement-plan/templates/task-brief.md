<!-- Rolepod subagent task brief — fill before delegating. Delete the <hints>. -->
<!-- The subagent executes ONLY this brief, and it does not commit. -->

# Task: <one-line goal>

## Goal
<What this task delivers — the outcome, in one or two sentences.>

## Files allowed
<Exact paths the subagent may edit. Keep to 1-2 files or one module.>
- `path/to/file`

## Files forbidden
<Paths the subagent must NOT touch — shared interfaces, other owners' code,
 anything outside this task.>

## Inputs
<Spec / plan reference, the relevant constraints, the existing pattern to match.>

## Test / evidence
<The command to run and the assertion that proves the task done.>
- Command: `<command>`

## Done criteria
<All true: test passes · lint clean · no scope creep beyond Files allowed.>

## Bounds
- Max tool calls: <e.g. 12>
- Do NOT commit — return a manifest; the Lead commits.
- New idea mid-task → write it down, finish this task, do not expand scope.
