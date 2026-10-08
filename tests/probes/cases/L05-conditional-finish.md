skill: finish-work
expect: ^LITE-R4: REQUIRED=TWO-LENSES; SECURITY=NO; ADVERSARIAL=NO[[:space:]]*$
expect: ^STANDARD-R4: REQUIRED=SECURITY-ENGINEER\+TWO-LENSES; ADVERSARIAL=NO[[:space:]]*$
expect: ^FULL-R4: REQUIRED=SECURITY-ENGINEER\+TWO-LENSES\+ADVERSARIAL[[:space:]]*$
expect: ^MISSING-REPORT: COMPLETER=SAME-ISOLATED-REVIEWER; ROUND=SAME; SNAPSHOT=FROZEN-H1; LEAD-SUBSTITUTES=NO[[:space:]]*$
expect: ^ROUTINE-MERGE: LAUNCH-CHECKLIST=NO[[:space:]]*$
expect: ^GENUINE-LAUNCH: CHECKLIST=BEFORE-TRAFFIC; INFRASTRUCTURE=ONLY-WHEN-APPLICABLE[[:space:]]*$
expect: ^APPLICABLE-CHECK-MISSING: GATE=NO-GO[[:space:]]*$
expect: ^KEEP-OPEN: PUSH=NO; MERGE=NO; CLEANUP=NO; USER-PICK=NO[[:space:]]*$
forbid: ^STANDARD-R4: REQUIRED=.*ADVERSARIAL=YES
forbid: ^ROUTINE-MERGE: LAUNCH-CHECKLIST=YES
---
You are an AI coding agent with only the standalone skill below; no other skill, reference, file or tool is available. Answer exactly in this format and quote a deciding sentence verbatim from the skill for each group.

Situation variants:
1. High-risk R4 reports are checked in active Lite, Standard, then Full sessions.
2. In Lite, an assigned isolated lens reviewer returns an empty report; agents remain available.
3. A routine merge uses the existing production deploy pipeline. No first traffic, staged rollout, or migration is planned.
4. A genuine staged launch uses no feature flag and no database migration, but does require monitoring and an on-call owner.
5. One applicable launch safety check is still unverified.
6. The user explicitly says, "Keep this branch open for another task." The branch target is already known.

Use each label exactly. For review, launch, and finish, state required action, forbidden action, and whether a user pick remains. For MISSING-REPORT, explicitly state that the same isolated reviewer completes it in the same round on the same frozen H1; the Lead does not substitute.

LITE-R4: REQUIRED=<TWO-LENSES|OTHER>; SECURITY=<NO|YES>; ADVERSARIAL=<NO|YES>
STANDARD-R4: REQUIRED=<SECURITY-ENGINEER+TWO-LENSES|OTHER>; ADVERSARIAL=<NO|YES>
FULL-R4: REQUIRED=<SECURITY-ENGINEER+TWO-LENSES+ADVERSARIAL|OTHER>
MISSING-REPORT: COMPLETER=<SAME-ISOLATED-REVIEWER|OTHER>; ROUND=<SAME|OTHER>; SNAPSHOT=<FROZEN-H1|OTHER>; LEAD-SUBSTITUTES=<NO|YES>
ROUTINE-MERGE: LAUNCH-CHECKLIST=<NO|YES>
GENUINE-LAUNCH: CHECKLIST=<BEFORE-TRAFFIC|OTHER>; INFRASTRUCTURE=<ONLY-WHEN-APPLICABLE|ALWAYS>
APPLICABLE-CHECK-MISSING: GATE=<NO-GO|GO>
KEEP-OPEN: PUSH=<NO|YES>; MERGE=<NO|YES>; CLEANUP=<NO|YES>; USER-PICK=<NO|YES>
QUOTE: <verbatim sentence or quote each group>
TRACE: <cite the relevant numbered section or exact rule>
