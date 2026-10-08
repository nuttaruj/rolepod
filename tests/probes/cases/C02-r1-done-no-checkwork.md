core: always-on
expect: LOAD-CHECK-WORK:[* ]*NO
forbid: LOAD-CHECK-WORK:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the text after the `--- CORE` line below. Use no tools; answer from the text.

Situation: the user asked you to fix one typo in a README sentence. You edited that one line; the edit echo shows the corrected line. Nothing else changed.

Question: before you tell the user it is done, do you load check-work? Answer in this exact format:
LOAD-CHECK-WORK: YES | NO
QUOTE: <the one line from the text that decided it>
