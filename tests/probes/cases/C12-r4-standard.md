skill: convening-code-review
expect: MODE:[* ]*standard
expect: ADVERSARIAL:[* ]*NO
expect: SECURITY-ENGINEER:[* ]*YES
expect: ROUND2:[* ]*NO
forbid: ADVERSARIAL:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: an R4 money diff is ready for round 1. `workflow-mode.sh` printed `standard`.

Question: what does round 1 contain? Answer in this exact format:
SECURITY-ENGINEER: YES | NO
LENS-PAIR: YES | NO
ADVERSARIAL: YES | NO
ROUND2: YES | NO
MODE: <lite | standard | full>
QUOTE: <the one line from the skill that decided it>
