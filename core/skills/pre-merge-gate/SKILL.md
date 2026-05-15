---
name: pre-merge-gate
description: Run the pre-merge gate — simplicity + test + reviewer routing + ask-user matrix + CI lanes — before pushing or merging.
when_to_use: 'before `git push` to tracked branch, `gh pr merge`, "ship it", "before push", "before merge", "ship gate", PR ready to merge'
---

# Pre-Merge Gate

Read BEFORE: `gh pr merge`, `git push` to tracked branch, equivalent ship.

Deep guide: skill `shipping-and-launch`.

## Step 0 — Simplicity gate (BEFORE reviewer)

```
S1: Feature beyond user request?          yes → cut
S2: Abstraction for single-use?           yes → inline
S3: Config/flexibility nobody asked?      yes → cut
S4: Defensive code for impossible case?   yes → cut
S5: Same pattern in 3+ places?            yes → centralize
```

Any yes → revise. Don't waste reviewer rounds on bloat.

## Step 0.5 — Test gate (BEFORE reviewer)

```
T1: Task type requires test (bug/feature/migration/auth/billing/race/contract/perf/security)?
     yes + no test → block, write (Lead or qa-tester)
T2: New tests pass?              no → fix
T3: Existing tests pass?         no → fix regression
T4: Tests fast enough?           no → tier
T5: Tests isolated?              no → fix order dep
```

Internal only. Reviewer != tester. Tests pass BEFORE spawning reviewer.

Skip if: typo / comment / docstring / pure rename / dead code removal.

Full: rule `test/testing.md`.

## Step 1 — Pick reviewer

Routing canonical: skill `reviewer-flow`.

Quick:
- `<5 files` → qa-tester only
- `5-30 files` → Gemini + qa-tester
- `>30 files` → Gemini + qa-tester + Codex (risky)
- High-risk surface (auth/billing/migration/locks/external) → Codex adversarial + qa-tester
- UI / frontend → Gemini + qa-tester

**qa-tester = minimum floor. Never skip.**

## Step 2 — Run reviewers

- Cap per batch: Codex 3, Gemini 3, qa-tester unlimited
- Batch findings before re-running
- Verify each in code — review = input not orders
- Unresolved findings: explain with file:line if invalid/deferred
- Lead interprets; reviewers don't decide

Full cascade: skill `reviewer-flow`.

## Step 3 — Ask user before ship?

| Profile | Action |
|---------|--------|
| Doc-only (`*.md`, `docs/`, comments, docstrings) | **Push direct to main**. No PR. |
| `fix/refactor/chore` AND ≤3 files AND ≤50 lines | **Auto-merge** via PR. Report after. |
| `feat(*)` | **ASK first** |
| ≥4 files OR ≥100 lines | **ASK first** |
| Auth / billing / payments / migrations / Stripe / external | **ASK first** regardless of size |
| Breaking change / removes public API | **ASK first** + flag breaking |

### "Doc-only" definition

= ONLY `*.md` / `docs/` / comments / docstrings.
Touches any of these → NOT doc-only → PR path:
- Source code (`.py`, `.ts`, `.tsx`, `.go`, `.rs`, `.php`, `.rb`, `.java`, `.kt`, `.swift`, `.cs`, `.cpp`, etc.)
- Config (`.json`, `.yaml`, `.toml`, `.env*`, `Dockerfile`, `Makefile`)
- Schema / migration
- Hook / build script / CI workflow

## Step 4 — One ask, one ship

User OK'd commit + PR ("ship it", "let's go", "commit + PR")
→ covers merge after all required CI green
→ DO NOT ask second time post-CI
→ merge + report

### CI lanes — 3-phase

| Phase | Trigger | Scope | Required? |
|-------|---------|-------|-----------|
| **1 Fast critical** | every PR | Lint / typecheck / smoke unit / auth guard / tenant isolation / money core / migration apply / build | YES |
| **2 Path-triggered** | path matches | Module's full tests (only touched modules) | YES when triggered |
| **3 Nightly / manual** | cron / on-demand | Broad / integration / docker / chaos / security deep / E2E / perf | NO |

ALL Phase 1 + triggered Phase 2 green → merge auto.
Required red → Lead fix + re-push (no ask).

Lanes: rule `test/testing.md`.

### Re-ask only if

- Required lane fails after Lead fix → "tried X, still red, advise?"
- Phase 3 catches material issue → notify
- User requests changes mid-CI

## Step 5 — Push after merge

User memory: "Auto-push after fixes complete" — push to main immediately after commit + gate pass. No ask.

## Skipping the gate

Requires explicit override ("skip gate, ship now"). Default = enforce.

## Common mistakes — DO NOT

- Skip qa-tester because PR is "small"
- Re-trigger Codex/Gemini per fix instead of batching
- Auto-merge `feat(*)` without asking
- Treat config/schema change as doc-only
- Ask second time after user said ship

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "Small PR, skip the gate" | The gate is mechanical (S+T+F). Small PR still passes or fails the questions — answer them, don't skip. |
| "Reviewer already saw it" | "Saw" ≠ "approved with line-anchored findings". If you can't paste the verdict, the review didn't happen. |
| "Tests are flaky, ignore reds" | Flaky test = unverified state. Fix the flake or quarantine; don't merge red. |
| "CI takes too long, push to main" | The full CI suite splits into Phase 1 (fast, required) + Phase 2 (path-triggered) + Phase 3 (nightly). Phase 1 + matched Phase 2 must be green. |
| "User said ship, no need to ask twice" | First "ship" = approval, no second ask. But high-risk surface (auth / billing / migration) still needs the explicit reviewer pass before the gate clears. |
| "Reviewer will catch it later" | Reviewer routing is the gate's job. If you reach the gate without a reviewer dispatched, the gate blocks. That's the design. |
