---
description: Invoke FULL team lifecycle — all 6 phases (define + plan + build + verify + review + ship) via team recipes. Use when one-shot subagent dispatch is insufficient and you want parallel agents at every phase.
disable-model-invocation: true
---

# Team All — Full Lifecycle Recipe

You are entering the **full team-all workflow**. This is the heavy variant of rolepod's team mode — all 6 phases use parallel team recipes, not single-subagent dispatch.

When to use:
- New feature with cross-domain impact (frontend + backend + DB + security)
- Refactor touching ≥30 files
- High-risk surface (auth / billing / migrations / payments)
- User explicitly invoked `/team-all` because pattern-match to plain subagents has been insufficient

NOT for:
- Single-file change
- Typo / docs
- Hotfix
- Independent work that fits one specialist

## Execution sequence (NO skipping)

Each phase MUST complete its gate before the next phase fires. Lead orchestrates via Task tool; phases that spawn ≥2 parallel agents require a cohesion contract first (skill `parallel-contract-orchestration`).

### Phase 1 — Define
Spawn (parallel): `product-manager` + `business-analyst` + `system-architect`
Output: written SPEC.md with acceptance criteria, risk surface, scope.
Gate: `verify-first` — every claim cited to source.

### Phase 2 — Plan
Spawn: `system-architect` (writes cohesion contract + RED test list) + `product-manager` (verifies task ordering matches spec).
Output: ordered task list with per-task done-condition + verify command.
Gate: `Q1-Q4` — every task has a verifiable owner.

### Phase 3 — Build
Spawn (parallel by path): pick engineers via `team-routing` skill (backend-developer, frontend-developer, mobile-developer, billing-engineer, ai-ml-engineer, data-scientist as needed). Owner = `system-architect`.
Output: code that compiles + tests written + acceptance criteria met per task.
Gate: `S1-S5` simplicity + `F1-F5` failure-mode + `T1-T6` test gate.

### Phase 4 — Verify
Spawn (parallel by concern): `qa-tester` + `security-engineer` + `performance-engineer`.
Output: evidence per concern — qa-tester runs full test suite, security-engineer audits high-risk paths, performance-engineer measures perf budgets.
Gate: `post-change-verify` — every change has evidence (test pass / curl / screenshot / log).

### Phase 5 — Review
Spawn: `universal-reviewer` + `qa-tester` (doubt-driven, bounded to 3 rounds).
Adversarial reviewers: dispatch BOTH `codex exec --skip-git-repo-check '<prompt>'` AND `gemini -m pro -p '<prompt>'` if both binaries on PATH (per `reviewer-flow` — Codex = depth, Gemini = breadth, orthogonal coverage).
Output: line-anchored findings, fixed or explicitly rejected with reason.
Gate: `pre-merge-gate` — S+T+F+P all pass + reviewer findings resolved.

### Phase 6 — Ship
Spawn (parallel): `devops-sre` + `tech-writer` + `growth-marketer` + `customer-success`.
Output: CI green (Phase 1 + triggered Phase 2) + launch announcement drafted + customer-facing comms.
Gate: CI 3-phase + user approval where policy requires + `finishing-a-development-branch` 4-option menu.

## Rules

- **No phase skipping.** If `verify-first` says spec already written, mark Define complete + continue. Don't skip the gate.
- **Cohesion contract before any 2+ parallel agent spawn** (skill `parallel-contract-orchestration`). Hook `cohesion-contract-check.sh` enforces.
- **Lead owns git state.** Sub-agents can't `git commit` / `git push` (hook `block-subagent-commit.sh` enforces).
- **Cost awareness.** Team-all = 5-10× single-session cost. User must have invoked it explicitly (this command requires `disable-model-invocation: true` — not auto-fired).

## Skip-back routes

If mid-flight scope shrinks ("this is single-file after all"):
- Lead announces phase rollback
- Falls back to default Subagent + Task dispatch
- Document why in summary (so MemPalace KG captures the rollback signal)

## Pairs with

- `team-routing` — picks the right engineer per path
- `parallel-contract-orchestration` — writes cohesion contract before fanout
- `pre-merge-gate` — phase 5 gate detail
- `finishing-a-development-branch` — phase 6 exit menu

For single-phase invocation, use `/team-define`, `/team-plan`, `/team-build`, `/team-verify`, `/team-review`, `/team-ship`. This `/team-all` command chains all 6.
