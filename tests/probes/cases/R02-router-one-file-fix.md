skill: using-rolepod
expect: TIER:\*{0,2} *R2
expect: FIRST SKILL:\*{0,2} *`?debug-issue
forbid: TIER:\*{0,2} *R[0134]
forbid: FIRST SKILL:.*(write-spec|implement-plan)
---
You are an AI coding agent working in a TypeScript repo. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the user's message was exactly: "fix the off-by-one in src/utils/paginate.ts — the last page drops its final item. The unit tests live in src/utils/paginate.test.ts." You have read both files: the bug is one comparison in one function (`<` should be `<=`), about 3 changed lines plus one new test case. The file handles list pagination only — nothing about auth, billing, data deletion or other high-risk paths.

Question: how do you route this request? Answer in this exact format:
TIER: <R0 | R1 | R2 | R3 | R4>
FIRST SKILL: <the skill that fires first, or none>
NEXT: <the one concrete thing you do next>
QUOTE: <the one line from the skill that decided it>
