skill: implement-plan
expect: (SPEC-AS-PLAN|spec-as-plan) R3|≤3 approved ordered tasks
expect: eligible|qualifies
expect: (single|one) owner
expect: high-risk.*write-plan|write-plan.*high-risk
forbid: Scope grows past one file \(its test file included\)
---
You are implementing an approved spec. Use only the supplied skill text; do not use tools. Answer only from that text. The spec already names two ordered tasks. Each task names its files, verify command and dependency. One owner will do all work. There is no high-risk path and no parallel work. No plan artifact exists.

Can you build from the inline checklist? State the eligible lane, its tier and why it qualifies, then the next action.

Later, while Task 1 is underway, you discover Task 2 touches authentication (high-risk). State the reroute and next skill.
