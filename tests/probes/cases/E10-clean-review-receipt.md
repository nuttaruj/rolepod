skill: convening-code-review
expect: CASE=CLEAN\s+VERDICT=APPROVED\s+ROUND=COMPLETE
expect: CASE=FINDINGS\s+VERDICT=REJECTED\s+ROUND=COMPLETE
expect: CASE=PARTIAL\s+VERDICT=PARTIAL\s+ROUND=OPEN
expect: CASE=MISSING-COVERAGE\s+VERDICT=PARTIAL\s+ROUND=OPEN
forbid: ^APPROVED$
forbid: infer clean from missing Findings section alone
forbid: duplicated findings in the return
forbid: "phase"[[:space:]]*:[[:space:]]*"review"
---
You are the Lead. Use only the skill text after `--- SKILL ---`; do not use tools. Classify each report receipt below. Return exactly four lines in the format `CASE=<id> VERDICT=<APPROVED|REJECTED|PARTIAL> ROUND=<OPEN|COMPLETE> REASON=<short evidence>`. ROUND says whether this review round's reports are complete, never whether later fixes are needed. Partial or missing coverage must be `VERDICT=PARTIAL ROUND=OPEN`; do not emit a completed review line for either case.

CASE=CLEAN — Scope lists both changed files and frozen H1; Read says lens: spec, names both files, traces each claimed behavior through its caller, and says where both held; risk surfaces: None; Reviewers says round complete; limitation: none; Recommendation: APPROVED; report path exists.

CASE=FINDINGS — Scope and coverage are complete; Findings has one MAJOR at `src/a.py:12` with issue, impact, and fix direction; Recommendation: REJECTED; report path exists.

CASE=PARTIAL — Scope says `src/a.py` was skipped because the hunk was cut off; Read covers only `src/b.py`; Recommendation says APPROVED; report path exists.

CASE=MISSING-COVERAGE — Scope and H1 are present; Read says only `lens: standards` and names no changed files, behaviors, or trace paths; Findings omitted; Recommendation: APPROVED; report path exists.
