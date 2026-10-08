---
name: simplify-code
description: The owner's cleanup procedure. Use when code looks bloated, over-engineered or rotted; a refactor is asked; a pattern repeats in 3+ places; a helper or abstraction has one use.
---

# Simplify Code

Turns code that does not earn its complexity into less code with the same behavior, each cut proven by the existing tests. Phase = Build (refactor): runs mid-Build or standalone.
Run alone (no caller) → stop and tell the user instead.

## Skip when

- No tests cover the touched code → write characterization tests at the public interface that pin today's output, then resume at step 1 with them as the Baseline; the cleanup is still owed.
- The complexity is load-bearing (a security boundary, a data invariant).
- Mid-feature and the cut is not needed to unblock the change. A required prefactor is not a skip (step 6).
- The behavior itself must change → return `BLOCKED` to your caller naming the behavior change.
- A module-boundary or API cut → return `BLOCKED` to your caller naming the cut; never ask the user.

### 1. Green baseline

Run the touched module's suite. Red → fix it or write tests first; without a green baseline nothing is provably behavior-preserving.
An earlier green run counts only under `implement-plan`'s Prove rule (scope, relevant inputs, environment and provenance still match); no `implement-plan` → only when the command AND the pre-cut snapshot match (staged and unstaged changes and every input the tests read, not just the same HEAD), else run it again.
Gather: the flagged region, its tests, the call sites of anything you plan to inline or remove, and the brief's intent.

Done when: the suite is green and recorded as the Baseline.

### 2. Scan for these patterns

| Pattern | Action |
|---------|--------|
| Interface / type with one implementation | Inline the impl, delete the interface |
| Shallow module (interface as wide as what it hides) | Inline; extract only when the interface is smaller than the behavior behind it |
| Config flag with one value used in code | Delete the flag |
| Helper / wrapper with one caller | Inline at the call site |
| Retry / timeout config without observed failure | Delete; add back when a real failure appears |
| Defensive null check on a value that cannot be null structurally | Tighten the type, delete the check |
| Same 5-line pattern in 3+ files | Extract to one source of truth |
| Backwards-compat shim for code nobody calls | Delete the shim |
| Comment that restates what the code does | Delete the comment |
| Wrapper that only forwards calls (delete it → complexity vanishes) | Inline; a pure pass-through earns nothing |

Other red flags: a plugin point with no plugin · a split of a file under 500 lines · "might need later" · "best practice" · "already started". None proves the code is needed → propose the cut; step 3 decides.

**Debt markers.** A deliberate simplification with a KNOWN ceiling (global lock, O(n²) scan, naive heuristic) leaves one greppable comment: `rolepod-debt: <what>. ceiling: <limit>. upgrade when: <trigger>`.
- `grep 'rolepod-debt:'` lists the ledger.
- A marker naming no upgrade trigger is rot: fix the marker or do the upgrade.
- Markers are exempt from the "comment restates code" row.

Done when: every match in the region has a proposed action, or is left with a reason.

### 3. Check the fence before any cut

For each cut the scan proposes, before removing anything:
- Call sites: an abstraction the codebase depends on stays. Verify every caller.
- Chesterton's Fence: `git blame` the origin commit. Code with no callers may still encode a reason; verify the WHY, not just the call sites.
- Deletion test: imagine deleting the module. Complexity vanishes → it was a pass-through; delete it. Complexity reappears scattered across N callers → it earned its keep; keep it.

Both the fence and the deletion test pass → safe to cut. Either fails → stop.

Done when: every proposed cut has its callers listed and passes both checks.

### 4. Structural over runtime

Make the bad state un-representable where the type system allows: a runtime `if (x === null) throw` becomes a non-nullable type; a "must be set" config becomes a required constructor argument.
A type proves what your own code produces, not what arrived. JSON / network / config / DB values still need a check at the boundary where they enter.

Done when: each removed runtime check is replaced by a type or kept at an entry boundary.

### 5. Centralize at 3 occurrences

- The same pattern in 3+ places enforcing the SAME rule (one invariant, one lifecycle) → centralize. Two is a coincidence, three is a pattern.
- Text that only reads alike under a different contract stays separate.
- On the high-risk list — auth, billing, credits, URL validation, redirects, SSRF, cookies, logging, retries, external API — TWO occurrences already force it.
- Inverse rule: one adapter behind an interface is a hypothetical seam; inline it. Two real adapters are a real seam; keep the interface. Counts decide structure.

Done when: every repeated rule has one home, recorded under Patterns centralized.

### 6. Refactor before fix

A planned change is hard because of the current shape → name the friction first: the `path:line` that forces the change to edit N places, copy a rule, or reach past a seam. Then cut that shape until the change is easy, and make the easy change.
- The cleanup diff holds no behavior change and returns apart from the feature change; the Lead commits.
- No friction you can name at a `path:line`, or the change goes in directly → skip this step; never invent friction.

Done when: the friction is named (or the step skipped) and the cleanup diff holds no behavior change.

### 7. One cut at a time

- Checks per cut follow `implement-plan`'s Prove; no `implement-plan` → the touched file's tests after each cut. The Baseline suite runs once more, after the last cut, as Tests after.
- A red check right after a cut means that cut went too far: revert that one, not all.
- An "unused" abstraction turns out to have callers you missed → restore it, verify, then retry once through step 3; callers remain → keep it, with the reason in the report.

Done when: every cut passed its narrow check before the next began, and the Baseline suite is green once after the last cut.

### 8. Stop when behavior is at risk

A cut that changes what a test ASSERTS → check what the assertion proved.
- The expected VALUE changes → no longer behavior-preserving: return `BLOCKED` to your caller naming the change.
- An assertion moved off a private detail or a mock's call shape onto the same observable output, expected value unchanged, is still behavior-preserving.

Artifact: `templates/simplification-report.md` — Baseline, Cuts made, Patterns centralized, Tests after, Behavior preserved; no template → those five headings in the report, a pre-existing red under Tests after as a limitation.

Done when: Tests after is green with the same expected values and Behavior preserved reads YES, or the change is routed out.

## Guardrails

- Prove behavior with the same tests, green after the change with no expected value or contract changed. Never simplify without that suite.
- A failure → run just those tests on the base tree, the tree without the cuts (`implement-plan`'s Prove): red there too = pre-existing, a limitation.

## Next phase

- Called from another skill → back to its next step with the Baseline and Tests after tails and the diff trimmed to the cuts. Uncovered a real bug → `debug-issue`.
- Called alone → `convening-code-review` on the cleanup diff, with the report.
- Not available → `review-code` on the diff.
- No other skill → stop and tell the user what was cut, the Baseline and Tests after tails, and what is still unverified or unreviewed.
