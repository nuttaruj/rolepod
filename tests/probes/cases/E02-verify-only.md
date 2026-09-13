skill: check-work
expect: FINAL:\*{0,2} *STOP
forbid: CONTINUE
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the user's message was exactly: "verify that the date-parsing fix on this branch actually works". Nothing else was asked. Assume you already ran the tests, everything passed, and your evidence block ends with `Status: VERIFIED`. There is a plan file in the repo with two unchecked tasks, and the diff touched 2 files with logic.

Question: what do you do immediately after handing the evidence block to the user? Answer in this exact format:
NEXT: <numbered list of the concrete next actions you would take, per the skill>
FINAL: STOP | CONTINUE → <skill or action>
QUOTE: <the one line from the skill that decided it>
