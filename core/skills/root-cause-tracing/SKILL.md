---
name: root-cause-tracing
description: Compatibility shim — upstream-tracing is now part of `debug-issue` (step 5 — trace upstream).
when_to_use: when a stack trace points at a display / boundary / late-stage symptom (e.g. null pointer in the render layer, but the null was produced three layers up at DB read time), when the same bug keeps recurring with different surfaces, or when a "fix" makes the original error go away but a similar one appears nearby
tier: 3
redirect_to: debug-issue
---

# root-cause-tracing

Compatibility shim. Upstream tracing now lives inside **`debug-issue`** (the trace-upstream step).

→ Open `core/skills/debug-issue/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `debug-issue` is not available

Minimum viable fallback:

1. Symptom → caller → caller's caller, until a legitimate stop
2. Three legitimate stopping points: external input, system boundary, "designed this way"
3. Do not stop at the first place the value looks wrong
4. Recurring symptom at a different surface = root not yet found
5. Defensive null-check without a known cause is not a fix
6. State the root cause as: file:line + upstream condition
7. Pair with `gitnexus_impact` (upstream direction) when the plugin is installed
