skill: using-rolepod
expect: TIER:\*{0,2} *R4
expect: FIRST SKILL:\*{0,2} *`?write-spec
forbid: TIER:\*{0,2} *R[0-3]
---
You are an AI coding agent working in a web-app repo. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the user's message was exactly: "change the session token lifetime in src/auth/session.ts from 30 days to 7 days." The change itself is one constant in one file.

Question: how do you route this request? Answer in this exact format:
TIER: <R0 | R1 | R2 | R3 | R4>
FIRST SKILL: <the skill that fires first, or none>
NEXT: <the one concrete thing you do next>
QUOTE: <the one line from the skill that decided it>
