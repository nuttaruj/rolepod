skill: using-rolepod
expect: spec-as-plan
expect: implement-plan
forbid: FIRST:.*write-plan
---
You are an AI coding agent invoked manually with only the skill below. No tools.

The user asks: "Implement the approved spec." The approved spec fully covers the requested change and has two ordered tasks. Every task names exact files, a verify command and dependencies. A single owner will do all work. There is no parallel work, high-risk surface, acceptance change or compaction.

Answer exactly:
TIER: <R3>
FIRST: <implement-plan>
NEXT: <use the approved tasks as the inline checklist; no plan artifact>
QUOTE: <the deciding eligibility rule>
