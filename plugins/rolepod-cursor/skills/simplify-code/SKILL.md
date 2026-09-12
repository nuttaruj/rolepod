---
name: simplify-code
description: Use when code feels over-engineered, rotted, or duplicated — cut unused abstraction, inline single-use helpers, centralize patterns repeated in 3+ places, prefer structural impossibility over defensive clutter. Behavior-preserving. Phase = Simplify.
---

# Simplify Code

Cut complexity that does not earn its keep. Behavior-preserving: every cut is provable by the existing tests. Usable mid-Build (refactor intent) or standalone.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER simplify without a test suite that proves behavior before and after.
2. NEVER remove an abstraction the codebase depends on — verify call sites first.
3. NEVER add an abstraction for "hypothetical future use". One concrete user is not enough.
4. Same pattern in 3+ places enforcing the SAME rule (one invariant, one lifecycle) → centralize; text that only reads alike under a different contract stays separate. On the high-risk list — auth, billing, credits, URL validation, redirects, SSRF, cookies, logging, retries, external API — TWO occurrences already force it.
5. Deletion test before any cut: imagine deleting the module. Complexity vanishes → it was a pass-through, delete it. Complexity reappears scattered across N callers → it earned its keep, keep it.
</EXTREMELY-IMPORTANT>

## When to use

- A reviewer flagged over-engineering or duplication · a file >500 lines grew by accretion · an abstraction has one caller · a defensive check covers an "impossible" case · the same logic sits in 3+ files · the user says "messy" / "refactor X" · `rolepod-debt:` markers in the touched area (§2).

Skip when:
- No tests cover the touched code → write them first via `implement-plan` or `debug-issue`.
- The complexity is load-bearing (security boundary, data invariant).
- Mid-feature and the cut is not needed to unblock the change — a required prefactor is not a skip (§4b).

## Boundary

Owns: behavior-preserving cuts — inline single-use helpers, delete unused config, centralize repeated patterns, structural simplification.

Does not own: feature changes · bug fixes with unknown root cause · refactors without a test baseline · product / API behavior changes.

Hand off:
- Behavior must change → `write-spec` or `write-plan`.
- Tests missing for a risky area → `implement-plan` (baseline tests first).
- Bug found while simplifying → `debug-issue`.
- Cuts complete → `check-work`.

## Workflow

### 1. Green baseline

Run the touched module's suite. Red → fix or write tests first; without a baseline nothing is provably behavior-preserving. Gather: the flagged region, its tests, call sites of anything you plan to inline or remove, the user's intent (cleanup only, or cleanup + behavior change).

### 2. Scan for these patterns

Before removing anything run Chesterton's Fence + the deletion test (Iron Rule 5) together: `git blame` the origin commit — code with no callers may still encode a reason. Verify the WHY, not just the call sites. Both pass → safe to delete; either fails → stop.

| Pattern | Action |
|---------|--------|
| Interface / type with one implementation | Inline the impl, delete the interface |
| Config flag with one value used in code | Delete the flag |
| Helper / wrapper with one caller | Inline at the call site |
| Retry / timeout config without observed failure | Delete; add back when a real failure appears |
| Defensive null check on a value that cannot be null structurally | Tighten the type, delete the check |
| Same 5-line pattern in 3+ files | Extract to one source of truth |
| Backwards-compat shim for code nobody calls | Delete the shim |
| Comment that restates what the code does | Delete the comment |
| Wrapper that only forwards calls (delete it → complexity vanishes) | Inline; a pure pass-through earns nothing |

**Debt markers.** A deliberate simplification with a KNOWN ceiling (global lock, O(n²) scan, naive heuristic) leaves one greppable comment: `rolepod-debt: <what>. ceiling: <limit>. upgrade when: <trigger>`. `grep 'rolepod-debt:'` lists the ledger; a marker naming no upgrade trigger is rot — fix the marker or do the upgrade. Exempt from the "comment restates code" row.

### 3. Structural over runtime

A runtime `if (x === null) throw` becomes a non-nullable type; a "must be set" config becomes a required constructor argument. Make the bad state un-representable where the type system allows. A type proves what your own code produces, not what arrived — JSON / network / config / DB values still need a check at the boundary where they enter.

### 4. Centralize at 3 occurrences

Two is a coincidence, three is a pattern. On Iron Rule 4's high-risk list, two already force it.

Inverse rule: one adapter behind an interface = hypothetical seam, inline it; two real adapters = real seam, keep the interface. Counts decide structure.

### 4b. Refactor before fix

A planned change is hard because the surrounding shape is wrong → first cut the shape until the change is easy, then make the easy change. Two commits: cut commits are behavior-preserving (this skill); the change commit is the feature (`implement-plan`). Mixing them hides which line caused which regression. Skip when the change is small and the shape is fine — never invent friction.

### 5. One cut per commit

Run the suite between cuts. A delegated subagent stages and returns diff + proof; the Lead commits (`implement-plan`). A failing test mid-simplification means the previous cut went too far — revert that one, not all.

### 6. Stop when behavior is at risk

A cut that changes what a test ASSERTS → check what the assertion proved. The expected VALUE changes → no longer behavior-preserving: ask the user, or move it to an `implement-plan` task with a spec. A retarget onto the same observable output (a private detail, a mock's call shape) is still behavior-preserving.

## If a matching Rolepod agent is available

- `universal-reviewer` — DRY / smell / structure cleanup
- `system-architect` — cuts touching module boundaries or APIs
- `security-engineer` — cuts touching auth / secret / token / crypto paths

Brief: the file region, the existing tests, the user intent (cleanup vs cleanup + behavior).

## If no matching agent is available

Execute as Lead: §1 green baseline → §2 smallest single cut → suite green → commit or stage → repeat. Stop when a cut would change behavior; centralize anything in 3+ files.

## Output

The simplification report is the canonical artifact: `templates/simplification-report.md` — green baseline, each cut, anything centralized, post-cut tests, the behavior-preserved verdict.

## References

Load only when needed:
- `examples/simplify-examples.md` — a single-use-helper inline and a defensive-check cut, good/bad pairs; read when unsure whether a cut is behavior-preserving.

## Hard stops

- Tests not green at the start → write tests first.
- A cut changed a test's expected VALUE → behavior change, route to `implement-plan`.
- An "unused" abstraction has callers you missed → restore, verify, then retry.
- About to add an abstraction for one caller → reject.
- About to delete a module without the deletion test → stop; Iron Rule 5.
- Refactor-before-fix commits mixed with the feature change → split.

## Next phase

- Part of a larger plan → `implement-plan`, next task. Uncovered a real bug → `debug-issue`.
- Cleanup complete → `check-work`, then `finish-work`; if neither is available, attach the report and ask the user whether to ship.
