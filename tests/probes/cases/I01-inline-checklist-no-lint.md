skill: implement-plan
expect: LINT:\*{0,2} *NO
expect: FIRST:\*{0,2} *[*`]*(Read|read|Run|run|Baseline|baseline|npx vitest)
forbid: LINT:\*{0,2} *YES
forbid: FIRST:.*(write-plan|plan-lint|temp)
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are the task owner of an R2 (one file + test) task. There is no plan file anywhere in the repo. Your whole brief is this inline chat checklist from the Lead:
- Goal: `paginate()` in src/utils/paginate.ts keeps the last item of the last page.
- Done when: a new case in src/utils/paginate.test.ts passes and the old cases stay green.
- Command: `npx vitest run src/utils/paginate.test.ts`
`plan-lint.sh` is installed.

Question: before your first edit, do you lint the plan, and what do you do first? Answer in this exact format:
LINT: YES | NO
FIRST: <the one concrete thing you do first>
QUOTE: <the one line from the skill that decided it>
