<!-- Load when a finish involves production traffic. -->

# Launch

- A genuine launch event is first traffic to a new surface, a staged rollout, or a migration. A routine merge riding the existing deploy pipeline is not one; its evidence is the CI lanes.
- A launch fills `templates/release-checklist.md` before any traffic: rollback, monitoring, on-call, the feature flag default, migration safety. Every box checked → GO; any box unchecked → NO-GO, no traffic.
