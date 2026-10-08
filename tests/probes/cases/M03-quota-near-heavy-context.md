skill: manage-context
expect: COMPACT:[* ]*NO
expect: STEP ?[123]:.*([Hh]andoff|brief)
forbid: COMPACT:[* ]*YES
forbid: STEP ?[123]:.*/compact
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are the Lead, running Claude Code, on `docs/rolepod/plans/billing-export.md`. Task 3 of 6 just landed and its commit is in — a milestone at a clean seam. The context bar is red and an auto-compaction warning is showing. The CLI also shows the usage quota at 88% of this window, resetting in 3 hours; at the current rate about 40 minutes of work remain. No task is half done.

Question: list the steps you take, in order, before any more plan work. Answer in this exact format:
STEP1: <first step>
STEP2: <second step>
STEP3: <third step, or none>
COMPACT: YES | NO   (does any step run /compact?)
QUOTE: <the one line from the skill that decided it>
