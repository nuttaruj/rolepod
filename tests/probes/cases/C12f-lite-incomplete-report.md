skill: convening-code-review
expect: SAME-ROUND:[* ]*YES
expect: SAME-FROZEN-DIFF:[* ]*YES
expect: ISOLATED-REVIEWER-COMPLETES:[* ]*YES
expect: LEAD-SUBSTITUTION:[* ]*NO
expect: AGGREGATE:[* ]*AFTER-COMPLETE
expect: SECOND-ROUND:[* ]*NO
---
You are an AI coding agent with only the skill below; use no tools and answer from its text.

Situation: in Lite, two fresh reviewers received the same frozen H1 diff in parallel. The spec-lens reviewer returned a full report; the standards-lens reviewer returned an empty message. Agents are available. What happens next? Does the Lead replace the missing report, start another review round, or wait for that isolated reviewer to finish its report on H1? When may findings be aggregated?

Answer exactly:
SAME-ROUND: YES | NO
SAME-FROZEN-DIFF: YES | NO
ISOLATED-REVIEWER-COMPLETES: YES | NO
LEAD-SUBSTITUTION: YES | NO
AGGREGATE: AFTER-COMPLETE | NOW
SECOND-ROUND: YES | NO
QUOTE: <deciding sentence>
