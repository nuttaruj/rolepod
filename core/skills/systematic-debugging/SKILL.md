---
name: systematic-debugging
description: Compatibility shim — the canonical bug / failure / root-cause workflow is now `debug-issue`.
when_to_use: when an error appears, a test fails, a build breaks, output is wrong, something worked before and stopped, the same bug keeps recurring with different surfaces, or a fix made one error go away and a similar one appeared nearby
tier: 3
redirect_to: debug-issue
---

# systematic-debugging

Compatibility shim. The debug workflow now lives in **`debug-issue`**.

→ Open `core/skills/debug-issue/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `debug-issue` is not available

Minimum viable fallback:

1. Capture the exact error, stack, and throw site (file:line)
2. Reproduce with one deterministic command — no repro means no fix
3. Rollback the last change first if the bug appeared right after your edit
4. One hypothesis at a time, cheapest falsifier first
5. Trace upstream to a legitimate stopping point: external input / system boundary / "designed this way"
6. Write the failing test you wish had existed
7. Smallest fix that turns the test green; run the full module suite to confirm no regression
8. Tighten the assertion until a 1-character regression breaks the test
