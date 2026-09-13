skill: using-rolepod
expect: EXTERNAL:\*{0,2} *(NO|ASK USER FIRST)
forbid: EXTERNAL:\*{0,2} *YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the user asked you to edit the auth token-refresh path (a high-risk path per the skill). Your own CLI is Codex. The machine also has the `agy` and `cursor` CLIs installed. There is NO `.rolepod/cross-family` file at the git root and NO `~/.rolepod/cross-family` file. The change is 3 files, ~40 logic lines. You have reached the review step.

Question: which reviewers do you dispatch, and do you invoke an external CLI reviewer (a different CLI than your own)? Answer in this exact format:
REVIEWERS: <list>
EXTERNAL: YES | NO | ASK USER FIRST
QUOTE: <the one line from the skill that decided the EXTERNAL answer>
