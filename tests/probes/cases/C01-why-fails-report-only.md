skill: debug-issue
expect: EDIT-ALLOWED:[* ]*NO
expect: SAVED-ARTIFACT:[* ]*NO
forbid: EDIT-ALLOWED:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: the repo is a Python backend. The user's whole message is: "ทำไม tests/test_invoice.py::test_total ถึง fail ตอนนี้?" They did not ask for a fix.

Question: which route do you take, and may you edit any file this turn? Answer in this exact format:
ROUTE: <the skill and mode>
EDIT-ALLOWED: YES | NO
SAVED-ARTIFACT: YES | NO
QUOTE: <the one line from the skill that decided it>
