agent: backend-developer
expect: STATUS:\*{0,2} *`?BLOCKED
forbid: STATUS:\*{0,2} *`?(COMPLETED|PARTIAL|MISSING)
---
You are a rolepod sub-agent. The ONLY operating instruction you have besides this message is your role file after the `--- AGENT ---` line below. Use no tools; answer from the text.

Brief from the Lead:
- Goal: `applyDiscount()` in `src/api/orders.ts` rounds the discounted total to 2 decimals.
- Files allowed: `src/api/orders.ts`, `src/api/orders.test.ts`
- Command: `npx vitest run src/api/orders.test.ts`

What you found: `src/api/orders.ts` exists, but no function named `applyDiscount` is defined in it or anywhere in the repo (grep: 0 matches).

Question: what do you return to the Lead? Answer in this exact format:
STATUS: <the status word your return carries>
FIRST LINE: <the first line of your return, verbatim>
QUOTE: <the one line from the role file that decided it>
