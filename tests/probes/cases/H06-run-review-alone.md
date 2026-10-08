skill: convening-code-review
expect: SECURITY-ENGINEER:[* ]*YES
expect: LENS-PAIR:[* ]*YES
expect: ADVERSARIAL:[* ]*NO
expect: FIX-BEFORE-ALL-REPORTS:[* ]*NO
expect: MAX-ROUNDS:[* ]*4
forbid: ADVERSARIAL:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: a standalone run with no plan and no brief. The session carries active mode Standard. The uncommitted diff changes the session-token refresh in `src/auth/refresh.ts`, a high-risk path. This CLI can dispatch the `universal-reviewer` and `security-engineer` roles. No cross-family pool is configured.

Question: what does round 1 contain, and when may fixing start? Answer in this exact format:
SECURITY-ENGINEER: YES | NO
LENS-PAIR: YES | NO
ADVERSARIAL: YES | NO
FIX-BEFORE-ALL-REPORTS: YES | NO
MAX-ROUNDS: <the most review rounds, round 1 included>
QUOTE: <the one line from the skill that decided it>
