<!-- Rolepod release checklist — fill BEFORE production traffic; mark each section applicable or omit it with a short reason. -->

# <Release> — Launch Checklist

## Rollback
- [ ] Last-good SHA recorded: `<sha>`
- [ ] Revert command known and tested: `<command>`
- [ ] Rollback trigger and owner named: <condition · owner — e.g. error rate > 2x baseline, P95 +50%, any data-integrity or security problem>

## Success signal
- [ ] Launch success signal and threshold named: <metric · target · observation window>

## Monitoring (when production monitoring is needed)
- [ ] Dashboard URL: <url>
- [ ] Alert thresholds named: <metric + threshold>
- [ ] On-call notified: <who>
- Omitted because: <short reason, if not applicable>

## Feature flag (when the launch uses a feature flag)
- [ ] Flag name: `<flag>` — default confirmed: <on / off>
- [ ] Rollout plan: <staged % / cohort / all at once>
- Omitted because: <short reason, if not applicable>

## Migration (when the launch includes a migration)
- [ ] Forward migration applied and verified
- [ ] Rollback migration tested
- Omitted because: <short reason, if not applicable>

## Operational safety (when applicable)
- [ ] Required operational owner and safety checks named: <owner · checks>
- Omitted because: <short reason, if not applicable>

## Go / no-go
<Every applicable box checked and omission justified → GO. Any applicable box unchecked or unverified → NO-GO, do not send traffic.>
GO | NO-GO
