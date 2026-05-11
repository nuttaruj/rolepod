---
name: ci-cd-and-automation
description: Set up and harden CI/CD pipelines. Use when configuring build/test/deploy automation, adding quality gates, splitting CI lanes by speed and risk, or debugging slow/flaky pipelines.
---

# CI/CD and Automation

Pipeline = contract: every merge claims code meets these gates. Flaky/skipped/slow gates → people stop trusting → broken code ships.

## When to use

- Greenfield repo, no CI yet
- Tests exist but not wired to PRs
- Pipeline >10 min for 1-line change
- Required check flaky (re-run-to-merge culture)
- New module needs own test lane
- Setup auto-deploy / preview environments
- CI provider migration

## Three-phase model

Match cost to signal.

| Phase | Trigger | Budget | Required to merge |
|-------|---------|--------|-------------------|
| **1 Fast critical** | every PR | <5 min | YES |
| **2 Path-triggered** | path glob match | <15 min | YES when triggered |
| **3 Nightly / manual** | cron / dispatch | unbounded | NO |

### Phase 1 — universal invariants

Must hold regardless of touch: lint, typecheck, smoke unit subset, auth guard, tenant isolation, money-core path, migration apply on fresh DB, prod build. Keep <5 min — bloat → demote to Phase 2.

### Phase 2 — touched-only depth

Each module owns path glob + test lane. Touch `apps/billing/**` → billing's full suite. Touch only frontend → billing lane skipped. Use workflow `paths:` filter, not conditional `if:` inside one big job.

### Phase 3 — slow / expensive

Full integration, container build, chaos, security deep scan, E2E, perf benchmark. Cron or workflow_dispatch. NOT required for merge. Finding → file issue or fix PR.

## How to apply

1. **Audit current pipeline** — list jobs, runtime, trigger, required. Mark flaky.
2. **Categorize** each into Phase 1/2/3 by speed and signal
3. **Add path filters** to Phase 2
4. **Move slow to Phase 3** with nightly cron
5. **Set required checks** in branch protection: Phase 1 + currently-running Phase 2
6. **Cache aggressively** — deps, artifacts, toolchains. Cold 8 min → warm 2 min.
7. **Fail fast** — lint and typecheck before tests
8. **Surface flaky tests** — quarantine, don't disable. Flaky = real bug (race/order/time/network).

## Deploy automation

- **Preview per PR** — isolated preview URL. Reviewers click, not clone.
- **Promote artifacts, not branches** — same build CI passed → prod. No rebuild between envs.
- **Migrations before app rollout** — schema-first, code-second, rollback plan
- **Health check gates rollout** — auto smoke after deploy; failure → auto-rollback or pause
- **Secrets via platform's secret manager** — not in env files, not in CI logs

## Common mistakes

- Full suite every PR (slow → re-run culture → ignored failures)
- Flaky tests marked required (merge red and shrug)
- One mega-job lint+test+build+deploy (no parallelism, hard to debug)
- Skipping CI on doc PRs accidentally (path filter too narrow)
- Caching wrong layer (cache `node_modules` but not pnpm store)
- Phase 3 stays broken (nightly red weeks → no signal)
- Required checks not on all PRs (branch protection blocks merge forever)

## Quick reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| Phase 1 >5 min | Too many tests in smoke | Move slowest 20% to Phase 2 |
| Re-run-to-green common | Flaky required tests | Quarantine, fix root cause |
| PR blocked, all checks pass | Required check name mismatch | Sync branch protection with workflow names |
| Same bug ships twice | No regression test | Phase 1 invariant from postmortem |
| Cold cache every run | Cache key includes timestamp | Key by lockfile hash |
| Deploy ok, app broken | No post-deploy health check | Add smoke gate + auto-rollback |

## Output format

```
Goal: [what this enables / fixes]
Phase: [1 / 2 / 3] + reason
Trigger: [paths / events / schedule]
Budget: [target runtime]
Required: [yes/no — and what relaxes if no]
Rollout: [how to ship without breaking current PRs]
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Add CI later, after we ship" | Untested merges accumulate; regression surface too wide to bisect by 'later'. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
