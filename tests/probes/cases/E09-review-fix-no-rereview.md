skill: orchestrating-plans
expect: NEXT SKILL:\*{0,2} *`?finish-work
forbid: NEXT SKILL:.*(convening-code-review|implement-plan)
---
You are the Lead, an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: a plan with three R3 (multi-file) tasks, none on a high-risk path; every checkbox is `- [x]`. The plan's ONE combined review ran over the plan diff: no BLOCKER or MAJOR, two MINOR findings (a variable name, a missing guard clause). The owning role fixed both in one commit, and the review's rule is that MINORs never open a re-check. You just ran `check-work` on the tree with those fixes: every check passed and your evidence block ends with `Status: VERIFIED`.

Question: which skill runs next? Answer in this exact format:
NEXT SKILL: <convening-code-review | finish-work | implement-plan | other>
WHY: <one sentence>
QUOTE: <the one line from the skill that decided it>
