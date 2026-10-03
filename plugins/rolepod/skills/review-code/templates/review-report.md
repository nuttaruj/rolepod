<!-- Canonical Review-phase artifact. Record each fact once; omit empty optional sections. -->

# <Feature / PR> Review

## Scope
<Diff/spec and every changed file: `read` or `skipped — reason`. A missing changed file makes this partial.>
**Snapshot H1 (immutable):** `<base sha>..<head sha>` <+ `diff <git diff HEAD | git hash-object --stdin>` for uncommitted work. Paired Lite reports use the same H1/hash and each names only its own lens. Never relabel H1; a re-check gets a separate report.

## Read
<Reviewer lens/role and coverage: files and behaviors read, paths traced, and where each claimed behavior held or failed. On a clean review, this is the evidence; security/full adversarial reports retain the depth-required trace.>

## Risk surfaces touched
<List touched risk surfaces, or `None`.>

## Reviewers
<Roles run and whether the round is complete; when merged, N reports → U unique findings (dedup key: file:line + root cause). R4 names its security and adversarial coverage.>

**Lite isolation** (Lite only; omit otherwise): <lens: spec | lens: standards>; fresh context: yes; received only this lens: yes; other report/findings visible: no; paired H1/hash matches: yes.

## Findings
<Omit this section when clean. Severity ordered. Each finding retains severity, file:line, axis, issue, impact, and fix direction; merged findings retain reviewer.>
- `file:line` — BLOCKER|MAJOR|MINOR — <axis> — <issue> — <impact> — <fix direction> — <reviewer, when merged>

## Questions
<Omit when none. Questions need an author answer, not a fix.>
- `file:line` — <question>

## Follow-ups
<Omit when none. Untouched pre-existing issues or issues outside a fix delta; each has axis and never drives verdict. Copy each to the plan.>
- `file:line` — <axis> — <issue>

## Tests reviewed
<Omit when none. State yes/no and whether assertions, mock boundary, and relevant concurrency coverage are strong.>

## Author fix closure
<No-recheck branches only; omit when there are no findings. Preserve source reports at H1. Each finding needs specific evidence, bounded H1→H2 fix delta (paths + delta hash), final H2, and whether the delta is covered. A green suite alone does not close a finding.>

**Cross-model adversarial pass** (R4 only; omit otherwise): <CLI/model receipt or precise NOT RUN reason. On a high-risk diff, vertical or NOT RUN except opt-in-off / wide-effort is a verification limitation; no fresh reviewer blocks merge until the user waives it.>

## Recommendation
<APPROVED — nothing open above MINOR; a pre-existing MAJOR parked in Follow-ups with its reason is closed. APPROVED-WITH-NITS — only MINOR / Questions remain. REJECTED — any open BLOCKER introduced here or on a changed path, or a MAJOR neither fixed nor parked as pre-existing with reason. Untouched pre-existing issues do not reject.>
APPROVED | APPROVED-WITH-NITS | REJECTED — <one-line reason>
