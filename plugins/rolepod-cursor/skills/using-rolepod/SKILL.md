---
name: using-rolepod
description: Use at the start of every request to route work into Rolepod's workflow spine before planning, editing, delegating, verifying, reviewing, or shipping.
---

# Using Rolepod — workflow router

Turns each request into a tier and the first skill of `Define → Plan → Build → Verify → Review → Ship`; that skill owns what follows.

Route each new request. A literal follow-up on the same routed R0/R1 task, with no tool call in between, resumes; a phase or tier change, or a tool call in between, routes again.
The user's explicit instruction wins ("skip spec", "answer only", "just write the code", "just commit", "no plan", "ship as-is"): obey, and say which step was skipped.

### 1. Commission or conversation

- **Conversation** — an idea question in any language ("what do you think", "would X be better?"), a hypothetical, a comparison, no imperative aimed at the repo → R0: discuss trade-offs with honest pushback; no spec, no plan, no artifact. When the idea firms up, offer once: "want this as a spec?"
- **Commission** — an imperative aimed at the repo in any language (fix / add / build / change), named files or features, acceptance-shaped wording → step 2.
- **Ambiguous** → treat it as conversation and ask in one line whether to build.

Done when: a conversation is answered in the user's register, or a commission goes to step 2.

### 2. Tier it — the rigor ladder

| Tier | Signature | Path |
|---|---|---|
| **R0** answer only | question, lookup, conversation — no file change | answer; verify facts, reason freely on opinions |
| **R1** trivial edit | a docs-only diff, any size — or ≤5 lines in 1 file with zero logic lines (comment, blank, user-facing text in a string; never a URL, path, key, regex, query or a value code branches on), not high-risk, ≤3 tool calls | direct edit; the edit echo is the verify; no review |
| **R2** one file + test | 1 source file + its test, clear scope, logic, ≈≤30 lines, not high-risk | its step 3 skill still fires (bug → `debug-issue`, else `implement-plan`); a 3-5 line chat checklist (goal, done-when, verify command) replaces spec + plan; a task owner builds it on main (baseline, failing test first, verify, the commit check, the two review lenses); the Lead never pre-explores, then commits |
| **R3** multi-file | several files, vague scope, or sequencing / delegation | the full spine |
| **R4** high-risk | a high-risk path (Stop conditions), any size | the full spine + adversarial review floor, never downgraded; 1 file, ≤5 lines, comment / blank only → R2 with ONE internal strong reviewer |

- Unsure about risk → the higher tier.
- Unsure about size only → read the affected regions of the named files (and `git status` once work started) and tier from that; an unresolved dependency → higher.
- The task grows (a second source file, hidden logic, a risk path) → re-tier up at once, never down.
- Tier is per task; the commission's highest tier sets the spine (Define → Plan) only.
- Verify never fully skips: R1/R2 drop the full suite and browser drive, never the echo or the checklist command.
- Effort settings (`/effort`, ultracode) raise reasoning, never the tier.

Done when: one tier is chosen from observed scope.

### 3. Pick the first skill

Force-full: the message opens with `/rolepod-full`, `$rolepod-full`, `force full lifecycle`, `run full rolepod lifecycle` or `rolepod mode: full lifecycle` → `rolepod-full`, all six phases, even for a one-line fix. Bare `/rolepod`, `run all phases`, `no skip` auto-route.

Otherwise the FIRST matching row fires:

| Intent | Route |
|---|---|
| build / add / design with a vague target (UI, product, doc, ADR included) | Define → `write-spec` |
| build X to a spec whose Success criteria cover it | Plan → `write-plan` |
| add / change Y at R3+ where the spec does not cover Y, or no spec exists | Define → `write-spec` (a new dated delta spec); R2-sized → `implement-plan` with the step 2 checklist |
| execute the plan / use agents in parallel | Plan → `write-plan` (agent routing + cohesion contract) → `implement-plan` |
| architecture (DB schema, API contract, module split) | Define → `write-spec` (Approaches: ONE `system-architect`) |
| where to deepen / refactor for testability, whole repo | tell the user to type /deepen-codebase ($deepen-codebase on Codex) |
| prototype / layout options / does this state model feel right | spec settled → `write-prototype`; else `write-spec` first |
| fix bug / failing test / regression / why does X fail | Build → `debug-issue` |
| refactor / simplify / clean up | Build → `simplify-code` → `check-work` |
| slow / latency / bundle size / N+1 / p95 | Verify → `check-work` baseline → `implement-plan`, Owner `performance-engineer` |
| clear UI edit (design, screenshot, exact acceptance) | Build → `implement-plan`, Owner `frontend-developer` (design system / CSS / a11y → `ui-ux-designer`) |
| write test cases / report a bug, no fix wanted | Verify → `qa-tester` agent (no agent → the Lead writes the case table); a found bug → `debug-issue` report-only |
| is this done / does it (or the UI) work / verify | Verify → `check-work` |
| audit UX / a11y of one page or flow | Verify → `check-work` UI verification → `review-code` Axes (UI) |
| edit / fix on a high-risk path | Define → `write-spec` → `write-plan` → `implement-plan` (per-task review) |
| clear doc edit; CI, Docker, deploy, infra config | Build → `implement-plan`, Owner `content-strategist` (`audience:` set) / `devops-sre`; R1 → the Lead |
| review / look at the diff; audit / find all X across the repo | Review → `review-code`; a whole-repo sweep scopes first (References) |
| ship / merge / PR / done, or the work's natural end | Ship → `finish-work` (`review-code` first if a review is missing) |
| explain / conceptual question | answer; a wide repo or online sweep → ONE `scout` first (no agent → the Lead greps) |
| context too large / compact / resume / stuck | `manage-context` |

No row matches → `examples/routing-transcripts.md`; still none → ask the user which phase.

Done when: one row matched, or the user named the phase.

### 4. State the route

```
Tier: R3 (multi-file) | R4 (high-risk)
Routing: <phase> → <skill>
Reason: <one sentence>
Skipping: <phases + why>, or "none"
Next step: <concrete action>
```

- R0 / R1 — no line.
- R2 — `Route: R2 (one file + test) → <skill> · <reason>`, then the checklist.
- R3 / R4, force-full, or a surprising route — the full block.
- Each tier carries its gloss: R0 answer only · R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk.

Done when: the route is stated (R2 and up) and the named skill is running.

## Stop conditions

- Coding before Define on an ambiguous request → `write-spec`. Claiming done before Verify → `check-work`.
- A 2nd parallel agent without a cohesion contract → `write-plan` first.
- High-risk paths — auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security (override: `.rolepod/risk-paths`) — with zero reviewer reports at commit or ship → STOP. Floor: `security-engineer` + ONE strong pass (`review-code` Pick reviewers).
- A 3rd agent on one issue, or a 3rd PR on one surface in a session → STOP, ask the user.
- A diff mixing unrelated concerns at push → split the PRs (`finish-work` Pre-merge gates).
- Concurrent sessions share the REF as well as the files. A "concurrent session(s) detected" warning → before editing a SHARED file, work in `git worktree add .worktrees/<task> -b <branch>`; disjoint edits flow free.
- Holding work for authorization → keep it on its own branch; never merge it into a SHARED branch before the answer comes — unpushed there, it ships with whoever pushes next.

## References

- Force-full triggered, or the user asks to set up / change cross-family → `references/force-full-lifecycle.md`.
- Delegating, picking a model class, or running a fleet → `references/model-tiers.md`.
- A repo-wide sweep, or the 3rd same-shaped fix in one loop → `references/scope-then-spawn.md`.
- A sibling plugin is installed, or the task's central framework has an unconnected official MCP → `references/plugins-and-mcp.md`.

## Next phase

- The skill the route names; it owns everything downstream.
- If that skill is not available, run its step as the Lead and say so in the Skipping line.
