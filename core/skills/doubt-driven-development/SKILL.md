---
name: doubt-driven-development
description: Compatibility shim — adversarial fresh-context review now lives in `review-code` (used for high-risk surfaces and unverifiable claims).
when_to_use: irreversible operations (migrations, money, deploys), cross-module changes, or any unverifiable claim ("works correctly", "no edge cases")
tier: 3
redirect_to: review-code
---

# doubt-driven-development

Compatibility shim. Adversarial review now lives inside **`review-code`**.

→ Open `core/skills/review-code/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `review-code` is not available

Minimum viable fallback:

1. Fresh-context reviewer reads ONLY the artifact + the contract, never the author's reasoning
2. Try to make the change fail before approving it
3. Look for what is MISSING as hard as what is present
4. Phrase findings as doubts: "could this be wrong?" before "this is fine"
5. Bound the cycle: at most 3 rounds of doubt → fix → re-doubt
6. Irreversible operations (migration, money, deploy) → mandatory adversarial round
7. Adversarial reviewer is not the author's pair — must be a different agent or session
