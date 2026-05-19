---
name: post-change-verify
description: Compatibility shim — evidence-required-before-claiming-done now lives in `check-work`.
when_to_use: '"verify change", "evidence after edit", "verify build", "verify task done", "show test pass output"'
tier: 3
redirect_to: check-work
---

# post-change-verify

Compatibility shim. Evidence-based verification now lives in **`check-work`**.

→ Open `core/skills/check-work/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `check-work` is not available

Minimum viable fallback:

1. Pick the right evidence type for the change (test / build / typecheck / curl / log / screenshot / browser)
2. UI changes require a browser observation; "it compiled" is not enough
3. Run the test / build / curl and capture the relevant output lines
4. Mentally flip `==` to `!=` to catch weak assertions
5. If verification is impossible, state explicitly: what / why / risk / suggested check
6. Include the exact command + result summary in the final response
7. Never claim done with failing checks
