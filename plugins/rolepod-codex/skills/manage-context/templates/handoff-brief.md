<!-- Rolepod handoff brief — write before starting a fresh session. -->
<!-- The new session starts from this brief, then reads every artifact it links; nothing else carries over. Delete <hints>. -->

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

## Artifacts to read next
<Path to each one the flow has — plan (its checkboxes are the position; an
 inline checklist is re-stated here with its ticks), spec, cohesion contract,
 debug ledger. `none` for one the flow lacks. Link, never paste.>

## Files touched
<Paths edited so far + a word on each.>

## Tests run and status
<What was run, green / red, the last known result. Reusing an older run? It
 must still meet check-work's evidence cache (Run the evidence) before you cite it as current.>

## Constraints still active
<Deadlines, no-touch zones, style rules, decisions the user pinned.>

## Decisions made
<Non-obvious choices made this session and why — so the next session does
 not re-litigate them.>

## Blockers and attempts
<What is stuck, if anything, and what is needed to unblock. Escalating or
 mid-debug → `Attempts: <n> used` on the current goal with one line per
 failed fix (what, why it stayed red), the ledger's `Second opinion:` state,
 and the ledger path above — never the ledger pasted.>

## Resume with
<Which skill the next session starts in, and the next concrete command.
 Any rolepod-equipped CLI can be the next session — skill names match
 across adapters.>
