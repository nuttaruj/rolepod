skill: orchestrating-plans
expect: NEXT SKILL:\*{0,2} *`?convening-code-review
forbid: NEXT SKILL:.*(finish-work|implement-plan)
---
You are the Lead, an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the user asked you to fix a rounding bug in `src/billing/format.ts`. The router tiered it R2 (one file + test); there is no plan file, only your 3-line inline checklist. A task owner built it on main, its Command went green, and it dispatched its two `universal-reviewer` lenses (spec, standards): both clean, reports under `.rolepod/evidence/review/`. You committed. Then you ran `check-work`: the module suite failed on a case the change broke. `debug-issue` fixed it with a 7-line logic change in the same file, and you committed that. You just ran `check-work` again: every check passed and your evidence block ends with `Status: VERIFIED`.

Question: which skill runs next? Answer in this exact format:
NEXT SKILL: <convening-code-review | finish-work | implement-plan | debug-issue | other>
WHY: <one sentence>
QUOTE: <the one line from the skill that decided it>
