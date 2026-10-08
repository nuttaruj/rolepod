skill: security-review
expect: EXPLOIT-TRACE:[* ]*NO
expect: CVE-LOOKUP:[* ]*NO
forbid: EXPLOIT-TRACE:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: you are dispatched on an R4 money diff to review it for security. The brief says `depth: checklist`.

Question: how deep do you go? Answer in this exact format:
EXPLOIT-TRACE: YES | NO
CVE-LOOKUP: YES | NO
MAX-TOOL-CALLS: <number>
QUESTION-ASKED: <the one question you answer>
QUOTE: <the one line from the skill text that decided it>
