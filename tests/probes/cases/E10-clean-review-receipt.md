skill: review-code
expect: CASE=CLEAN\s+VERDICT=APPROVED
expect: CASE=FINDINGS\s+VERDICT=REJECTED
expect: CASE=PARTIAL\s+VERDICT=PARTIAL
expect: CASE=MISSING-COVERAGE\s+VERDICT=PARTIAL
forbid: ^APPROVED$
forbid: infer clean from missing Findings section alone
forbid: duplicated findings in the return
---
You are the Lead. Use only the skill text after `--- SKILL ---`; do not use tools. Classify each report receipt below. Return exactly four lines in the format `CASE=<id> VERDICT=<...> REASON=<short evidence>`.

CASE=CLEAN — Scope lists both changed files and frozen H1; Read says lens: spec, names both files, traces each claimed behavior through its caller, and says where both held; risk surfaces: None; Reviewers says round complete; limitation: none; Recommendation: APPROVED; report path exists.

CASE=FINDINGS — Scope and coverage are complete; Findings has one MAJOR at `src/a.py:12` with issue, impact, and fix direction; Recommendation: REJECTED; report path exists.

CASE=PARTIAL — Scope says `src/a.py` was skipped because the hunk was cut off; Read covers only `src/b.py`; Recommendation says APPROVED; report path exists.

CASE=MISSING-COVERAGE — Scope and H1 are present; Read says only `lens: standards` and names no changed files, behaviors, or trace paths; Findings omitted; Recommendation: APPROVED; report path exists.
