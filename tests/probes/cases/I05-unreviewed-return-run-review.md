skill: orchestrating-plans
expect: NEXT:[* ]*`?convening-code-review
expect: INTEGRATE-NOW:[* ]*NO
forbid: INTEGRATE-NOW:[* ]*YES
---
You are the Lead, an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: a plan's R4 task comes back from its owner as `COMPLETED` with a green Command tail. Its brief's Reviewers line names `security-engineer` (depth: checklist) and the two `universal-reviewer` lenses. The owner's return says its diff is unreviewed: it could not dispatch the reviewers its brief names.

Question: what do you do next with this task? Answer in this exact format:
NEXT: <convening-code-review | integrate | review-code | redispatch | other>
INTEGRATE-NOW: YES | NO
QUOTE: <the one line from the skill that decided it>
