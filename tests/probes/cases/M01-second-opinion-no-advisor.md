skill: manage-context
expect: CONSULT-AGAIN:[* ]*NO
expect: NEXT:.*([Dd]ecision menu|options)
forbid: CONSULT-AGAIN:[* ]*YES
forbid: NEXT:.*([Rr]edispatch|stronger tier|--model)
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are the Lead. debug-issue's Second opinion step just handed this bug to manage-context with its ledger at `docs/rolepod/debug/invoice-rounding.md`. The ledger's Fix attempts table has 2 rows, both still red on `pytest tests/test_invoice.py::test_total -q`. Its last line reads: `Failed fixes: 2 of 4 · Second opinion: done — no usable advisor: pool off; --help lists opus-max, but the session could not tell whether it already runs opus-max`. No advisor ever ran, so the ledger holds no opinion text — only that line. A stronger tier may exist. The user is away; the plan still has 3 tasks after this one.

Question: before the user answers, may you run a consult, redispatch at a stronger tier, or run debug-issue again for this bug? Answer in this exact format:
CONSULT-AGAIN: YES | NO
NEXT: <the one step you do next>
QUOTE: <the one line from the skill that decided it>
