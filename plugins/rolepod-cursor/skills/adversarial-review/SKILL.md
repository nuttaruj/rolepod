---
name: adversarial-review
description: Run the one adversarial pass of an R4 (high-risk) diff's round 1 — an external CLI through cross-family when the pool is usable, else universal-reviewer on a strong-class model — that tries to break the change and challenges its approach. Use when review-code's R4 round 1 calls for it, or the user explicitly asks for an adversarial review of a diff. Never for R2/R3 or a round 2+.
---

# Adversarial Review

An R4 (high-risk) diff's round 1 → one adversarial report beside `security-engineer` and the two standard lenses.

## Skip when

- R1 (trivial edit), R2 (one file + test), R3 (multi-file) — `review-code`'s standard review covers them.
- Round 2+ — a fix delta gets `review-code`'s internal re-check (Fix-verify rounds), never this pass.
- An R4 comment/blank-only diff — ONE internal strong reviewer, no adversarial pass.
- The commit gate — it asks for no pass of its own: the round-1 external counts whatever its verdict, and a REJECTED external is never re-run for an APPROVED. Evidence missing because the diff moved as a patch → commit in the owner's worktree (`implement-plan`), never a new pass.

### 1. Run the pass

- Run it with the rest of round 1 (`review-code` Pick reviewers): `security-engineer` · `universal-reviewer` `lens: spec` · `universal-reviewer` `lens: standards` · this pass. The internal pass goes in the SAME message; the external's `--detach` runs just before that message — it returns at once — so the external runs while the internal reviewers do.
- A usable pool → the external is the only adversarial pass: no internal `mode: adversarial` beside it (the internal pass stands in only under What counts below). The `cross-family` skill's runner, `<cross-family skill folder>/scripts/cross-family.sh` (that folder sits beside this skill's): `--kind review --adversarial --brief <brief> --attach <diff> --detach`, then ONE `--collect <job-id>`; its report joins round 1 with the other reports. The runner hands the member this skill's Reviewer stance.
- Pool off, no usable member, no `cross-family`, or the runner refuses `--adversarial` (exit 2: the stance is missing beside it) → `universal-reviewer` with `mode: adversarial` on a strong-class model — never a balanced one, even under a balanced Lead. It writes `.rolepod/evidence/review/<task>-adversarial.md`.
- The brief is the reviewer's whole world: the diff, the spec / acceptance criteria, the risk profile, the claimed behaviors to trace.
- Called alone (the user asked; no `review-code` round) → freeze the diff first — each ref resolves and the diff is non-empty — then run the pass as above.

Done when: the adversarial report is back in full — never partial — and sits in the round with the other reports.

### 2. What counts

- The external runs in a CLI different from the Lead's, on that CLI's own default model (the same vendor is fine).
- The internal strong pass stands in when (a) cross-family is off, the runner reports no usable member (every member failed / pool empty — logged) or refuses `--adversarial`; (b) the external came back weak — an empty or partial return (a changed file missing from its Scope list counts), a bare verdict, or no claims walked. Record why.
- The vertical fallback (same CLI, stronger tier) and an inline advisor never satisfy this pass; each only raises the Lead floor, recorded as a LIMITATION.
- The author's own model is never the final adversarial reviewer, and the Lead's own walk is never this pass. Only when no dispatch is possible at all (the user forbade agents, no subagent support) does the Lead's cold self-review stand in — a LIMITATION that blocks the merge until the user waives it (`finish-work` Reviewer gate).
- The review report's **Cross-model adversarial pass** line: `ran on <cli>` (a `ROLEPOD-XFAM ok` receipt) · `NOT RUN — cross-family off (opt-in)` (the user's choice — a note, not a limitation) · `NOT RUN — <reason>` (the internal strong pass ran) · `vertical — same CLI, <reason>`.

Done when: the pass that ran is one of the above and the Cross-model line names it.

### 3. Apex escalation

Strong is the default: "done right per the existing pattern?". Apex — the strongest model the CLI exposes — asks "is the pattern itself right?". Escalate only on:
1. irreversible with no rollback — destructive migration, key rotation, live money movement;
2. novel design with no pattern to diff against;
3. deep cross-system reasoning — races on financial invariants, distributed consistency;
4. the user asks.

- No trigger → strong stands. A CLI whose strong pin IS its ceiling collapses apex into strong.
- A costlier rung is a cost decision: surface it first. A ceiling below frontier class still gets the full review; record the depth cap as a LIMITATION.
- The dispatch line's `override` records the rung sent.

Done when: the rung is strong, or apex with its trigger named.

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

## Report

- The internal reviewer fills `review-code`'s report template (through the Skill tool) into `.rolepod/evidence/review/<task>-adversarial.md`: Scope (every changed file, read or skipped with its reason), Read (each claim walked and where it held or failed), Findings (BLOCKER / MAJOR / MINOR at file:line, each with the axis it lands on), Recommendation. No Skill tool → those four sections.
- At most 40 tool calls; past it → return what you have, marked PARTIAL. Reply ≤ 12 lines + verdict; the report file holds the rest.
- An external member's output shape is the runner's contract: severity-ordered findings, the Scope list, the `VERDICT:` line.

## Next phase

- Back to `review-code` One review round: the findings merge with the other reports; round 2+ follows `review-code` Fix-verify rounds, never this pass.
- Called alone → the report goes to the user; fixes go to `implement-plan` or `debug-issue`.
