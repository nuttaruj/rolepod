skill: review-code
expect: CLEAN=APPROVED; FINDINGS=REJECTED; PARTIAL=PARTIAL; MISSING-COVERAGE=PARTIAL
forbid: bare APPROVED; infer clean from missing Findings section alone; report duplicated findings in the return
---
You are the Lead. Use only the skill text after `--- SKILL ---`; do not use tools. Classify each report receipt below. Return exactly four lines in the format `CASE=<id> VERDICT=<...> REASON=<short evidence>`.

The compact report schema stores scope, immutable snapshot, reviewer lens/role, coverage/read trace, limitations, and verdict once. Empty optional sections may be omitted. A clean report must name changed files and behaviors covered, trace paths and where claims held, risk surfaces, and limitations. A bare APPROVED or missing coverage is never clean. The return is at most 12 lines with verdict, written report path, counts, and any limitation/action needing a decision; it does not repeat findings. If no tool can write the report, provide all evidence inline even above 12 lines, and never claim an unwritten path. Findings retain severity, file:line, impact, and fix direction.

CASE=CLEAN — Scope lists both changed files and frozen H1; Read says lens: spec, names both files, traces each claimed behavior through its caller, and says where both held; risk surfaces: None; Reviewers says round complete; limitation: none; Recommendation: APPROVED; report path exists.

CASE=FINDINGS — Scope and coverage are complete; Findings has one MAJOR at `src/a.py:12` with issue, impact, and fix direction; Recommendation: REJECTED; report path exists.

CASE=PARTIAL — Scope says `src/a.py` was skipped because the hunk was cut off; Read covers only `src/b.py`; Recommendation says APPROVED; report path exists.

CASE=MISSING-COVERAGE — Scope and H1 are present; Read says only `lens: standards` and names no changed files, behaviors, or trace paths; Findings omitted; Recommendation: APPROVED; report path exists.

Required classifications: CLEAN is APPROVED because evidence is complete. FINDINGS is REJECTED with one finding. PARTIAL and MISSING-COVERAGE are PARTIAL, never clean, because evidence is incomplete. Do not repeat the finding in the reply or replace coverage with the verdict.
