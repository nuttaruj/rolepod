---
name: debugging-and-error-recovery
description: Compatibility shim — bug / failure / root-cause work is now handled by `debug-issue`.
when_to_use: when an error appears, when output is wrong, or when something worked before and stopped
tier: 3
redirect_to: debug-issue
---

# debugging-and-error-recovery

Compatibility shim. The debug workflow now lives in **`debug-issue`**.

→ Open `core/skills/debug-issue/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `debug-issue` is not available

Minimum viable fallback:

1. Capture the exact error message, stack, and throw site
2. Reproduce deterministically before any fix attempt
3. State one hypothesis at a time; pick the cheapest falsifier
4. Do not spray fixes — one hypothesis, one test
5. Trace upstream until you hit external input / system boundary / designed-this-way
6. Write the failing test before shipping the fix
7. Verify regression-clean after the fix
