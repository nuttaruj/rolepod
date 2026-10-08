skill: convening-code-review
expect: ADVERSARIAL-SEAT:[* `]*rolepod-reviewer
expect: LENS:[* `]*adversarial
forbid: LENS:[* `]*(spec|standards|security)
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: an R4 diff changes `src/billing/refund.ts`. The session carries active mode Full. No cross-family pool is configured. This CLI can dispatch the `rolepod-reviewer` type, which takes one `lens:` per dispatch.

Question: who runs the adversarial pass? Answer in this exact format:
ADVERSARIAL-SEAT: <the type name>
LENS: <the lens value its brief names>
QUOTE: <the one line from the skill text that decided it>
