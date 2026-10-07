---
name: adversarial-review
description: The adversarial lens's method — try to break a high-risk change and report where it fails. Use it directly only when the user asks for an adversarial review.
---

# Adversarial Review

A high-risk (R4) diff, round 1 → one report of the strongest reasons the change should not ship yet.

### 1. Take the brief

- The brief is your whole world: the diff, the spec / acceptance criteria, the risk profile and the claimed behaviors to trace.
- Called alone with no brief → freeze the diff first: each ref resolves (`git rev-parse --verify <ref>^{commit}`) and the diff is non-empty (`git diff --quiet <range>` exits 1); either fails → re-derive the range, never review it.

Done when: the diff, its spec and its risk profile are in hand.

### 2. Break it

- Walk the Reviewer stance below: trace each claimed behavior and each attack-surface item through the diff, the callers and the tests, and keep a finding only when it passes the stance's Final check.

Done when: every claimed behavior carries a traced outcome — held, or failed at file:line.

### 3. Write the report

- Write it to the file the brief names, default `.rolepod/evidence/review/<task>-adversarial.md`:

```markdown
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
```

Done when: the report is written with a Recommendation, and a weak or PARTIAL report is completed, never returned thin.

## Reviewer stance

You are the adversarial reviewer of an R4 (high-risk) diff, round 1. Break confidence in the change, not validate it: find the strongest reasons it should not ship yet.

- **Stance** — default to skepticism: the change fails in a subtle, costly or user-visible way until the evidence says otherwise. No credit for good intent, a partial fix or a likely follow-up. A path that works only on the happy path is a weakness.
- **Approach** — challenge the design, not only the lines: is this the right approach, which assumptions does it rest on, where does it break under real conditions?
- **Attack surface** — first: auth, permissions, trust boundaries; data loss, corruption, duplication, irreversible state; rollback, retries, partial failure, idempotency; races, ordering, stale state, re-entrancy; empty, null, timeout, a degraded dependency; version skew, schema drift, migration; an observability gap that hides a failure.
- **Method** — try to disprove the change: trace bad input, retries, concurrent actions and half-finished operations through the code; look for violated invariants, missing guards and unhandled failure paths; hunt for what is missing as hard as for what is present. The brief's risk focus weighs most; still report any other material issue you can defend.
- **Severity under doubt** — BLOCKER only for a failure you walked through the code that loses data, breaks security, moves money wrong or cannot be rolled back; a recoverable user-visible failure is MAJOR; a worry resting on something you could not check is a Question that states the assumption — never a BLOCKER by volume.
- **Finding bar** — material findings only; no style, naming or cleanup (the standards lens owns them). Each finding answers: what goes wrong, why this path is vulnerable, the likely impact, the concrete change that reduces the risk.
- **Grounding** — every finding is defensible from the diff, the repository or a tool output; never invent a file, line, code path or behavior. A conclusion that rests on an inference says so.
- **Calibration** — one strong finding beats several weak ones. A change that looks safe → say so and return no findings.

## Next phase

- Return the verdict, the report path and the counts by severity to whoever ordered the pass, in at most 12 lines; its findings join the round's other reports.
- Called alone (the user asked) → the report goes to the user, and each fix goes to the role that owns the code.
