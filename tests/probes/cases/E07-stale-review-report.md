skill: orchestrating-plans
expect: NEXT SKILL:\*{0,2} *`?convening-code-review
forbid: NEXT SKILL:.*(finish-work|implement-plan)
---
You are the Lead, an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the user asked you to build a feature from a plan. The plan has four tasks: three R3 (multi-file) tasks and one R4 (high-risk) task that changes the login token check. Every task is built and committed and every checkbox is `- [x]`. The R4 task's owner ran its per-task reviewers, and their reports sit under `.rolepod/evidence/review/`. That folder also holds review reports from two older, already-shipped plans. You just ran `check-work` on the whole change: every check passed and your evidence block ends with `Status: VERIFIED`. The change touches 9 files with logic.

Question: which skill runs next? Answer in this exact format:
NEXT SKILL: <convening-code-review | finish-work | implement-plan | other>
WHY: <one sentence>
QUOTE: <the one line from the skill that decided it>
