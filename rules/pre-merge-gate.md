# Pre-Merge Gate

Read BEFORE: `gh pr merge`, `git push` to tracked branch, equivalent ship action.

Deep guide: skill `shipping-and-launch`

## Step 0 — Simplicity gate (run BEFORE reviewer)

Active checkpoint. Answer 5 questions:

```
S1: Feature beyond user request?          yes → cut
S2: Abstraction for single-use code?      yes → inline
S3: Config/flexibility nobody asked?      yes → cut
S4: Defensive code for impossible case?   yes → cut
S5: Same pattern now in 3+ places?        yes → centralize before commit
```

Any "yes" → revise. Don't waste reviewer rounds on bloat.

## Step 0.5 — Test gate (run BEFORE reviewer)

```
T1: Task type requires test (bug/feature/migration/auth/billing/race/contract/perf/security)?
     yes + no test → block, write test (Lead direct or qa-tester subagent)
T2: New tests pass?                       no → fix
T3: Existing tests still pass?            no → fix regression
T4: Tests fast enough?                    no → tier (unit hot, integration CI)
T5: Tests isolated?                       no → fix order dependency
```

Internal only. Reviewer != tester. Tests must be runnable + passing BEFORE spawning reviewer.

Skip if: typo / comment / docstring / pure rename / dead code removal.

Full guide: `testing.md`

## Step 1 — Pick reviewer by PR profile

Routing matrix (canonical) → `reviewer-flow.md`.

Quick reference:
- `<5 files` → qa-tester only
- `5-30 files` → Gemini + qa-tester
- `>30 files` → Gemini + qa-tester + Codex (risky parts)
- High-risk surface (auth/billing/migrations/locks/external) → Codex adversarial + qa-tester
- UI/frontend → Gemini + qa-tester

**qa-tester = minimum floor. Never skip** (even 1-file change touching high-risk surface).

## Step 2 — Run reviewers, batch findings, fix

- Round cap per feature batch: Codex 3, Gemini 3, qa-tester unlimited.
- Batch all findings before re-running. Don't re-trigger per fix.
- Verify each finding in code — review = input not orders.
- Don't hide unresolved findings → explain with file:line if invalid/deferred.
- Lead interprets findings; reviewers don't make decisions.

Full cascade phases + reviewer routing details: `reviewer-flow.md`

## Step 3 — Ask user before ship?

| Profile | Action |
|---------|--------|
| Doc-only (`*.md`, `docs/`, comments, docstrings) — zero runtime impact | **Push direct to main**. No PR. No reviewer. No gate. |
| `fix/refactor/chore` AND ≤3 files AND ≤50 lines | **Auto-merge** via PR after gate green. Report after. |
| `feat(*)` | **ASK first** |
| ≥4 files OR ≥100 lines | **ASK first** |
| Touches auth/billing/payments/migrations/Stripe/external integration | **ASK first** regardless of size |
| Breaking change / removes public API | **ASK first** + flag breaking |

### "Doc-only" definition

= ONLY `*.md` files / `docs/` content / comments / docstrings.
Touches **any** of these → NOT doc-only → use PR path:
- source code (`.py`, `.ts`, `.tsx`, `.go`, `.rs`, `.php`, `.rb`, `.java`, `.kt`, `.swift`, `.cs`, `.cpp`, etc.)
- config (`.json`, `.yaml`, `.toml`, `.env*`, `Dockerfile`, `Makefile`)
- schema / migration
- hook / build script / CI workflow

## Step 4 — One ask, one ship

User explicitly OK'd commit + PR (e.g. "let's go", "ship it", "commit + PR")
→ approval covers merge after **all required CI lanes green**
→ DO NOT ask second time post-CI
→ just merge + report

### CI lanes — 3-phase model

| Phase | Trigger | Scope | Required? |
|-------|---------|-------|-----------|
| **1 Fast critical** | every PR | Universal invariants (lint / typecheck / smoke unit / auth guard / tenant isolation / money core / migration apply / build) | YES |
| **2 Path-triggered** | path matches | Module's full test suite (only modules touched) | YES when triggered |
| **3 Nightly / manual** | cron / on-demand | Broad / integration full / docker / chaos / security deep / E2E / perf | NO |

ALL Phase 1 + triggered Phase 2 = green → merge auto.
Required red → Lead fix + re-push (no ask).

Lane definitions: `testing.md` "Test tiers + CI lanes" section.

### Re-ask only if

- A required CI lane fails (after Lead fix attempt) → "tried fix X, still red, advise?"
- Non-required lane catches material issue (Nightly/E2E finds bug) → notify, don't auto-fix
- User requests changes mid-CI

## Step 5 — Push after merge

User memory: "Auto-push after fixes complete" — push to main immediately after commit + gate pass. No need to ask.

## Skipping the gate

Requires explicit user override (e.g. "skip gate, ship now").
Default = enforce.

## Common mistakes — DO NOT

- Skip qa-tester because PR is "small"
- Re-trigger Codex/Gemini per individual fix instead of batching
- Auto-merge feat(*) without asking
- Treat config/schema change as "doc-only"
- Ask second time after user already said ship
