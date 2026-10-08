skill: write-plan
expect: WHERE:.*High-risk surfaces
expect: LINE:.*(Task 2|T2)
forbid: WHERE:.*Reviewer
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are writing the plan artifact for an approved spec. The spec's High-risk surfaces section lists "session-cookie validation (auth)". Task 2 edits `src/lib/request-guard.ts` and its test to add that validation. Nothing in that path looks like a risk path (no auth / token / security word), and the repo has no risk-paths override. Task 2's owner will receive only the brief generated from the plan, never the plan file.

Question: where in the plan do you record that Task 2 touches this high-risk surface, so the owner's brief routes a `security-engineer` review? Answer in this exact format:
WHERE: <the plan section or task field you write it in>
LINE: <the exact line you write there>
QUOTE: <the one line from the skill that decided it>
