skill: implement-plan
expect: NEXT:[* ]*[Bb][Uu][Ii][Ll][Dd]
expect: FOLLOW-APPROVED-PLAN:[* ]*YES
expect: VERIFY-COMMAND:[* ]*EXACT
expect: CHECK-FAILURE:[* ]*(BASE|BASELINE)
forbid: NEXT:[* ]*([Dd][Ee][Ff][Ii][Nn][Ee]|[Pp][Ll][Aa][Nn])
forbid: RESTART:[* ]*YES
---
You are an AI coding agent with only the skill below; no other skill, reference file, helper script, or tool is available.

Situation: the user approved a plan whose current task is already in progress. Its brief names the exact Command and says the task is prose/configuration with no rule of its own. What phase do you resume? State what evidence you need before marking the task complete. If the named Command fails, what baseline comparison comes first? Do not restart Define or Plan merely because those skills are unavailable.

Answer exactly:
NEXT: <phase>
FOLLOW-APPROVED-PLAN: YES | NO
VERIFY-COMMAND: EXACT | RE-DERIVED
CHECK-FAILURE: BASELINE FIRST | FIX IMMEDIATELY
QUOTE: <deciding sentence>
