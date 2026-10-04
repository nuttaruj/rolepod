skill: implement-plan
expect: SPEC-AS-PLAN R3.*eligible|≤3 approved ordered tasks
expect: single owner
expect: high-risk.*write-plan|write-plan.*high-risk
forbid: Scope grows past one file \(its test file included\)
---
You are implementing an approved spec. It already names two ordered tasks. Each task names its files, verify command and dependency. One owner will do all work. There is no high-risk path and no parallel work. No plan artifact exists.

Can you build from the inline checklist? State the lane and the next action.
