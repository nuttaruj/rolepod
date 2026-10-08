skill: finish-work
expect: MODE:[* ]*lite
expect: H1-IMMUTABLE:[* ]*YES
expect: H2-CLOSURE:[* ]*YES
expect: FIX-EVIDENCE:[* ]*YES
expect: DELTA-PROVENANCE:[* ]*YES
expect: REUSE-COVERED-H2:[* ]*YES
expect: NEW-REVIEWER-H2:[* ]*NO
expect: H1-RELABEL:[* ]*NO
expect: H3-REUSE:[* ]*NO
expect: SCOPE-CHANGE:[* ]*SURFACE-AND-ROUTE
expect: GREEN-ALONE:[* ]*NO
forbid: NEW-REVIEWER-H2:[* ]*YES
forbid: H1-RELABEL:[* ]*YES
---
You are an AI coding agent with only the skill below; use no tools and answer from its text.

Situation: Lite R4 review finished on frozen snapshot H1. The two isolated lens reports are immutable, match H1, and identify finding F1. The author fixes only F1, adds a repro test that failed on H1 and passes on the fix, records changed paths and the exact bounded H1→H2 delta hash, and `check-work` verifies clean tree H2. Can Finish work reuse H1 plus this closure evidence without another reviewer? Then suppose unrelated file H3 changes after H2. Is H3 covered by H1 or the F1 closure? State required handling. A passing full suite alone is not the F1 proof.

Answer exactly:
MODE: <lite | standard | full>
H1-IMMUTABLE: YES | NO
H2-CLOSURE: YES | NO
FIX-EVIDENCE: YES | NO
DELTA-PROVENANCE: YES | NO
REUSE-COVERED-H2: YES | NO
NEW-REVIEWER-H2: YES | NO
H1-RELABEL: YES | NO
H3-REUSE: YES | NO
SCOPE-CHANGE: SURFACE-AND-ROUTE | OTHER
GREEN-ALONE: YES | NO
QUOTE: <the deciding line>
