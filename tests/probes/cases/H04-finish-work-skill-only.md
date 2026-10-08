skill: finish-work
expect: ACTION:[* ]*KEEP OPEN
expect: PREPARE:[* ]*(CHECK|GATE)
expect: PUSH:[* ]*NO
expect: ASK-AGAIN:[* ]*NO
forbid: ACTION:[* ]*(MERGE|PR)
---
You are an AI coding agent with only the skill below; no other skill, reference file, helper script, or tool is available.

Situation: implementation, verification and review are complete. The user explicitly said: "Keep this branch open for another task." The branch is already on its task branch. State the authorized finish action, the gate you still inspect before checkpointing, whether this instruction authorizes a push or merge, and whether you ask the user to pick again. Use only procedures in this skill.

Answer exactly:
ACTION: <KEEP OPEN | MERGE | PR>
PREPARE: <CHECK THE PRE-MERGE GATE | NONE>
PUSH: YES | NO
ASK-AGAIN: YES | NO
QUOTE: <deciding sentence>
