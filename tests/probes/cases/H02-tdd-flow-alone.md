skill: tdd-flow
expect: FIRST:.*([Ss]eam|applyDiscount)
expect: SEAM:.*applyDiscount
forbid: SEAM:.*_rate
forbid: FIRST:.*(implement|write the (code|function|fix)|change the code)
forbid: FIRST:.*([Tt]ests (for|covering)|several tests|all (the )?tests|edge|error case)
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the user's message was exactly: "do this test-first: orders over 100 get a 10% discount". The pricing module exposes one public function `applyDiscount(order)`; it calls a private helper `_rate(total)`. No other skill is loaded and no plan exists.

Question: what is your first concrete action, and where does the test go? Answer in this exact format:
FIRST: <the first action you take, per the skill>
SEAM: <where the test calls into the code>
QUOTE: <the one line from the skill that decided it>
