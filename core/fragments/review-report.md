# <Feature / PR> Review

## Scope
<The diff and every changed file: `read` or `skipped — reason`; a skipped changed file makes the report partial.>
**Snapshot H1 (immutable):** `<H1 tree id>` and `<diff hash>` from your brief (standalone: the range you took and its diff hash). Never relabel H1; a re-check writes its own report at H2.

## Read
<Your lens or role and what you covered: the files and behaviors read, the paths traced, and where each claimed behavior held or failed. On a clean review this is the evidence.>

## Risk surfaces touched
<Each touched risk surface, or `None`.>

## Findings
<Omit when clean. Severity ordered; each keeps severity, file:line, axis, issue, impact and fix direction.>
- `file:line` — BLOCKER|MAJOR|MINOR — <axis> — <issue> — <impact> — <fix direction>

## Questions
<Omit when none. A question needs the author's answer, not a fix.>
- `file:line` — <question>

## Follow-ups
<Omit when none. A pre-existing issue on an untouched path, or one outside a fix delta; each with its axis, never a verdict driver.>
- `file:line` — <axis> — <issue>

## Tests reviewed
<Omit when none. Say whether the assertions, the mock boundary and the concurrency coverage are strong.>

## Recommendation
<APPROVED — nothing open above MINOR (a pre-existing MAJOR parked in Follow-ups with its reason counts as closed) · APPROVED-WITH-NITS — only MINOR or Questions remain · REJECTED — an open BLOCKER introduced here or on a changed path, or a MAJOR neither fixed nor parked as pre-existing with a reason; untouched pre-existing issues never reject · PARTIAL — required coverage or a report is missing or incomplete; the round stays open · BLOCKED — the brief cannot be reviewed: `BLOCKED: <the one question>`.>
APPROVED | APPROVED-WITH-NITS | REJECTED | PARTIAL | BLOCKED — <one-line reason>
