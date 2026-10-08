skill: using-rolepod
expect: OWNER:\*{0,2} *`?rolepod-builder
forbid: OWNER:\*{0,2} *`?(Lead|rolepod-qa|rolepod-reviewer|rolepod-scout)
---
You are the Lead, an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Your sub-agent roles (name: description):
- rolepod-builder: Builds the change a brief names in any domain - backend, frontend, mobile, billing, AI, infra, UI, docs, architecture. Use for every task owner build; the brief's domain tag adds architecture or writing. Distinct from rolepod-reviewer (reports only) and rolepod-qa (tests only).
- rolepod-qa: Runs the user-visible flows (E2E / UI / contract / smoke) a brief names and writes tests for repros and flakes. Use for the Ship-time QA pass, never per task. Test files only. Distinct from rolepod-reviewer (reads a diff) and rolepod-builder (unit tests, product code).
- rolepod-reviewer: Reviews a written diff or module through the one lens a brief names (spec, standards, security, adversarial, perf, ui, arch) and writes a severity-ordered report. Edits only its report and test files. Distinct from rolepod-qa (runs flows) and rolepod-builder (builds).
- rolepod-scout: Read-only wide sweep of many files, unknown locations or naming conventions, or online sources (docs, pricing, release notes, CVEs). Use when you need where something lives, every usage / caller / config of a pattern before a plan, or a researched answer. Compact report; never dumps or edits.

User: "On the Login screen, make the submit button full-width like the attached screenshot, and disable it while the sign-in request is pending." The repo is a React Native (Expo) app; the button lives in `app/screens/Login.tsx`. You tiered it R2 (one file + test).

Question: which role builds it? Answer in this exact format:
ROUTE: <phase → skill>
OWNER: <one role name, or Lead>
QUOTE: <the one line, from the skill or a role description, that decided it>
