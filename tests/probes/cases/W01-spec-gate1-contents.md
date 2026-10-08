skill: write-spec
expect: SHOWS:.*(path|file|docs/rolepod/specs)
expect: SHOWS:.*assum
forbid: TAGGED:\*{0,2} *NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are running write-spec for "add a CSV export button to the orders page". Discovery is done: the user confirmed CSV only and "current filters apply"; for the row limit the user said "don't know", and you picked 10 000 rows yourself. You also decided on your own that the export excludes cancelled orders. Self-review is done. You have written the spec to a file and run spec-lint. You are now at Gate 1.

Question: what do you put in front of the user at Gate 1? Describe what you show and where, and what items you mark differently. Answer in this exact format:
SHOWS: <comma-separated list of every item you present in chat>
TAGGED: YES | NO  (YES = some items in chat are marked as assumption/inference)
QUOTE: <the one line from the skill that decided it>
