skill: review-code
expect: DIFF-SOURCE:[*` ]*git diff HEAD
expect: AXES:[* ]*both
expect: SMELL-LINE-PER-FILE:[* ]*YES
expect: HASH-IN-SCOPE:[* ]*YES
expect: ENDING:[* ]*REPORT-TO-USER
expect: FIX-IT:[* ]*NO
expect: FINAL:[* ]*STOP
forbid: FIX-IT:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.
Situation: the user wrote exactly "review my uncommitted changes" in a repo whose plan file still has unchecked tasks. There is no brief, no orderer and no spec file; the user earlier said the goal is "add CSV export for orders". Assume the review found one MAJOR and one MINOR.
Question: how do you take the diff, which axes do you walk, how do you walk the standards axis, and how do you end? Answer in this exact format:
DIFF-SOURCE: <the command that gives you the diff>
AXES: both | spec only | standards only
SMELL-LINE-PER-FILE: YES | NO
HASH-IN-SCOPE: YES | NO
ENDING: REPORT-TO-USER | RETURN-TO-ORDERER
FIX-IT: YES | NO
FINAL: STOP | CONTINUE → <skill or action>
QUOTE: <the one line from the skill that decided it>
