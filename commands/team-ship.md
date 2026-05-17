---
description: Invoke Team-ship phase — approved → deploy + announce + post-ship support
disable-model-invocation: true
---

# Team Ship Recipe

You are entering Team-ship phase. Move reviewed code from "green" to "live + announced".

## Spawn via Task tool

1. `devops-sre` — deploy:
   - Pre-deploy checklist (migrations applied? feature flags set? rollback ready?)
   - CI 3-phase gates (Phase 1 fast critical + Phase 2 path-triggered must be green)
   - Deploy + smoke test in target environment
   - Monitor post-deploy metrics (error rate, latency, alerts)
2. `tech-writer` — release notes:
   - Internal CHANGELOG entry
   - ADR if architectural decision
   - API doc updates for any public surface change
3. `growth-marketer` — announce:
   - External blog / changelog / social post (when user-facing)
   - SEO impact check (when surface change affects public pages)
4. `customer-success` — FAQ / support:
   - User-facing help article
   - Migration guide (when breaking change)
   - Support team brief (what's new, what to watch for)

## Skip lanes that don't apply

- Internal-only change → skip `growth-marketer`
- No user-facing surface → skip `customer-success`
- Hotfix / typo → only `devops-sre` (CI + deploy)

## Gate focus

- **CI 3-phase** — Phase 1 (every PR) + triggered Phase 2 must be green before merge
- **Auto-merge rule** — user already OK'd commit + PR → merge auto when required CI green, no re-ask
- **Phase 3 nightly** — informational; catches issue → notify, don't block

## Output

- Deploy confirmation (env + version + smoke result)
- Release notes published
- Announcement (when applicable)
- FAQ / support brief (when user-facing)

## Post-ship

- Monitor metrics for 1 cycle (deploy lag varies)
- File follow-up tasks for deferred items from `/team-review`
- Update MemPalace KG with any major architectural decision made during the lifecycle
