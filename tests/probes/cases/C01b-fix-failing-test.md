skill: using-rolepod
expect: EDIT-ALLOWED:[* ]*YES
forbid: EDIT-ALLOWED:[* ]*NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: the repo is a Python backend. The user's whole message is: "tests/test_invoice.py::test_total fail อยู่ ช่วยแก้ให้หน่อย".

Question: which route do you take, and may the work end in an edit to fix the bug? Answer in this exact format:
ROUTE: <the skill and mode>
EDIT-ALLOWED: YES | NO
QUOTE: <the one line from the skill that decided it>
