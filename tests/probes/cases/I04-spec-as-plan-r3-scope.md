skill: orchestrating-plans
expect: LANE:.*R3
expect: WHY:.*(single|one) owner
expect: NEXT-SKILL:.*write-plan
forbid: Scope grows past one file \(its test file included\)
---
You are implementing an approved spec. Use only the supplied skill text; do not use tools. Answer only from that text. The spec already names two ordered tasks. Each task names its files, verify command and dependency. One owner will do all work. There is no high-risk path and no parallel work. No plan artifact exists.

Can you build from the inline checklist? Later, while Task 1 is underway, you discover Task 2 touches authentication (high-risk).

Answer exactly:
LANE: <the eligible lane and its tier>
WHY: <why it qualifies>
NEXT: <the next action>
REROUTE: <what happens when Task 2 turns out high-risk>
NEXT-SKILL: <the skill used after the reroute>
