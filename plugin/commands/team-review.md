---
description: Invoke Team-review phase — evidence → adversarial pass before ship
---

# Team Review Recipe

You are entering Team-review phase. Adversarial pass over verified code before shipping.

## Spawn via Task tool

1. `universal-reviewer` — multi-axis review:
   - Correctness, readability, architecture, security, performance
   - DRY, dead code, abstraction quality
   - Final judge for code-quality gate
2. `qa-tester` (review-mode) — adversarial test coverage:
   - Are tests assertion-strong (T6)? Would a 1-char bug still pass?
   - Edge cases reviewers might have missed
   - Race condition coverage on concurrent code

## Adversarial cycle — bounded 3 rounds

Apply `doubt-driven-development` skill:
1. Reviewer challenges the diff (find weakness)
2. Lead defends or fixes
3. Re-challenge with stripped reasoning

Cap: 3 rounds per reviewer. After cap → ship-block requires explicit user OK.

## High-risk escalation

Touching auth / billing / migrations / locks / external integrations → also escalate to Codex (`codex exec`) for adversarial CLI review (when installed). Gemini (`gemini -p`) optional for cross-file breadth on >30-file diffs.

## Gate focus

- **pre-merge-gate.md** — all gates green
- **hard stops** — 3rd agent on same issue → STOP and re-frame
- Findings → batch all, fix together, NOT one-by-one

## Output

- Reviewer reports (findings + severity)
- Resolution log (fixed / deferred / wontfix with rationale)
- Final go / no-go signal

## Next phase

All gates green + user OK → `/team-ship` to deploy + announce.
