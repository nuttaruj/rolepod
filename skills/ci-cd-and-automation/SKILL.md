---
name: ci-cd-and-automation
description: Set up and harden CI/CD pipelines. Use when configuring build/test/deploy automation, adding quality gates, splitting CI lanes by speed and risk, or debugging slow/flaky pipelines.
---

# CI/CD and Automation

A pipeline is a contract: every merge claims the code meets these gates. If the gates lie (flaky, skipped, slow), people stop trusting them and ship broken code. This skill is about designing gates that catch real problems fast and don't get in the way the rest of the time.

## When to use

- Greenfield repo with no CI yet
- Tests exist but aren't wired to PRs
- Pipeline takes >10 minutes for a 1-line change
- Required check is flaky (re-run to merge culture)
- Adding a new module that needs its own test lane
- Setting up auto-deploy / preview environments
- Migrating between CI providers

## Three-phase model

Match cost to signal. Don't run everything on every push.

| Phase | Trigger | Budget | Required to merge |
|-------|---------|--------|-------------------|
| **1 Fast critical** | every PR | <5 min | YES |
| **2 Path-triggered** | path glob match | <15 min | YES when triggered |
| **3 Nightly / manual** | cron / dispatch | unbounded | NO (next-cycle catch) |

### Phase 1 — universal invariants

Things that MUST hold no matter what was touched: lint, typecheck, smoke unit subset, auth guard, tenant isolation, money-core path, migration apply on fresh DB, production build. Keep this lane under 5 minutes — if it bloats, demote candidates to Phase 2.

### Phase 2 — touched-only depth

Each module owns a path glob and a test lane. Touch `apps/billing/**` → billing's full suite runs. Touch only frontend → billing lane skipped. Encode this in the workflow's `paths:` filter, not in conditional `if:` inside one big job (it's harder to read and required-checks behave oddly).

### Phase 3 — slow / flaky / expensive

Full integration, container build, chaos, security deep scan, E2E, perf benchmark. Cron or workflow_dispatch. NOT required for merge — they catch regressions next cycle. If a Phase 3 lane finds something, file an issue or open a fix PR.

## How to apply

1. **Audit current pipeline**: list every job, its runtime, its trigger, whether it's required. Mark flaky ones.
2. **Categorize each job** into Phase 1/2/3 by speed and signal.
3. **Add path filters** to Phase 2 jobs so they only run when relevant.
4. **Move slow stuff to Phase 3** with a nightly cron.
5. **Set required checks** in branch protection: only Phase 1 + currently-running Phase 2.
6. **Cache aggressively**: dependencies, build artifacts, language toolchains. A cold pipeline that takes 8 minutes can usually hit 2 minutes warm.
7. **Fail fast**: lint and typecheck before tests. Don't wait 4 minutes to learn a syntax error broke the build.
8. **Surface flaky tests**: quarantine, don't disable. A flaky test is a real bug — race, ordering, time, network — fix or mark and track.

## Deploy automation

- **Preview per PR** — every PR gets an isolated preview URL. Reviewers click, not clone.
- **Promote artifacts, not branches** — the same build that passed CI is what goes to prod. Don't rebuild between environments.
- **Migrations apply before app rollout** — schema-first, code-second, with a rollback plan.
- **Health check gates rollout** — automated smoke after deploy; failure auto-rolls-back or pauses traffic.
- **Secrets via the platform's secret manager** — not in env files in the repo, not in CI logs.

## Common mistakes

- Running the full suite on every PR (slow → re-run culture → ignored failures)
- Marking flaky tests as required (people merge red and shrug)
- One mega-job that does lint + test + build + deploy (can't see what failed; no parallelism)
- Skipping CI on docs PRs by accident (path filter too narrow blocks needed checks)
- Caching the wrong layer (e.g. caching `node_modules` but not the pnpm store; cold every time)
- Letting Phase 3 stay broken (nightly red for weeks → no signal value left)
- Required checks that don't exist on some PRs (branch protection blocks merge forever)

## Quick reference

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Phase 1 >5 min | Too many tests in smoke set | Move slowest 20% to Phase 2 |
| Re-run-to-green common | Flaky tests in required lane | Quarantine, fix root cause |
| PR blocked, all checks pass | Required check name mismatch | Sync branch protection with workflow names |
| Same bug ships twice | No regression test added | Phase 1 invariant from postmortem |
| Cold cache every run | Cache key includes timestamp | Key by lockfile hash |
| Deploy succeeds, app broken | No post-deploy health check | Add smoke gate + auto-rollback |

## Output format

When proposing a CI change, present:

```
Goal: [what this enables / fixes]
Phase: [1 / 2 / 3] + reason
Trigger: [paths / events / schedule]
Budget: [target runtime]
Required: [yes/no — and what relaxes if no]
Rollout: [how to ship without breaking current PRs]
```
