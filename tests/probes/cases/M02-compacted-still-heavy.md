skill: manage-context
expect: FIRST:.*([Rr]e-?anchor|[Pp]lan|git (log|status))
expect: THEN:.*([Hh]andoff|brief)
forbid: FIRST:[* ]*(Run |run )?`?/compact
forbid: THEN:.*[Rr]un (`?/compact|the trim|a trim)
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are the Lead, running Claude Code, 4 tasks into a 7-task plan at `docs/rolepod/plans/export.md`. The session just resumed from an auto-compaction summary, and the context bar is still yellow right after it. The summary says Task 5 is half done. You have run nothing since the resume.

Question: what do you do first, and what then about the heavy context? Answer in this exact format:
FIRST: <the one step you do first>
THEN: <the one step for the heavy context>
MODES: <the manage-context modes you run, in order>
QUOTE: <the one line from the skill that decided it>
