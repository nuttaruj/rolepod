skill: convening-code-review
expect: SCANNER-IN-BRIEF:[* ]*NO
expect: RULES-IN-BRIEF:[* ]*NO
forbid: SCANNER-IN-BRIEF:[* ]*YES
forbid: RULES-IN-BRIEF:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: an R4 money diff is ready for round 1. The repo has no security scanner, no audit script and no security rules anywhere in its CLAUDE.md or docs. You are about to brief `security-engineer`.

Question: do you add a scanner result or a security rules checklist to its brief, or invent one? Answer in this exact format:
SCANNER-IN-BRIEF: YES | NO
RULES-IN-BRIEF: YES | NO
QUOTE: <the one line from the skill that decided it>
