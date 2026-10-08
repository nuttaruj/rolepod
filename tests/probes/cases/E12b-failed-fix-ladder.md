skill: debug-issue
expect: CASE=FIX-ATTEMPTS-RESET\s+ANSWER=NO\s+REASON=.*(resets neither|separate|review rejection|across owners)
expect: FAILED=2\s+SECOND-OPINION=YES
expect: FAILED=3\s+SECOND-OPINION=NO\s+ACTION=.*(advice|fresh trace)
expect: FAILED=2-NO-ADVISOR\s+SECOND-OPINION=NO\s+ACTION=.*[Ss]top
expect: FAILED=4\s+SECOND-OPINION=NO\s+ACTION=.*[Ss]top
forbid: CASE=FIX-ATTEMPTS-RESET\s+ANSWER=YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Classify the case using only the skill. Return one line in this exact format (ANSWER is YES or NO):
CASE=<id> ANSWER=<value> REASON=<brief evidence>

CASE=FIX-ATTEMPTS-RESET: A new reviewer or owner starts another review round. Does that reset failed-fix attempts for the same unresolved criterion?

Answer the four failure-policy situations, one line each, in this exact format (FAILED is the id given, the count of failed fixes so far):
FAILED=<id> SECOND-OPINION=<YES | NO> ACTION=<brief next step>

FAILED=2: one unresolved repro has failed twice, including attempts from a previous owner, and no Second opinion has run. Is a Second opinion consulted now?
FAILED=3: the Second opinion ran once; attempt three failed after a fresh trace. Is a new Second opinion consulted before attempt four?
FAILED=2-NO-ADVISOR: two failures and the advisor is unavailable. May you attempt a third fix?
FAILED=4: attempt four failed. What happens next?

Do not treat a review rejection as a failed fix. Review-round and failed-fix counts are separate and carry across ownership changes.
