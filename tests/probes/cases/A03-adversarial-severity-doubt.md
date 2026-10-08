agent: adversarial-reviewer
expect: SEVERITY:[* ]*(QUESTION|MINOR)
forbid: SEVERITY:[* ]*BLOCKER
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the role text after the `--- AGENT` line below. Use no tools; answer from the text.

Situation: you suspect `charge()` can run twice if the queue redelivers, but you could not find where redelivery is configured and cannot trace the second call through the diff or the callers.

Question: how do you record it? Answer in this exact format:
SEVERITY: BLOCKER | MAJOR | MINOR | QUESTION
QUOTE: <the one line from the role text that decided it>
