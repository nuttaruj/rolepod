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
{{INCLUDE: core/fragments/review-report.md}}
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
