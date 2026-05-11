---
name: shipping-and-launch
description: Run a disciplined production launch. Use when preparing to deploy, drafting a launch checklist, setting up monitoring/alerts, or planning a rollback for a risky change.
---

# Shipping and Launch

Most production incidents aren't caused by the code change — they're caused by what wasn't planned around the code change. This skill turns "ship it" into a repeatable sequence: gate the release, watch the right signals, know exactly how to undo.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER ship without a written rollback plan — exact command, exact owner, tested at least once. "Revert the commit" is not a rollback plan for migrations / data writes / external side effects.
2. NEVER ship with a required CI lane red. Phase 1 + triggered Phase 2 must all be green. Red lane fixed by Lead, re-pushed, re-verified — no override.
3. ALWAYS watch the right signal for ≥15 min post-deploy before declaring success. p95 latency, error rate, queue depth, business metric tied to the change.

The five minutes you save by skipping the rollback plan cost five hours of incident response.
</EXTREMELY-IMPORTANT>

## Red Flags — you are about to skip this skill

| Red flag (your thought) | What it actually means |
|-------------------------|------------------------|
| "Rollback is just `git revert`" | Not for migrations, queue messages, sent emails, charged cards. Plan per-change-type. |
| "I'll watch metrics after lunch" | The first 15 minutes are when issues surface. Watch live. |
| "Feature flag is off, no risk in shipping" | Flag-off code still executes import / startup paths. Verify the dark path too. |
| "CI was flaky, that red lane isn't real" | Flaky lane = real signal you cannot read. Stabilize or treat as red. |
| "Small change, no need for staged rollout" | The "small change" outage list is long. Stage by default for tenant-scoped systems. |

## When to use

- About to merge to a deployed branch
- First production launch of a feature
- Rolling out a migration
- Enabling a feature flag for a non-trivial percentage
- Switching providers, regions, or storage engines
- Re-launching after an incident

## Pre-launch checklist (run before merging the launch PR)

### Code

- [ ] All required CI lanes green (Phase 1 + triggered Phase 2)
- [ ] Reviewer passes: at least qa-tester; reviewer set per `reviewer-flow.md`
- [ ] Simplicity gate (S1-S5) passed
- [ ] Test gate (T1-T6) passed
- [ ] No TODO/FIXME blocking the launch surface
- [ ] No debug logs, no commented-out code, no `console.log` in hot paths

### Data

- [ ] Migration applied to staging, verified row counts and constraints
- [ ] Migration is reversible OR rollback strategy documented
- [ ] Backfill plan if columns/tables added with non-trivial data
- [ ] Backups confirmed taken within last cycle

### Surface

- [ ] Feature flag in place if blast radius warrants
- [ ] Rate limits adjusted if new endpoints added
- [ ] Auth/permissions reviewed for the new surface
- [ ] External dependencies (APIs, webhooks) have timeouts + circuit breakers

### Observability

- [ ] Logs structured and identifiable for the new surface
- [ ] Key metrics emitted (request rate, error rate, latency p50/p95)
- [ ] Alert thresholds set on at least: error rate spike, latency regression, saturation
- [ ] Dashboard linked in the launch PR description

### Rollback

- [ ] Rollback method tested in staging (not just "we'll redeploy")
- [ ] Feature flag kill-switch confirmed working
- [ ] Migration rollback path written down
- [ ] On-call knows what's launching and how to undo

## Launch sequence

1. **Announce** — short message in the launch channel: what, when, blast radius, on-call.
2. **Deploy with gradual exposure** — feature flag at 1% → 10% → 50% → 100%, watching dashboards between steps.
3. **Watch for one full cycle** — at each step, wait until you've seen normal traffic patterns (often 5-30 minutes), not just a clean smoke test.
4. **Confirm with real signal, not silence** — error rate flat AND request rate matching expectations. Silence can mean "no traffic," not "no errors."
5. **Hold position before next step** — don't push to 100% during the drink-coffee window. Let it bake.

## When to roll back

Rollback is the default response, not the failure case. Bias toward roll-back-and-investigate over fix-forward when:

- Error rate increases >2x baseline and isn't returning to normal
- Latency p95 increases >50% and isn't recovering
- Customer-impact reports start arriving from multiple sources
- A guarantee is silently broken (data integrity, auth, billing)
- You can't tell what's happening

Fix-forward only when: the bug is obvious, the fix is one line, AND you have a fast deploy. Otherwise revert.

## Post-launch (first 24 hours)

- Watch dashboards at: T+15min, T+1h, T+4h, T+24h
- Compare to a quiet baseline week, not yesterday (avoid Monday-vs-Sunday traps)
- Monitor support inbox / status page reports
- Check downstream systems — analytics, billing, batch jobs — for delayed effects
- Close the loop: post a short result note (success metrics or issues caught)

## Postmortem template (when something goes wrong)

```
What happened: [user-visible impact, timeline]
Why it happened: [root cause, not the trigger]
How we found out: [signal source, time-to-detect]
How we responded: [time-to-mitigate, time-to-resolve]
What we'd change: [concrete actions, with owners]
What we'd NOT change: [stuff that worked — credit it]
```

Blameless. Owners on actions, not on the cause. Ship the actions; otherwise the postmortem is theater.

## Common mistakes

- Launching Friday afternoon
- Deploying behind a flag, then enabling the flag without re-watching
- "Smoke test passed" used as a substitute for real-traffic observation
- No rollback plan because "the change is small"
- Alert thresholds copied from another service (false noise → ignored alerts)
- Postmortem with no action items, or actions with no owner
- Treating a near-miss as a non-event — log it, learn from it
- Touching unrelated code in the launch PR (now you're rolling back two things)

## Quick reference — risk → controls

| Risk level | Examples | Controls |
|-----------|----------|----------|
| Low | Copy change, pure UI tweak | Standard CI, deploy at any time |
| Medium | New endpoint, new schema column | Flag rollout, dashboard watch |
| High | Migration with backfill, auth change, billing | Flag + gradual + on-call paged + roll-back-tested |
| Critical | Cross-region cutover, irreversible data ops | Maintenance window, paired operator, dry run |

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "Rollback plan is overhead, deploys go fine 99% of the time" | The 1% costs your weekend. Rollback rehearsal at write time is 10 min; recovering a borked deploy without one is hours. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
