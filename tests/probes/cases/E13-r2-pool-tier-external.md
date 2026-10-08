skill: convening-code-review
expect: UNIVERSAL-REVIEWER:[* ]*YES
expect: EXTERNAL:[* ]*NO
forbid: EXTERNAL:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are the Lead, running Claude Code. A standalone R2 task (one file + its test, ~25 logic lines in `src/export/csv.ts`, no high-risk path, no perf / UI / architecture concern) is built, its test is green and the change is uncommitted. The spec for it exists. The machine's `~/.rolepod/config.json` has `pool` with `cross-family` on, lists `codex` and sets `tier` R2; `cross-family.sh --pool` shows codex usable, and the `cross-family` skill is installed. You are at Pick reviewers.

Question: which reviewers do you dispatch in round 1? Answer in this exact format:
REVIEWERS: <every reviewer dispatched in round 1>
UNIVERSAL-REVIEWER: YES | NO   (is any universal-reviewer lens dispatched in round 1?)
EXTERNAL: YES | NO   (is the cross-family external dispatched in round 1?)
QUOTE: <the one line from the skill that decided it>
