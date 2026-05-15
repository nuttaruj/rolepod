---
name: debugging-and-error-recovery
description: Compatibility shim — bug / failure / root-cause work is now handled by the canonical `systematic-debugging` skill. Use `systematic-debugging` directly for all debugging tasks.
when_to_use: when an error appears, when output is wrong, or when something worked before and stopped
---

# Compatibility shim

This skill has been merged into **`systematic-debugging`**.

`systematic-debugging` covers the full workflow:

- reproduce → trace upstream to root → write failing test → minimal fix → verify regression-clean
- the three legitimate stopping points (external input / system boundary / "designed this way")
- common error patterns + bisection tactics
- worked example

→ Open `core/skills/systematic-debugging/SKILL.md` and follow that instead.

This shim exists so older trigger phrases ("when an error appears", "output is wrong", "something worked before and stopped") still route to the canonical skill. The shim will be removed after a release once behavior tests confirm the route works without it.
