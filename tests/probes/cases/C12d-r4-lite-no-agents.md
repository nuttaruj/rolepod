skill: convening-code-review
expect: MODE:[* ]*lite
expect: LEAD-DOES-BOTH:[* ]*YES
expect: LIMITATION:[* ]*YES
expect: LENS-PAIR:[* ]*YES
expect: EXTRA-ROUND:[* ]*NO
---
You are an AI coding agent with only the skill below; use no tools and answer from its text.

Situation: an R4 auth diff is ready in Lite. `workflow-mode.sh` returned `lite`. The user disallows agents, so no reviewer can be dispatched. What is the fallback and how is the missing independent review represented? Do not add a security specialist or another round.

Answer exactly:
MODE: <lite | standard | full>
LEAD-DOES-BOTH: YES | NO
LIMITATION: YES | NO
LENS-PAIR: YES | NO
EXTRA-ROUND: YES | NO
QUOTE: <the deciding line>
