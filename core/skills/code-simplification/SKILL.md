---
name: code-simplification
description: Compatibility shim — behavior-preserving simplification now lives in `simplify-code`.
when_to_use: when code works but is hard to read, when nesting is deep, when a function is doing too much, or when the design fights you on every change
tier: 3
redirect_to: simplify-code
---

# code-simplification

Compatibility shim. Simplification now lives in **`simplify-code`**.

→ Open `core/skills/simplify-code/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `simplify-code` is not available

Minimum viable fallback:

1. Run the touched module's tests first — must be green before any cut
2. Inline interfaces / wrappers / helpers with one caller
3. Cut config flags with one value, retry configs without observed failure
4. Centralize patterns repeated in 3+ places (one source of truth)
5. Prefer structural impossibility (types) over runtime defensive code
6. One cut per commit; run tests between cuts
7. Stop if a cut requires a test assertion change — that is a behavior change
