---
name: root-cause-tracing
description: Compatibility shim — upstream-tracing is now part of the canonical `systematic-debugging` skill (steps 6 + worked example). Use `systematic-debugging` directly.
when_to_use: when a stack trace points at a display / boundary / late-stage symptom (e.g. null pointer in the render layer, but the null was produced three layers up at DB read time), when the same bug keeps recurring with different surfaces, or when a "fix" makes the original error go away but a similar one appears nearby
---

# Compatibility shim

Upstream-tracing has been folded into **`systematic-debugging`** (Step 6 — *Trace upstream to root* — plus the worked example).

`systematic-debugging` covers:

- the three legitimate stopping points: external input / system boundary / "designed this way"
- "first plausible cause" anti-pattern + falsifier
- worked example (null at display layer → producer hook)
- pairs with `gitnexus-debugging` for graph-driven traces

→ Open `core/skills/systematic-debugging/SKILL.md` and follow that instead.

This shim exists so the older trigger phrases (symptom-far-from-cause, recurring-bug-different-surfaces, fix-moves-the-bug) still route to the canonical skill. The shim will be removed after a release once behavior tests confirm the route works without it.
