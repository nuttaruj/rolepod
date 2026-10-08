skill: coordinating-parallel-tracks
expect: DISPATCH:.*(ONE|one|single) message
expect: TASK4:.*merge
forbid: DISPATCH:.*Task 4
---
You are an AI coding agent acting as the Lead. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: an approved plan has `## Tracks`: A — Task 1, Task 2; B — Task 3. Task 4 is Blocked by Task 2 and Task 3. Parallel agents and worktrees are available; no other session holds a lock on the base checkout. No task has started.

Question: what do you dispatch first, and when does Task 4 start? Answer in this exact format:
DISPATCH: <what goes out first, and in how many messages>
TASK4: <when and where Task 4 starts>
QUOTE: <the one line from the skill that decided it>
