---
name: anti-spaghetti
description: Compatibility shim — duplication / dead code / drift / dependency-flow hygiene now lives in `simplify-code`.
when_to_use: when adding new logic, when a pattern starts repeating, or when a module imports from where it shouldn't
tier: 3
redirect_to: simplify-code
---

# anti-spaghetti

Compatibility shim. Code-rot prevention now lives in **`simplify-code`**.

→ Open `core/skills/simplify-code/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `simplify-code` is not available

Minimum viable fallback:

1. Duplication: same logic in 3+ places → centralize. Two is a coincidence, three is a pattern
2. Auth / billing / credit / URL validation / redirects / SSRF / cookies / logging / retries / external API: centralize on appearance, not at 3
3. Dead code: remove what YOUR change orphaned; mention pre-existing dead code, do not delete without asking
4. Drift: BE model + FE type + tests must stay in sync; codegen or contract test
5. Dependency flow: features import shared, NOT reverse; no circular imports
6. Separate presentation from logic; keep business rules out of view code
7. No new dependency without justification (maintained, sized, license-compatible, not already in stdlib)
