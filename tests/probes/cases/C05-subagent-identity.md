core: always-on
expect: WHO-EDITS:[* ]*ME
forbid: WHO-EDITS:[* ]*DISPATCH
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the text after the `--- CORE` line below. Use no tools; answer from the text. It sits in the AGENTS.md of the project you were spawned in.

Situation: you are the backend-developer sub-agent a Lead spawned. Your brief says: "Task 2: round tax once per invoice in invoice.py (one file + its test). Run the Command. Never commit. Return a decision brief."

Question: who makes the edit? Answer in this exact format:
WHO-EDITS: ME | DISPATCH-OWNER
QUOTE: <the one line from the text that decided it>
