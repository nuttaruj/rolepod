---
description: Invoke Team-verify phase — code → evidence (parallel quality agents)
---

# Team Verify Recipe

You are entering Team-verify phase. Convert built code into auditable evidence.

## Spawn via Task tool

Spawn in parallel based on what was built:

1. `qa-tester` (always — universal floor)
   - Run new tests + full existing suite
   - Verify business-logic correctness
   - Hunt edge cases / race conditions / missed flows
2. `security-engineer` (when touched: auth / permissions / billing / data sensitivity / external)
   - Threat model the diff
   - Validate input handling, authz at boundaries
   - Check secret / PII handling
3. `performance-engineer` (when touched: hot path / DB queries / bundle size / latency-sensitive)
   - Benchmark before vs. after
   - Profile critical path
   - p95 / p99 / bundle metrics

## Path filters

| Touched | Add agent |
|---------|-----------|
| Auth / authz / sessions | `security-engineer` |
| Billing / payments / credits | `security-engineer` |
| Migrations / schema | `qa-tester` (rollback test) + `security-engineer` |
| External integrations w/ side effects | `security-engineer` |
| Render path / bundles / DB queries | `performance-engineer` |

## Gate focus

- **T1-T6 testing** — every checkpoint passes
- **verify-first** — every "passes" claim cited with command + output snippet

## Output

- Test evidence (command + output)
- Security report (findings + severity + fix)
- Perf delta (metric before vs. after)

Findings → loop back to `/team-build` to fix → re-verify.

## Next phase

Evidence clean → `/team-review` for adversarial pass.
