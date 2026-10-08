skill: orchestrating-plans
expect: TEMP FILE:\*{0,2} *NO
forbid: TEMP FILE:\*{0,2} *YES
forbid: --brief +[0-9<]
---
You are the Lead, an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the router tiered the request R2 (one file + test). There is no plan file anywhere; your whole plan is this inline chat checklist:
- Goal: `slugify()` in src/utils/slug.ts drops a trailing dash.
- Done when: a new case in src/utils/slug.test.ts passes and the old cases stay green.
- Command: `npx vitest run src/utils/slug.test.ts`
`plan-lint.sh` is installed. You are about to dispatch a `backend-developer` task owner on the main checkout.

Question: what do you send as the owner's brief? Answer in this exact format:
BRIEF: <what the brief is and how you produce it>
TEMP FILE: YES | NO   (do you write any plan file to produce it?)
QUOTE: <the one line from the skill that decided it>
