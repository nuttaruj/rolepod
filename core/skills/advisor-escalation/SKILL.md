---
name: advisor-escalation
description: Compatibility shim — Advisor (Opus) escalation pattern for stuck Sonnet / Haiku sessions now lives in `manage-context`.
when_to_use: '"stuck", "consult Opus", "advice mode", "/advice", third agent on same issue, 50k tokens no convergence, architecture decision needing 2nd opinion'
tier: 3
redirect_to: manage-context
---

# advisor-escalation

Compatibility shim. Advisor escalation now lives in **`manage-context`**.

→ Open `core/skills/manage-context/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `manage-context` is not available

Minimum viable fallback:

1. Trigger: 3 failed attempts at the same target, OR 50k+ tokens with no convergence, OR architecture decision needing a second opinion
2. Capture the exact problem (error, what was tried, what failed)
3. Ask the Advisor (Opus) for direction with that context, not the full history
4. Bring back the recommendation; do not blindly apply it
5. Do not "try one more thing" past 3 attempts
6. If still stuck after escalation, surface the blocker to the user with a concrete ask
7. Capture the final decision in MemPalace if it is non-obvious and will be re-asked
