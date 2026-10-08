skill: security-review
expect: EXPLOIT-TRACE:[* ]*YES
expect: LEAK-CHECK:[* ]*YES
forbid: EXPLOIT-TRACE:[* ]*NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: you are dispatched on an R4 money diff to review it for security. The brief says `depth: full`.

Question: how deep do you go? Answer in this exact format:
EXPLOIT-TRACE: YES | NO
LEAK-CHECK: YES | NO   (memory and performance leaks on the changed code)
MAX-TOOL-CALLS: <number>
QUOTE: <the one line from the skill text that decided it>
