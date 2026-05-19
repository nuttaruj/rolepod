---
name: reviewer-flow
description: Compatibility shim — reviewer routing across qa-tester, security-engineer, universal-reviewer, Codex, and Gemini now lives in `review-code`.
when_to_use: 'when spawning a reviewer, "code review cascade", "adversarial review", "Codex review", "Gemini review", high-risk surface review'
tier: 3
redirect_to: review-code
---

# reviewer-flow

Compatibility shim. Reviewer selection now lives inside **`review-code`**.

→ Open `core/skills/review-code/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `review-code` is not available

Minimum viable fallback:

1. Pick reviewer by risk: qa-tester is the universal floor
2. High-risk surface (auth / billing / migration / secret) → add security-engineer + adversarial fresh-context
3. External reviewer CLIs: Codex for correctness + security adversarial, Gemini for breadth + cross-file
4. qa-tester is the fallback when an external reviewer fails or is unavailable
5. The author of a change cannot be the final reviewer of that change
6. Two-stage pattern for delegated work: implementer subagent → fresh reviewer subagent
7. Reviewer flags issue; qa-tester / Lead confirms the fix, not the original flagger
