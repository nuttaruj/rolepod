# Skill Inventory Audit (Core 10 Only)

Purpose: snapshot the post-cleanup skill surface. Rolepod now ships **10 executable skills** and **0 compatibility shim directories**. Old names are tracked in [legacy-skill-map.md](legacy-skill-map.md) as documentation only.

## Verdict

**Lean surface is intentional and complete.** The workflow still covers Define → Plan → Build → Verify → Review → Ship plus Simplify/Recovery, but users and agents choose from one small public surface instead of dozens of tiny phase fragments.

## Shipped skills

| Tier | Skill | Phase | Load-bearing responsibility |
|---|---|---|---|
| 0 | `using-rolepod` | Router | First skill; chooses phase, skip rules, evidence required |
| 1 | `write-spec` | Define | Discovery dialogue, options, approval gate, spec self-review |
| 1 | `write-plan` | Plan | Ordered tasks, test/evidence per task, agent routing, cohesion contract |
| 1 | `implement-plan` | Build | Execute approved work, TDD, bounded delegation, worktree discipline |
| 1 | `debug-issue` | Build (bug) | Reproduce → trace upstream → failing test → minimal fix |
| 1 | `check-work` | Verify | Fresh evidence before claiming done |
| 1 | `review-code` | Review | Multi-axis review, reviewer routing, high-risk adversarial pass |
| 1 | `finish-work` | Ship | S/T/F/P gates, CI lanes, 4-option finish menu |
| 1 | `simplify-code` | Simplify | Behavior-preserving cleanup and anti-bloat cuts |
| 1 | `manage-context` | Recovery | Context pressure, stuck sessions, onboarding, handoff/resume |

## What moved out of executable skills

Domain and sub-phase detail moved into one of two homes:

- **Core 10 trigger text** for old workflow phrases. Example: "break this into ordered tasks" now belongs to `write-plan`, not a separate `planning-and-task-breakdown` file.
- **Specialist agents** for domain judgment. Example: frontend, SEO, security, performance, docs, and platform-specific details live in the matching agent, routed by `write-plan`, `implement-plan`, `check-work`, or `review-code`.

The full mapping is in [legacy-skill-map.md](legacy-skill-map.md).

## Workflow completeness check

| Use case | Covered by | Evidence guard |
|---|---|---|
| Vague feature / fuzzy product request | `using-rolepod` → `write-spec` | `feature-from-spec` integration + workflow behavior cases |
| Approved spec to actionable plan | `write-plan` | `feature-from-spec` + `multi-agent-contract` |
| Normal implementation | `implement-plan` | `feature-from-spec` + agent handoff checks |
| Bug fix / recurring regression | `debug-issue` | `bug-fix-workflow` + legacy debug phrase behavior case |
| Multi-agent / parallel work | `write-plan` + cohesion hook | `multi-agent-contract` |
| High-risk auth/billing/security/migration | `review-code` + security/qa agents | `high-risk-gates` |
| Verify before completion claim | `check-work` | `feature-from-spec`, `bug-fix-workflow`, legacy verify phrase case |
| Code review before merge | `review-code` | `high-risk-gates`, agent standalone audit |
| Push / merge / PR / launch | `finish-work` | `ship-gate` |
| Over-engineered or duplicated code | `simplify-code` | lean-surface + simplify skill fallback checks |
| Stuck / context-heavy / unfamiliar repo | `manage-context` | lean-surface fallback and next-phase checks |
| Copy-only skill usage | Each Core 10 skill has no-agent fallback | `lean-surface` fallback checks |
| Copy-only agent usage | Each agent has standalone sections + output contract | `agent-standalone-audit` + `lean-surface` |

## Static invariants

`tests/static/lean-surface.sh` now locks:

- filesystem skill dirs = 10
- `tier: 3` count = 0
- `redirect_to:` count = 0
- deleted legacy skill directories stay absent
- rendered skill catalog count matches filesystem
- active docs route through Core 10 only
- agent preloads use Core 10 only, with `ui-ux-pro-max` as the only allowed optional add-on

## Summary

| Category | Count |
|---|---:|
| Tier 0 router | 1 |
| Tier 1 workflow skills | 9 |
| Public specialist skills | 0 |
| Compatibility shim directories | 0 |
| Total executable skill directories | 10 |

## Optional future exception

`check-security` remains the only credible future public skill candidate. Do not add it by default. Add it only if users repeatedly ask for a standalone security workflow that is more natural than `review-code` + `security-engineer`.
