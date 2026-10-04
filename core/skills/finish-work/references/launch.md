<!-- Load when a finish involves production traffic. -->

# Launch

- A genuine launch event is first traffic to a new surface, a staged rollout, or a migration. A routine merge riding the existing deploy pipeline is not one; its evidence is the CI lanes.
- A genuine launch fills `templates/release-checklist.md` before traffic. Record rollback, a measurable success signal, and applicable operational safety. Include feature flag, monitoring, on-call, and migration fields only when the launch requires them; give a short reason for each omitted section. Do not create infrastructure solely to fill a checklist field.
- Any applicable check missing, unverified, or unchecked → NO-GO; send no traffic until it is complete. A routine merge on the existing deploy pipeline uses its CI evidence and does not need a launch checklist.
