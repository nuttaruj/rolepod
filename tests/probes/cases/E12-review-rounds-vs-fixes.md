skill: convening-code-review
expect: CASE=FULL-R4-ROUND-CAP\s+ANSWER=RULE-AND-CONTINUE
expect: CASE=ROUND-3-FIXER\s+ANSWER=FRESH-HIGHER-TIER
expect: CASE=ROUND-1-INCLUDED\s+ANSWER=YES
expect: CASE=LITE-ROUND-2\s+ANSWER=YES
expect: CASE=STANDARD-R4-ROUND-2\s+ANSWER=YES
expect: CASE=R2-R3-ROUND-2\s+ANSWER=YES
expect: CASE=MINOR-ONLY\s+ANSWER=NO\s+REASON=.*author evidence
forbid: CASE=FULL-R4-ROUND-CAP\s+ANSWER=STOP-AND-HAND-OFF
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Classify each case using only the skill. Return one line per case in this exact format (ANSWER is RULE-AND-CONTINUE or STOP-AND-HAND-OFF for FULL-R4-ROUND-CAP, FRESH-HIGHER-TIER or SAME-OWNER for ROUND-3-FIXER, YES or NO for the others):
CASE=<id> ANSWER=<value> REASON=<brief evidence>

CASE=FULL-R4-ROUND-CAP: A Full R4 review is still open after round 4.
CASE=ROUND-3-FIXER: A BLOCKER fix goes into review round 3. Who makes that fix?
CASE=ROUND-1-INCLUDED: Does the four-round cap include the initial review round?
CASE=LITE-ROUND-2: A Lite review found a BLOCKER and the owner fixed it. Does a round 2 re-check run?
CASE=STANDARD-R4-ROUND-2: A Standard R4 review found a MAJOR and the owner fixed it. Does a round 2 re-check run?
CASE=R2-R3-ROUND-2: An R2/R3 review found a BLOCKER and the owner fixed it. Does a round 2 re-check run?
CASE=MINOR-ONLY: A review found only MINOR findings and the author fixed them. Does a round 2 re-check run?
