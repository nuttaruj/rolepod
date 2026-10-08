skill: write-plan
expect: CARRIES:\*{0,2} *YES
expect: LINE:.*id,date,total,status
forbid: CARRIES:\*{0,2} *NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are writing the plan artifact for an approved spec. The spec's Chosen approach fixes this contract, agreed with `system-architect`: "`GET /orders/export` returns `text/csv`; the column order is frozen as `id,date,total,status` — existing importers parse by position, so no column is added, dropped or reordered." Task 2 builds that endpoint. The spec path is already on the brief's Plan/Spec line.

Question: does Task 2's own block (its Change or Done when) carry the frozen contract clause, or does the spec path on the brief cover it? Answer in this exact format:
CARRIES: YES | NO  (YES = the task block itself states the clause)
LINE: <the Change or Done when line you write for Task 2, or "none">
QUOTE: <the one line from the skill that decided it>
