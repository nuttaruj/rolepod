skill: security-review
expect: TRUST-BOUNDARY:[* ]*YES
forbid: TRUST-BOUNDARY:[* ]*NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: you review a diff at `depth: full`. A worker reads `/var/run/jobs/next.json`, a file a separate cron job writes, and passes its `path` field to `fs.readFile`. The file lives on the same machine, so the author calls it trusted.

Question: is that file a trust boundary? Answer in this exact format:
TRUST-BOUNDARY: YES | NO
QUOTE: <the one line from the skill text that decided it>
