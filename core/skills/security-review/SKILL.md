---
name: security-review
description: The security lens's method — model the threat, walk the diff at the brief's depth, report each BLOCKER / MAJOR with an exploit scenario. Use directly only when the user asks for a security audit.
---

# Security Review

A diff or a system → a security verdict with severity-ranked findings at file:line, each BLOCKER / MAJOR with an exploit scenario and the repro that proves it.

### 1. Take the depth

- Depth comes from the brief. `depth: checklist` → one question under an Architecture heading, "Security concerns?" (secrets in code, basic input handling, an auth gate on an entry point); report any visible concern with a severity; trace nothing, look up no CVE, at most ~15 tool calls. `depth: full` → steps 2-5, and also check memory and performance leaks on the changed code. A brief naming no depth means full.
- An audit with no diff → the paths the brief names, read end to end.

Done when: the report's Read names the depth.

### 2. Model the threat (full depth)

- Fix the attacker and the compliance regime first: the brief names them; none named and no role card → audit against all three attackers (external user, authenticated user, insider) and say so in an `Assuming:` line.
- Trust boundaries: where untrusted data enters — a request, an upload, a webhook, an external API response, a queue message, LLM output, a local value another process writes. Trust follows who wrote a value, not which channel delivered it.
- Assets: what an attacker wants behind each boundary — credentials, PII, payment data, admin actions, money movement.
- STRIDE per boundary as a fast lens, not a ceremony: spoofing, tampering, repudiation, information disclosure, denial of service, elevation of privilege; one line per boundary, only the letters that apply.

Done when: every changed path is tied to a boundary and an asset, or named out of scope.

### 3. Walk the diff

- Trace each boundary to its asset through the changed code, card by card (your role's Objective & Focus; none → the OWASP Top 10 categories), and record where each claim held or failed.
- Prove a finding with a repro or a test inside the run scope the brief gives and name its command instead of pasting rerunnable logs; a step you inferred says so.

Done when: every boundary from step 2 has a traced result at file:line.

### 4. Grade and report

- Hard stops, each a REJECT:
  - A secret would land in code / log / response → REJECT.
  - An auth check is missing on a new endpoint → REJECT.
  - A user-controlled URL hits the internal network without an allowlist (SSRF) → REJECT.
  - Crypto rolled by hand → REJECT, use a library.
  - A token / cookie without `HttpOnly` / `Secure` / `SameSite` where required → REJECT.
  - The compliance regime is unstated and the change crosses regulatory scope → return `BLOCKED:` naming the regimes in play — a wrong guess can ship a breach.

{{INCLUDE: core/fragments/risk-paths.md}}

- Grade each finding CRITICAL / HIGH / MEDIUM / LOW and record it as BLOCKER (CRITICAL, HIGH) / MAJOR (MEDIUM) / MINOR (LOW); the axis is `security`.
- Every BLOCKER and MAJOR names an exploit scenario — who calls it, how, and what they get — and the repro or test that proves it, by command; a finding with no scenario is MINOR.
- Repro, the one exception to "trace, never run": `git worktree add --detach .worktrees/<task>-repro <head>`, write and run the repro test there, then `git worktree remove --force .worktrees/<task>-repro` before you return; never touch the reviewed tree (H1 unchanged) and never install a dependency there. It cannot run → attach the repro test text and mark the finding "repro not run".
- Your writes: the report, the security spec a billing / payments brief names (`security-spec: <path>`) before build, and test files only; product code that needs a change → a finding for the owner.
- Write the report to the file the brief names, default `.rolepod/evidence/review/<task>-security.md`; its Read section names the threat model, the compliance regime and the depth:

```markdown
{{INCLUDE: core/fragments/review-report.md}}
```

- A clean report still names the changed files and behaviors covered, the paths traced and where each claim held, the risk surfaces and the limitations; keep the depth-required trace even when clean, never a bare `APPROVED`, and never treat missing coverage as clean.

Done when: the report is written with a Recommendation and every BLOCKER / MAJOR carries its scenario and repro.

### 5. Closure proof

- A fix to a security finding closes only when the repro or test its report entry names passes on the fixed tree (H2): the author runs it and records the result in the finding's closure proof; a green suite alone closes nothing.

## Next phase

- Return the verdict, the report path and the counts by severity to whoever ordered the review, in at most 12 lines.
- Called alone (the user asked) → the report goes to the user, and each fix goes to the role that owns the code.
