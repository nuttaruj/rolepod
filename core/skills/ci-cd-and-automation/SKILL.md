---
name: ci-cd-and-automation
description: Compatibility shim — CI/CD lane discipline (3-phase) and pipeline configuration now live in `finish-work`; depth lives in the `devops-sre` agent.
when_to_use: when configuring build/test/deploy automation, adding quality gates, splitting CI lanes by speed and risk, or debugging slow/flaky pipelines
tier: 3
redirect_to: finish-work
---

# ci-cd-and-automation

Compatibility shim. CI/CD lane policy now lives in **`finish-work`**; the `devops-sre` agent adds depth when installed.

→ Open `core/skills/finish-work/SKILL.md` and follow that instead. Brief `devops-sre` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `finish-work` is not available

Minimum viable fallback:

1. Phase 1 (every PR, required, < 5 min): lint, typecheck, smoke unit, auth guard, tenant isolation, money core, migration apply, build
2. Phase 2 (path-triggered, required when matched): module's full suite
3. Phase 3 (nightly / manual, not required): integration, chaos, security deep, E2E, perf benchmark
4. Required red → Lead fixes and re-pushes; user-authorized merge intent does not need re-asking per fix
5. Auto-merge only when ALL required lanes green AND user already authorized merge
6. Slow / flaky pipelines: isolate flake, move to nightly tier, fix root cause
7. Pin tool versions in CI; floating tags cause silent drift
