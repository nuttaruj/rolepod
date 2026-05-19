---
name: shipping-and-launch
description: Compatibility shim — production launch checklist (monitoring / rollback / alerts / on-call) now lives in `finish-work`.
when_to_use: when preparing to deploy, drafting a launch checklist, setting up monitoring/alerts, or planning a rollback for a risky change
tier: 3
redirect_to: finish-work
---

# shipping-and-launch

Compatibility shim. Launch checklist now lives in **`finish-work`**; the `devops-sre` agent adds depth when installed.

→ Open `core/skills/finish-work/SKILL.md` and follow that instead. Brief `devops-sre` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `finish-work` is not available

Minimum viable fallback:

1. Rollback plan: commit SHA + revert command, tested in staging
2. Monitoring dashboard URL named, accessible to on-call
3. Alert thresholds defined (error rate, latency, queue depth)
4. On-call notified before traffic flips
5. Feature flag default state confirmed
6. Migration is forward + rollback safe; backfill plan ready if needed
7. Post-launch: capture non-obvious decisions; queue `gitnexus analyze` if ≥ 5 files changed
