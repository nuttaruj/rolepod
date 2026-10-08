skill: orchestrating-plans
expect: NEXT SKILL:\*{0,2} *`?convening-code-review
expect: AFTER THAT:\*{0,2} *.*finish-work
forbid: NEXT SKILL:.*(check-work|finish-work)
---
You are the Lead, an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: a plan file with three R3 (multi-file) tasks, none on a high-risk path. Each task owner returned `COMPLETED` with its Command tail green, you spot-checked each and committed each. The plan's last code task was just committed; every checkbox is `- [x]`. No review of the plan diff has run yet.

Question: which skill runs next? Answer in this exact format:
NEXT SKILL: <check-work | convening-code-review | finish-work | other>
AFTER THAT: <the skill or step that follows it>
QUOTE: <the one line from the skill that decided it>
