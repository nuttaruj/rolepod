skill: review-code
expect: CASE=ATTEMPT-LEAVES-DEFECT\s+ANSWER=NOT-ADDRESSED
expect: CASE=PUSHBACK-REASON-HOLDS\s+ANSWER=HELD
expect: CASE=NEW-BREAK-IN-DELTA\s+ANSWER=OPEN-LIST
expect: CASE=BREAK-OUTSIDE-DELTA\s+ANSWER=FOLLOW-UPS
expect: CASE=EXTRA-AXIS-REQUESTED\s+ANSWER=OUT-OF-SCOPE
forbid: CASE=BREAK-OUTSIDE-DELTA\s+ANSWER=OPEN-LIST
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.
You are the reviewer of a Fix-verify re-check: your brief gives you the fix delta H1→H2 and the round-1 report. Classify each case using only the skill. Return one line per case in this exact format (ANSWER is one of NOT-ADDRESSED, ADDRESSED, HELD, REOPENED, OPEN-LIST, FOLLOW-UPS, OUT-OF-SCOPE):
CASE=<id> ANSWER=<value> REASON=<brief evidence>
CASE=ATTEMPT-LEAVES-DEFECT: A BLOCKER's fix edits the right function, but the delta still lets the null id through.
CASE=PUSHBACK-REASON-HOLDS: The owner pushed back on a MAJOR with a reason that the code at H2 confirms.
CASE=NEW-BREAK-IN-DELTA: The delta introduces an unchecked array index on a line the fix added.
CASE=BREAK-OUTSIDE-DELTA: You notice an old N+1 query in a file the delta does not touch.
CASE=EXTRA-AXIS-REQUESTED: The brief also asks you to run the suite and add a performance walk.
