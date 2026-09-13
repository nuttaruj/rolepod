skill: review-code
expect: FINAL:\*{0,2} *STOP
forbid: CONTINUE
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the user's message was exactly: "review the diff on this branch". Nothing else was asked — no fix, no merge, no ship. Assume the review is finished: two MINOR findings, no blockers, and a plan file in the repo still has unchecked tasks.

Question: what do you do immediately after handing the review report to the user? Answer in this exact format:
NEXT: <numbered list of the concrete next actions you would take, per the skill>
FINAL: STOP | CONTINUE → <skill or action>
QUOTE: <the one line from the skill that decided it>
