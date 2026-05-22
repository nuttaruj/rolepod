<!-- Rolepod release checklist — fill BEFORE production traffic. -->
<!-- Every box must be checked. An unchecked box blocks the launch. -->

# <Release> — Launch Checklist

## Rollback
- [ ] Last-good SHA recorded: `<sha>`
- [ ] Revert command known and tested: `<command>`

## Monitoring
- [ ] Dashboard URL: <url>
- [ ] Alert thresholds named: <metric + threshold>
- [ ] On-call notified: <who>

## Feature flag
- [ ] Flag name: `<flag>` — default confirmed: <on / off>
- [ ] Rollout plan: <staged % / cohort / all at once>

## Migration (if any)
- [ ] Forward migration applied and verified
- [ ] Rollback migration tested

## Go / no-go
<Every box checked → GO. Any box unchecked → NO-GO, do not send traffic.>
GO | NO-GO
