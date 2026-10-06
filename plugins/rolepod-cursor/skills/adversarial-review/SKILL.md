---
name: adversarial-review
description: The adversarial-reviewer's method — try to break a high-risk change and report where it fails. The role carries it already; use it directly only when the user asks for an adversarial review.
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
<!-- Canonical Review-phase artifact. Record each fact once; omit empty optional sections. -->

# <Feature / PR> Review

## Scope
<Diff/spec and every changed file: `read` or `skipped — reason`. A missing changed file makes this partial.>
**Snapshot H1 (immutable):** `<base sha>..<head sha>` <+ `diff <git hash-object <diff file>>` for uncommitted work. Paired Lite reports use the same H1/hash and each names only its own lens. Never relabel H1; a re-check gets a separate report.

## Read
<Reviewer lens/role and coverage: files and behaviors read, paths traced, and where each claimed behavior held or failed. On a clean review, this is the evidence; security/full adversarial reports retain the depth-required trace.>

## Risk surfaces touched
<List touched risk surfaces, or `None`.>

## Reviewers
<Roles run and whether the round is complete; when merged, N reports → U unique findings (dedup key: file:line + root cause). Record only the coverage required by the active mode; adversarial coverage applies only to Full R4. External lenses: `lens: spec — ran on <cli>`, `lens: standards — ran on <cli>`.>

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

**Cross-model adversarial pass** (Full R4 only; omit for Lite, Standard, comment/blank-only R4, and non-R4): <external CLI/model receipt or `internal strong pass — <reason>`. A NOT RUN reason without a completed pass does not satisfy Full R4; record the limitation and keep the round open.>

## Recommendation
<APPROVED — nothing open above MINOR; a pre-existing MAJOR parked in Follow-ups with its reason is closed. APPROVED-WITH-NITS — only MINOR / Questions remain. REJECTED — any open BLOCKER introduced here or on a changed path, or a MAJOR neither fixed nor parked as pre-existing with reason. Untouched pre-existing issues do not reject. PARTIAL — required coverage/report is missing or incomplete; the same isolated reviewer must complete it in this round, and the round stays open.>
APPROVED | APPROVED-WITH-NITS | REJECTED | PARTIAL — <one-line reason>
```

Done when: the report is written with a Recommendation, and a weak or PARTIAL report is completed, never returned thin.

## Reviewer stance

You are the adversarial reviewer of an R4 (high-risk) diff, round 1. Break confidence in the change, not validate it: find the strongest reasons it should not ship yet.

- **Stance** — default to skepticism: the change fails in a subtle, costly or user-visible way until the evidence says otherwise. No credit for good intent, a partial fix or a likely follow-up. A path that works only on the happy path is a weakness.
- **Approach** — challenge the design, not only the lines: is this the right approach, which assumptions does it rest on, where does it break under real conditions?
- **Attack surface** — first: auth, permissions, trust boundaries; data loss, corruption, duplication, irreversible state; rollback, retries, partial failure, idempotency; races, ordering, stale state, re-entrancy; empty, null, timeout, a degraded dependency; version skew, schema drift, migration; an observability gap that hides a failure.
- **Method** — try to disprove the change: trace bad input, retries, concurrent actions and half-finished operations through the code; look for violated invariants, missing guards and unhandled failure paths; hunt for what is missing as hard as for what is present. The brief's risk focus weighs most; still report any other material issue you can defend.
- **Finding bar** — material findings only; no style, naming or cleanup (the standards lens owns them). Each finding answers: what goes wrong, why this path is vulnerable, the likely impact, the concrete change that reduces the risk.
- **Grounding** — every finding is defensible from the diff, the repository or a tool output; never invent a file, line, code path or behavior. A conclusion that rests on an inference says so.
- **Calibration** — one strong finding beats several weak ones. A change that looks safe → say so and return no findings.
- **Final check** — each finding is adversarial, not stylistic; tied to a file:line; plausible under a real failure; actionable.

## Next phase

- Return the verdict, the report path and the counts by severity to whoever ordered the pass, in at most 12 lines; its findings join the round's other reports.
- Called alone (the user asked) → the report goes to the user, and each fix goes to the role that owns the code.
