---
name: simplify-code
description: Use when code feels over-engineered, rotted, or duplicated — cut unused abstraction, inline single-use helpers, centralize patterns repeated in 3+ places, prefer structural impossibility over defensive clutter. Behavior-preserving. Phase = Simplify.
when_to_use: when reviewing existing code that looks bloated, when a refactor request lands, when the same pattern shows up in 3+ places, or when a single-use abstraction is adding cost without payoff
---

# Simplify Code

Turns code that does not earn its complexity into less code with the same behavior, each cut proven by the existing tests. Runs mid-Build (refactor intent) or standalone.

## Skip when

- No tests cover the touched code → write them first via `implement-plan` (baseline tests) or `debug-issue`.
- The complexity is load-bearing (a security boundary, a data invariant).
- Mid-feature and the cut is not needed to unblock the change. A required prefactor is not a skip (step 6).
- The behavior itself must change → `write-spec` or `write-plan`.

**Who runs the cuts.** The Lead routes, briefs, spot-checks and commits; the role that owns the path (`backend-developer` / `frontend-developer` / …) runs this skill's steps from the brief. Brief: the file region, the existing tests and their suite command, the user's intent (cleanup only, or cleanup + behavior change).
- Cuts touching module boundaries or APIs → the owner returns `BLOCKED:` for a `system-architect` decision, and cuts after it.
- Auth / secret / token / crypto paths → `security-engineer` reviews the cut diff.
- DRY / smell / structure cleanup → `universal-reviewer` reviews the cut diff as usual.

No subagents → the Lead does it.

### 1. Green baseline

Run the touched module's suite. Red → fix it or write tests first; without a green baseline nothing is provably behavior-preserving.
An earlier green run counts only when the command AND the pre-cut snapshot match — staged and unstaged changes and every input the tests read, not just the same HEAD; anything differs → run it again.
Gather: the flagged region, its tests, the call sites of anything you plan to inline or remove, and the user's intent.

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
- Two commits: the cleanup commit is behavior-preserving (this skill); the change commit is the feature (`implement-plan`). Mixing them hides which line caused which regression; split them.
- No friction you can name at a `path:line`, or the change goes in directly → skip this step; never invent friction.

Done when: the friction is named (or the step skipped), the cleanup commit holds no behavior change, and the feature change sits in its own commit.

### 7. One cut at a time

- After each cut, run the narrowest check that covers it (the touched file's tests). The Baseline suite runs once more, after the last cut, as Tests after.
- A red check right after a cut means that cut went too far: revert that one, not all.
- An "unused" abstraction turns out to have callers you missed → restore it, verify, then retry once through step 3; callers remain → keep it, with the reason in the report.
- A delegated subagent returns the diff + proof; the Lead commits the cleanup as one commit, apart from any feature commit (step 6, `implement-plan`).

Done when: every cut passed its narrow check before the next began, and the Baseline suite is green once after the last cut.

### 8. Stop when behavior is at risk

A cut that changes what a test ASSERTS → check what the assertion proved.
- The expected VALUE changes → no longer behavior-preserving: ask the user, or move it to an `implement-plan` task with a spec.
- An assertion moved off a private detail or a mock's call shape onto the same observable output, expected value unchanged, is still behavior-preserving.

Artifact: `templates/simplification-report.md` — Baseline, Cuts made, Patterns centralized, Tests after, Behavior preserved.

Done when: Tests after is green with the same expected values and Behavior preserved reads YES, or the change is routed out.

## Guardrails

- Prove behavior with the same tests, green after the change with no expected value or contract changed; an assertion moved off a private detail onto the same observable output is allowed (step 8). A failure → run those tests on the tree without the change to tell a pre-existing red. Never simplify without that suite.
- Keep an abstraction the codebase depends on. Never remove one before its call sites and the deletion test say it is safe.
- Add an abstraction only for concrete users that exist today (3+ for a shared rule, 2 on the high-risk list). Never for "hypothetical future use"; one caller is not enough.

Single-use-helper and defensive-check pairs → `examples/simplify-examples.md`.

## Next phase

- Part of a larger plan → `implement-plan`, next task. Uncovered a real bug → `debug-issue`. If neither is available, the runner (the Lead without sub-agents) fixes the bug at its root with a failing test first (→ `tdd-flow`), then re-runs this skill's suite.
- Cleanup complete → `check-work`, then `finish-work`; if neither is available, attach the report and ask the user whether to ship.
