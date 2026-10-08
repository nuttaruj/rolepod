skill: convening-code-review
expect: SCANNER-IN-BRIEF:[* ]*YES
expect: RULES-IN-BRIEF:[* ]*YES
forbid: SCANNER-IN-BRIEF:[* ]*NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL` line below. Use no tools; answer from the text.

Situation: an R4 money diff is ready for round 1. The repo already has a script `pnpm audit:security` that runs a local secret scan and a security lint. Its CLAUDE.md has a section "Security rules" (parameterized queries only, no secrets in code, authorization check on every endpoint). You are about to brief `security-engineer`.

Question: what does its brief carry beyond the diff? Answer in this exact format:
SCANNER-IN-BRIEF: YES | NO
RULES-IN-BRIEF: YES | NO
QUOTE: <the one line from the skill that decided it>
