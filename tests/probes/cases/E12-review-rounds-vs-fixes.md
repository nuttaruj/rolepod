skill: review-code
expect: FULL-R4-ROUND-CAP:[* ]*4
expect: ROUND-1-INCLUDED:[* ]*YES
expect: FIX-ATTEMPTS-RESET:[* ]*NO
expect: LITE-ROUND-2:[* ]*NO
expect: STANDARD-R4-ROUND-2:[* ]*NO
expect: R2-R3-ROUND-2:[* ]*NO
forbid: FIX-ATTEMPTS-RESET:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Classify each case using only the skill. Return one line per case in this exact format:
CASE=<id> ANSWER=<value> REASON=<brief evidence>

CASE=FULL-R4-ROUND-CAP: A Full R4 review is still open after round 4.
CASE=ROUND-1-INCLUDED: Does the four-round cap include the initial review round?
CASE=FIX-ATTEMPTS-RESET: A new reviewer or owner starts another review round. Does that reset failed-fix attempts for the same unresolved criterion?
CASE=LITE-ROUND-2: A Lite review finds an open issue. Is an automatic round 2 authorized by the four-round cap?
CASE=STANDARD-R4-ROUND-2: A Standard R4 review finds an open issue. Is an automatic round 2 authorized by the four-round cap?
CASE=R2-R3-ROUND-2: An R2/R3 review finds an open issue. Is an automatic round 2 authorized by the four-round cap?

Answer the separate failure-policy cases using this exact format:
ATTEMPT=<n> SECOND-OPINION=<YES | NO> ACTION=<brief next step>

Situation: one unresolved repro has failed twice, including attempts from a previous owner. What happens next?
Situation: Second opinion ran once; attempt three failed after a fresh trace. What happens before attempt four?
Situation: the advisor is unavailable after two failures. May you attempt a third fix?
Situation: attempt four failed. What happens next?

Do not treat a review rejection as a failed fix. Do not infer that the round cap authorizes extra rounds in Lite, Standard, R2 or R3. Review-round and failed-fix counts are separate and carry across ownership changes.
