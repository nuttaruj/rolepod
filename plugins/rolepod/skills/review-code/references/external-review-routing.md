<!-- Load on a high-risk diff (adversarial pass), the cross-family pool enabled at any tier, or an internal pass, apex or strong-class question. -->
<!-- review-code's Pick reviewers carries the trigger; this file is the review rules. Running the external is the `cross-family` skill. -->

# External review routing

The adversarial review pass routes to a **different CLI** than the Lead's, never to the Lead's own; the model family is information, not a filter.

## When the external runs

- **The pool is the user's choice, and it is opt-in** (`.rolepod/cross-family`, then `~/.rolepod/cross-family`; no file or `none` = off). Never turn it on unasked.
- **Mandatory at the pool's tier.** Pool enabled + a logic-bearing code diff at the pool's tier (R4 unless the pool file sets `tier = R2|R3`) + a usable member → the strong pass is the external. Below that tier, and any doc / comment / config / rename-only diff, stay internal unless the user asks.
- **The external IS the strong pass.** From the pool's tier up it replaces `universal-reviewer`, never both on round 1 (the user asks → one pass).
- **Run it:** pool on → `cross-family` kind review (`security-engineer` in the same message). Pool off, no usable member, or `cross-family` absent → `universal-reviewer` on a strong-class model, and the report's Cross-model line records why.
- **An externally implemented ship group** is reviewed by a DIFFERENT member. A user-lifted risky scope (`risky:lifted`) → the external pass by a different member.
- **Money / auth** — billing · payments · credits · auth · crypto · secrets · data deletion: `security-engineer` + ONE general strong pass (the external when the pool is usable, else `universal-reviewer`). Never external + `universal-reviewer` on round 1. Commit only after one strong pass has finished (the anchored external, or an internal strong pass).
- While the pool is usable, an internal strong reviewer does not replace the external on a high-risk diff — only after the runner reports no usable member.

## When the internal general pass runs

`universal-reviewer` runs as the general strong pass when any of these holds:
- (a) cross-family is off, or the runner reports no usable member (every member failed / pool empty — logged);
- (b) the review-code Breaker fired — its one round goes to the internal strong reviewer (`breaker.md`);
- (c) the external came back weak — empty / partial return (a changed file missing from its Scope list counts), bare verdict, or no claims walked; record why;
- (d) an apex trigger holds (below) — external first, internal when (c);
- (e) re-reading a fix delta in the fix-verify rounds.

**Strong class.** Dispatch the internal general pass on a strong-class model, even under a balanced Lead — never a balanced model. An external runs on its own CLI's default model. `qa-tester` (E2E / UI) is never the strong pass and never counts as one.

## Adversarial mode — what counts as the adversarial pass

For a high-risk diff, a fresh-context reviewer reads only the artifact + acceptance criteria, tries to make the change fail, and hunts what is missing as hard as what is present. The author's own model is never the final adversarial reviewer.

Done when: the adversarial reviewer has returned a full report. Only when no dispatch is possible at all (the user forbade agents / no subagent support) does the Lead's cold self-review stand in, recorded as a LIMITATION.

- The external adversarial pass runs in a CLI different from the Lead's, on that CLI's own default model (same vendor is fine).
- The vertical fallback (same CLI, stronger tier) and an inline advisor never satisfy it; both only raise the Lead floor, recorded as a LIMITATION.

## Apex escalation

Strong is the R4 default: "done right per the existing pattern?". Apex — the strongest model the CLI exposes — asks "is the pattern itself right?". Escalate only on:
1. irreversible with no rollback — destructive migration, key rotation, live money movement;
2. novel design with no pattern to diff against;
3. deep cross-system reasoning — races on financial invariants, distributed consistency;
4. the previous strong round missed blockers;
5. the user asks.

- No trigger → strong stands.
- A CLI whose strong pin IS its ceiling collapses apex into strong.
- A costlier rung is a cost decision: surface it first.
- A ceiling below frontier class still gets the full review; record the depth cap as a LIMITATION.
- The dispatch line's `override` records the rung sent.

## The Lead floor — covers every axis

The Lead floor is `universal-reviewer` (a read-only fresh-context subagent). When no reviewer can run (missing / failed / empty), the Lead's multi-axis read covers every axis — correctness, security, breadth, architecture, perf, UI — recorded as a LIMITATION.

Strength routing is an optimisation on top of the floor: it assigns a specialist to an axis when one is available; it never removes an axis. A specialist that is missing, is the Lead's own CLI, or has failed → that axis falls back to the floor.

On a high-risk surface with no usable cross-family member, the floor (plus the vertical fallback) still reviews every axis — but the review report's **Cross-model adversarial pass** line must record NOT RUN and why, and `finish-work`'s Reviewer gate surfaces that limitation before merge. It is a real verification limitation, not a pass. Cross-family off is a choice: the line reads `NOT RUN — cross-family off (opt-in)`, never a nag.

This never widens WHO reviews: the pool reviews code at its tier (R4, or lower only when the pool file sets `tier = R2|R3`); below it stays internal.
