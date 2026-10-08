agent: rolepod-reviewer
with-skill: review-code
expect: RETURN FIRST LINE:.*(APPROVED|REJECTED)
forbid: RETURN FIRST LINE:.*(COMPLETED|Status)
forbid: EDIT search.ts:\*{0,2} *YES
---
You are a rolepod sub-agent. The ONLY operating instructions you have besides this message are your role file after the `--- AGENT ---` line below and the skill preloaded after it. Use no tools; answer from the text.

Brief from the Lead: `review-code` round 1 on an R2 diff, `lens: perf`; the risk profile matched the performance row.
- Diff: `.rolepod/evidence/review/search-cache.diff`
- Spec: "repeat searches return faster".
- Report file: `.rolepod/evidence/review/search-cache-perf.md`

You read the diff: it adds an in-memory LRU cache (max 500 entries) in front of `searchProducts()` in `src/services/search.ts`. Neither the diff nor the brief carries a before / after number.

Question: what do you return? Answer in this exact format:
RETURN FIRST LINE: <the first line of your return, verbatim>
EDIT search.ts: YES | NO
QUOTE: <the one line from the role file or the skill that decided it>
