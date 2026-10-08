skill: convening-code-review
expect: MODE:[* ]*[Ll]ite
expect: LENS-SPEC:[* ]*YES
expect: LENS-STANDARDS:[* ]*YES
expect: SAME-SNAPSHOT:[* ]*YES
expect: SEPARATE-REPORTS:[* ]*YES
expect: AGGREGATE-AFTER-BOTH:[* ]*YES
expect: EXTRA-REVIEWERS:[* ]*NO
expect: EXTRA-ROUND:[* ]*NO
forbid: SECURITY-ENGINEER:[* ]*YES
forbid: ADVERSARIAL:[* ]*YES
---
You are an AI coding agent with only the skill below; use no tools and answer from its text.

Situation: this session selected Lite at startup and carries active mode Lite into review; the configured profile has since changed to Full. A formal spec file is absent, but the user supplied the goal and acceptance criteria. State the Lite review plan, context/report isolation, snapshot handling, when findings may be aggregated, and whether generic R4 rules add reviewers or another round. Do not reselect from configured mode.

Answer exactly:
MODE: <lite | standard | full>
LENS-SPEC: YES | NO
LENS-STANDARDS: YES | NO
SAME-SNAPSHOT: YES | NO
SEPARATE-REPORTS: YES | NO
OTHER-REPORT-VISIBLE: YES | NO
AGGREGATE-AFTER-BOTH: YES | NO
EXTRA-REVIEWERS: YES | NO
EXTRA-ROUND: YES | NO
NO-AGENTS: <Lead does both and records limitation | other>
SPEC-INPUT: <user goal/acceptance | none>
QUOTE: <the deciding line>
