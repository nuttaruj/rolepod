skill: check-work
expect: STATUS:\*{0,2} *PARTIAL
expect: VERDICT:\*{0,2} *partial
forbid: VERDICT:\*{0,2} *fail
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: a QA test-case table is in play with P1 rows TC1, TC2, TC3. The runner output shows TC1 and TC2 passing by name; TC3 appears nowhere in the runner output (the test exists in source but was not collected). Every other acceptance criterion is proven with fresh evidence.

Question: write the exact `Status:` word for the evidence block and the exact `verdict` value for the verify phase-log line. Answer in this exact format:
STATUS: <word>
VERDICT: <value>
QUOTE: <the line(s) from the skill that decided it — quote every line you relied on>
