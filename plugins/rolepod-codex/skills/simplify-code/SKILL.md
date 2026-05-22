---
name: simplify-code
description: Use when code feels over-engineered, rotted, or duplicated — cut unused abstraction, inline single-use helpers, centralize patterns repeated in 3+ places, prefer structural impossibility over defensive clutter. Behavior-preserving. Phase = Simplify.
when_to_use: when reviewing existing code that looks bloated, when a refactor request lands, when the same pattern shows up in 3+ places, or when a single-use abstraction is adding cost without payoff
tier: 1
phase: simplify
---

# Simplify Code

Recovery-phase skill. Cut complexity that does not earn its keep. Behavior-preserving — every change is provable by the existing tests.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER simplify without a test suite that proves behavior before and after.
2. NEVER remove an abstraction the codebase actually depends on — verify call sites first.
3. NEVER add a new abstraction for "hypothetical future use". One concrete user is not enough.
4. Same pattern in 3+ places → centralize. "Just this one place" is the start of rot for auth, billing, credits, URL validation, redirects, SSRF, cookies, logging, retries, external API.
</EXTREMELY-IMPORTANT>

## When to use

- Code reviewer flagged over-engineering or duplication
- A file is > 500 lines and looks like it grew by accretion
- An abstraction has exactly one caller
- A defensive null-check / try-catch covers an "impossible" case
- Same logic copy-pasted in 3+ files
- User says "this is getting messy" or "refactor X"

Skip when:
- Tests don't exist for the touched code — write them first via `implement-plan` or `debug-issue`
- The "complexity" is load-bearing (security boundary, data invariant)
- It is mid-feature; finish the feature first

## Boundary

Owns:
- Behavior-preserving complexity cuts: inline single-use helpers, delete unused config, centralize repeated patterns, structural simplification.

Does not own:
- Feature changes.
- Bug fixes with unknown root cause.
- Refactors without a test baseline.
- Product / API behavior changes.

Return / hand off:
- Behavior must change → `write-spec` or `write-plan`.
- Tests missing for a risky area → `implement-plan` to add baseline tests.
- Bug found while simplifying → `debug-issue`.
- Simplification complete → `check-work`.

## Inputs to gather

- The code region or file(s) flagged as complex
- The existing tests for that region (must be green before starting)
- Call sites for any abstraction you plan to inline or remove
- The user's intent (cleanup only, or cleanup + behavior change)

## Workflow

### 1. Confirm tests are green

Run the touched module's test suite. If red, fix or write tests first. You cannot prove behavior-preserving without a baseline.

### 2. Scan for these patterns

Before removing anything, `git blame` the origin commit — code with no callers may still encode a reason (Chesterton's Fence). Verify the why, not just the call sites.

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

### 3. Prefer structural over runtime

A runtime `if (x === null) throw` becomes a non-nullable type. A "must be set" config becomes a required constructor argument. Make the bad state un-representable when the type system allows.

### 4. Centralize at 3 occurrences

Two is a coincidence. Three is a pattern. For auth / billing / credit / URL validation / redirects / SSRF / cookies / logging / retries / external API, two is already too many — centralize on appearance.

### 5. One change at a time

One cut per commit. Run the test suite between cuts. A failing test mid-simplification tells you the previous cut went too far — revert that one, not all of them.

### 6. Stop when behavior is at risk

If a cut requires changing a test assertion to keep it green, you are no longer behavior-preserving. Stop, ask the user, or move the cut to a separate `implement-plan` task with a real spec.

## If a matching Rolepod agent is available

Delegate to the closest specialist:

- `universal-reviewer` for DRY / smell / structure cleanup
- `system-architect` when the cut touches module boundaries or APIs
- `security-engineer` when the cut touches auth / secret / token / crypto code paths

Brief: the file region, the existing tests, the user intent (cleanup vs cleanup + behavior).

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Run the module's test suite — must be green
2. List the over-engineering patterns present in the file
3. Pick the smallest single cut
4. Apply it
5. Run the test suite — must stay green
6. Commit (or stage); repeat with the next smallest cut
7. Stop when further cuts would change behavior or break tests
8. Centralize anything that appears in 3+ files into one source of truth

## Output

The simplification report is the canonical artifact: `templates/simplification-report.md`. It carries the green baseline, each cut, anything centralized, the post-cut tests, and the behavior-preserved verdict. Do not restate the report shape here; the template is the single source.

## Examples

Non-blocking — read only when unsure whether a cut is behavior-preserving:
- `examples/simplify-examples.md` — a single-use-helper inline and a defensive-check cut, each a good/bad pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## Hard stops

- Tests were not green at the start → write tests first, do not simplify on a red baseline
- A cut required a test assertion change → that is a behavior change, route to `implement-plan`
- An "unused" abstraction has callers you missed → restore it and verify before another attempt
- About to invent a new abstraction for one caller → reject; that is complexity, not simplification

## Full Rolepod enhancement

Full Rolepod improves this phase by adding the simplicity gate S1-S5 in pre-commit hooks, `universal-reviewer` adversarial pressure on DRY violations, and the centralization rule enforced for auth / billing / credit / URL validation paths.

## Next phase

- If the cleanup is part of a larger plan, return to `implement-plan` for the next planned task.
- If the cleanup uncovered a real bug, route to `debug-issue`.
- If the cleanup is complete, route to `check-work` for the verification block, then `finish-work`.
