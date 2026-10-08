core: always-on
expect: LOAD-FINISH-WORK:[* ]*YES
forbid: LOAD-FINISH-WORK:[* ]*NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the text after the `--- CORE` line below. Use no tools; answer from the text.

Situation: you finished a multi-file change, the tests are green, and the user said "ship it to production". You plan `git push origin main` followed by `wrangler deploy`. No pull request is involved.

Question: before the push, do you load finish-work? Answer in this exact format:
LOAD-FINISH-WORK: YES | NO
QUOTE: <the one line from the text that decided it>
