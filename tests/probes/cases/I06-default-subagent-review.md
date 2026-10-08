skill: implement-plan
expect: REVIEWER:[* ]*DEFAULT-SUBAGENT
expect: LENSES:[* ]*2
forbid: REVIEWER:[* ]*(NONE|SELF)
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you built an R2 change yourself (one source file plus its test) and its Command is green. `convening-code-review` is installed. This CLI can start default sub-agents, but it has no custom agent roles: no `universal-reviewer` role exists.

Question: who reviews the diff in round 1? Answer in this exact format:
REVIEWER: UNIVERSAL-REVIEWER-ROLE | DEFAULT-SUBAGENT | SELF | NONE
LENSES: <number of lenses dispatched>
QUOTE: <the one line from the skill that decided it>
