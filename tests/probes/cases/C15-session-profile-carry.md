skill: convening-code-review
expect: CURRENT:[* ]*lite
expect: REVIEWERS:[* ]*two isolated lenses
expect: PLAN-LINT:[* ]*lite
expect: FRESH-STARTUP:[* ]*full
expect: REREAD:[* ]*no
forbid: PLAN-LINT:[* ]*full
---
You are an AI coding agent with only the skill below; use no tools and answer from its text.

Situation: this session selected Lite at startup. After compaction, the current summary still carries active mode Lite, but configured `workflow.mode` has since changed to Full. You reloaded this skill and must finish the current R4 review, then invoke plan-lint for its owner brief. The native helper environment is not guaranteed, so you can pass the carried session mode/source. Later, a genuinely fresh session starts while config remains Full.

Answer exactly:
CURRENT: <lite | standard | full>
REVIEWERS: <two isolated lenses | standard R4 set | full R4 set>
PLAN-LINT: <lite | standard | full>
FRESH-STARTUP: <lite | standard | full>
REREAD: yes | no
QUOTE: <the deciding line>
