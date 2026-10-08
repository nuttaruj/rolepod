skill: write-spec
expect: Q2:\*{0,2} *OPEN
expect: Q3:\*{0,2} *OPEN
forbid: Q2:\*{0,2} *DEFAULTED
forbid: Q3:\*{0,2} *DEFAULTED
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are in write-spec Discovery for "add a CSV export button to the orders page". Your first frontier round asked three numbered questions, each with a recommended default:
1. Format — (a) CSV only [default] (b) CSV + XLSX
2. Row limit — (a) 10 000 rows [default] (b) no limit
3. Cancelled orders — (a) excluded [default] (b) included
The user replied exactly: "1a. 3 — not sure yet."

Question: after this reply, what is the state of each question, and what do you do next? Answer in this exact format:
Q1: SETTLED | OPEN | DEFAULTED
Q2: SETTLED | OPEN | DEFAULTED
Q3: SETTLED | OPEN | DEFAULTED
NEXT: <the one concrete thing you do next>
QUOTE: <the one line from the skill that decided it>
