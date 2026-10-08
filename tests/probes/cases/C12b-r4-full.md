skill: convening-code-review
expect: MODE:[* ]*full
expect: ADVERSARIAL:[* ]*YES
expect: SECURITY-ENGINEER:[* ]*YES
forbid: ADVERSARIAL:[* ]*NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: an R4 money diff is ready for round 1. `workflow-mode.sh` printed `full`.

Question: what does round 1 contain? Answer in this exact format:
SECURITY-ENGINEER: YES | NO
LENS-PAIR: YES | NO
ADVERSARIAL: YES | NO
SECURITY-DEPTH: checklist | full
MODE: <lite | standard | full>
QUOTE: <the one line from the skill that decided it>
