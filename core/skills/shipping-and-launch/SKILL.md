---
name: shipping-and-launch
description: Run a disciplined production launch. Use when preparing to deploy, drafting a launch checklist, setting up monitoring/alerts, or planning a rollback for a risky change.
---

# Shipping and Launch

Most incidents = not the code change, but what wasn't planned around it. Gate release, watch right signals, know exactly how to undo.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER ship without a written rollback plan — exact command, owner, tested once. "Revert the commit" is not a rollback for migrations / data writes / external side effects.
2. NEVER ship with required CI lane red. Phase 1 + triggered Phase 2 must all be green.
3. ALWAYS watch the right signal ≥15 min post-deploy before declaring success.

5 min saved skipping rollback = 5 hours of incident response.
</EXTREMELY-IMPORTANT>

## Red Flags

| Thought | Reality |
|---------|---------|
| "Rollback is just git revert" | Not for migrations, queue messages, sent emails, charged cards. |
| "I'll watch metrics after lunch" | First 15 min = when issues surface. Watch live. |
| "Flag is off, no risk" | Flag-off code still runs import/startup paths. Verify. |
| "CI was flaky, lane isn't real" | Flaky = real signal you can't read. Treat as red. |
| "Small change, no staged rollout" | The "small change" outage list is long. |

## When to use

- About to merge to deployed branch
- First production launch of feature
- Rolling out migration
- Feature flag for non-trivial %
- Switching providers/regions/storage
- Re-launch after incident

## Pre-launch checklist

### Code
- [ ] Required CI lanes green (Phase 1 + triggered Phase 2)
- [ ] Reviewer passes (min qa-tester per `reviewer-flow.md`)
- [ ] Simplicity gate (S1-S5) passed
- [ ] Test gate (T1-T6) passed
- [ ] No TODO/FIXME blocking launch surface
- [ ] No debug logs, no commented-out code

### Data
- [ ] Migration applied to staging, row counts + constraints verified
- [ ] Reversible OR rollback strategy documented
- [ ] Backfill plan if columns/tables added with non-trivial data
- [ ] Backups confirmed within last cycle

### Surface
- [ ] Feature flag if blast radius warrants
- [ ] Rate limits adjusted for new endpoints
- [ ] Auth/permissions reviewed
- [ ] External deps have timeouts + circuit breakers

### Observability
- [ ] Logs structured + identifiable
- [ ] Key metrics emitted (request rate, error rate, latency p50/p95)
- [ ] Alerts on error spike, latency regression, saturation
- [ ] Dashboard linked in PR

### Rollback
- [ ] Method tested in staging (not just "redeploy")
- [ ] Feature flag kill-switch confirmed
- [ ] Migration rollback documented
- [ ] On-call knows what's launching

## Launch sequence

1. **Announce** — short message: what, when, blast radius, on-call
2. **Gradual exposure** — flag at 1% → 10% → 50% → 100%, watching between
3. **Watch one full cycle per step** — normal traffic patterns (5-30 min), not just smoke test
4. **Confirm with real signal** — error rate flat AND request rate matching expectations. Silence ≠ no errors.
5. **Hold position before next step** — let it bake

## When to roll back

Rollback is the default response. Bias toward roll-back-and-investigate when:

- Error rate >2x baseline, not returning
- Latency p95 >50% up, not recovering
- Customer reports from multiple sources
- Guarantee silently broken (data integrity, auth, billing)
- You can't tell what's happening

Fix-forward only when: bug obvious, fix is one line, fast deploy available.

## Post-launch (first 24h)

- Watch dashboards at T+15m, T+1h, T+4h, T+24h
- Compare to quiet baseline week (avoid Monday-vs-Sunday traps)
- Monitor support inbox / status page
- Check downstream — analytics, billing, batch jobs
- Close loop: post short result note

## Postmortem template

```
What happened: [user-visible impact, timeline]
Why: [root cause, not the trigger]
How found: [signal source, time-to-detect]
How responded: [time-to-mitigate, time-to-resolve]
What we'd change: [concrete actions, owners]
What we'd NOT change: [credit what worked]
```

Blameless. Owners on actions. Ship actions or postmortem = theater.

## Common mistakes

- Launching Friday afternoon
- Deploying behind flag, enabling without re-watching
- "Smoke test passed" substituting for real-traffic observation
- No rollback plan because "change is small"
- Alert thresholds copied from another service → false noise → ignored
- Postmortem with no action items or no owner
- Treating near-miss as non-event
- Touching unrelated code in launch PR

## Quick reference — risk → controls

| Risk | Examples | Controls |
|------|----------|----------|
| Low | Copy change, UI tweak | Standard CI, deploy anytime |
| Medium | New endpoint, schema column | Flag rollout, dashboard watch |
| High | Migration with backfill, auth, billing | Flag + gradual + on-call paged + rollback tested |
| Critical | Cross-region cutover, irreversible data | Maintenance window, paired operator, dry run |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Rollback plan is overhead, deploys go fine" | The 1% costs your weekend. Rehearsal = 10 min; recovery = hours. |
| "Simple change" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
