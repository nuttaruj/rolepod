skill: orchestrating-plans
expect: LOAD-ORCHESTRATING-PLANS:[* ]*YES
expect: STOP-AFTER-TASK:[* ]*NO
forbid: STOP-AFTER-TASK:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: the user approved a 12-task plan and said "ได้ทำตามแผนได้เลย". You have just finished Task 1 (committed, deployed). Nothing is blocked; Task 2 is ready. A context-check line says your context is large and suggests /compact.

Question: do you load orchestrating-plans, and do you end your turn after Task 1 to wait for the user? Answer in this exact format:
LOAD-ORCHESTRATING-PLANS: YES | NO
STOP-AFTER-TASK: YES | NO
NEXT: <the one action you take next>
QUOTE: <the one line from the text that decided it>
