skill: adversarial-review
expect: FINDINGS:[* ]*NONE
forbid: FINDINGS:[* ]*(SOME|PADDED)
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: you are the adversarial pass on an R4 diff. After tracing every claimed behavior, retry, partial failure and concurrent path through the diff and its tests, you found nothing that fails.

Question: what does your report say about findings? Answer in this exact format:
FINDINGS: NONE | SOME | PADDED
QUOTE: <the one line from the skill text that decided it>
