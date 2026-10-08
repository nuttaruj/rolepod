core: always-on
expect: LOAD-FINISH-WORK:[* ]*YES
forbid: LOAD-FINISH-WORK:[* ]*NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the text after the `--- CORE` line below. Use no tools; answer from the text.

Situation: the work was a one-line typo fix (R1) on a branch. The user said "merge it". You are about to run `gh pr merge`.

Question: before the merge, do you load finish-work? Answer in this exact format:
LOAD-FINISH-WORK: YES | NO
QUOTE: <the one line from the text that decided it>
