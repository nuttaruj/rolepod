skill: finish-work
expect: BLOCK:[* ]*NO
forbid: BLOCK:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: an R4 diff is ready to merge. The review mode is `standard`. Its `security-engineer` report and both lens reports are present and clean, its check-work Status matches the tree, CI is green. There is no adversarial-pass report. The user authorized the merge.

Question: does the pre-merge gate block on the missing adversarial report? Answer in this exact format:
BLOCK: YES | NO
QUOTE: <the one line from the skill that decided it>
