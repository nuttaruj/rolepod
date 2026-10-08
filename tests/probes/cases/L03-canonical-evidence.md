skill: check-work
expect: ^PLANNED: RECEIPT=NAMED; COMMAND=YES; COMMAND-OUTPUT=(YES|PROOF-LINES); CHECKOUT-SNAPSHOT=YES; RESULT=YES; COMPLETE=YES[[:space:]]*$
expect: ^VERIFY-ONLY: RETURN=EVIDENCE-BLOCK-ONLY; STOP=YES[[:space:]]*$
expect: ^NO-FILE: RECEIPT=NONE; INLINE=YES; COMMAND=YES; COMMAND-OUTPUT=YES; CHECKOUT-SNAPSHOT=YES; RESULT=YES[[:space:]]*$
expect: ^STALE-IGNORED-INPUT: RERUN=CURRENT-INPUTS; COMPLETE=NO-UNTIL-FRESH-PROOF[[:space:]]*$
expect: ^FAILED-CHECK: BASELINE=COMPARE-AGAINST-BASE-TREE; COMPLETE=NO[[:space:]]*$
forbid: NO-FILE: I wrote the receipt
forbid: FAILED-CHECK: fix it before comparing against the base
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

TASK (this is the whole task; nothing else is missing): classify the five situation variants below against the skill, in the exact format below, and quote a deciding sentence verbatim from the skill.

Situation variants:
1. A planned task names a canonical receipt and a passing check whose tracked, untracked, and ignored inputs still match.
2. The user asks only whether a change works; no saved artifact was requested.
3. No file-writing tool is available, but you have the exact command result and evidence fields.
4. An ignored input read by a previously passing check changed after that run.
5. A check fails on the changed tree; its baseline status is unknown.

Use each label exactly. For each, say what you do, what you record, and whether verification is complete. In PLANNED, explicitly name command output and checkout/snapshot among receipt fields. Use the exact phrase `evidence block only` for Verify-only and `compare against the base tree` for the unknown-baseline failure. In STALE-IGNORED-INPUT, explicitly say to rerun the check against current inputs. In NO-FILE, explicitly say `No receipt written` and report fields inline. Do not claim to have written a file when you cannot.

Output plain text only: no bold, no bullets, no markdown; each label line below stands alone at the start of its own line, filled in with the allowed values only (no extra words on it).

PLANNED: RECEIPT=NAMED; COMMAND=YES; COMMAND-OUTPUT=<YES|PROOF-LINES|NO>; CHECKOUT-SNAPSHOT=YES; RESULT=YES; COMPLETE=<YES|NO>
VERIFY-ONLY: RETURN=EVIDENCE-BLOCK-ONLY; STOP=YES
NO-FILE: RECEIPT=NONE; INLINE=YES; COMMAND=YES; COMMAND-OUTPUT=YES; CHECKOUT-SNAPSHOT=YES; RESULT=YES
STALE-IGNORED-INPUT: RERUN=CURRENT-INPUTS; COMPLETE=NO-UNTIL-FRESH-PROOF
FAILED-CHECK: BASELINE=COMPARE-AGAINST-BASE-TREE; COMPLETE=NO
QUOTE: <verbatim deciding sentence>
TRACE: <cite the relevant numbered section or exact rule>
