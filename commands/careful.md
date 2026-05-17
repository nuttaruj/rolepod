---
description: Toggle careful mode for high-risk operations — extra verification, smaller increments, mandatory peer review.
disable-model-invocation: true
---

# Careful Mode

Activate for high-risk surface (auth / billing / migrations / locks / external integrations / destructive ops).

## When to activate

- Touching `**/auth/**`, `**/permissions/**`, `**/billing/**`, `**/payments/**`, `**/migrations/**`
- Distributed locks / queue handlers / race conditions
- 3rd-party integrations w/ side effects
- File / data deletion or encryption
- Crypto / signing / token issuance
- Pre-production deploy

## Rules in careful mode

1. **Smaller increments** — every change ≤30 lines; bigger = split into multiple commits
2. **Mandatory verify-first** — Read all referenced files; never assume
3. **Mandatory test BEFORE code** — TDD strict: failing test → code → pass
4. **Mandatory race-condition test** — for any concurrent code
5. **Mandatory rollback test** — for any migration / destructive op
6. **Mandatory Codex adversarial review** — per reviewer-flow.md high-risk routing
7. **Mandatory user confirmation** before destructive command
8. **Hard cap tool calls 5 per task** — force breaking into smaller pieces
9. **Mandatory MemPalace KG save** — for any decision made
10. **No Auto-merge** — even after CI green, ask user before merge

## How to invoke

User types `/careful` → Lead acknowledges + applies rules above for next operations until user types `/normal` or session ends.

## After careful mode

State explicit:
```
Careful mode: completed N operations.
Risks identified: [list]
Tests added: [list]
Rollback ready: [yes/no + procedure]
KG entries saved: [list]
```

## Anti-pattern — DO NOT

- Skip careful mode for "small" change touching high-risk surface
- Combine careful-mode change with non-careful change in same commit
- Ship in careful mode without all 10 rules satisfied
