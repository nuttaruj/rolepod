---
name: documentation-and-adrs
description: Compatibility shim — durable technical docs and ADR production now flow through `implement-plan` with the `tech-writer` agent adding depth when available.
when_to_use: when capturing why a choice was made, documenting a public API, writing a runbook, or recording context that future readers will need
tier: 3
redirect_to: implement-plan
---

# documentation-and-adrs

Compatibility shim. Technical doc / ADR production now lives in **`implement-plan`**; the `tech-writer` agent adds depth when installed. Spec shaping for the document itself still starts in `write-spec`.

→ Open `core/skills/implement-plan/SKILL.md` and follow that instead. Brief `tech-writer` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. ADR format: Context (what triggered the decision) → Decision (what we picked) → Consequences (good / bad / open)
2. Public API doc: signature + one runnable example + error cases
3. Runbook: trigger → diagnostic steps → fix steps → verify → escalate path
4. Date + author + status (proposed / accepted / superseded)
5. Link to the related code / PR / issue
6. One page per decision; do not bundle multiple ADRs together
7. Keep it under 2 pages — long ADRs do not get read
