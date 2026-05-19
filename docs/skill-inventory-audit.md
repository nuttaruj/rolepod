# Skill Inventory Audit (Core 10)

Purpose: snapshot every shipped skill after the Core 10 consolidation. **No further deletions in PR 1.** Audit confirms each public skill is load-bearing and each shim redirects to a Core 10 target. Behavior tests (`tests/workflow-behavior/cases/`) must continue to pass for one migration release before shims are removed.

## Verdict legend

- **keep** — Core 10 public skill, load-bearing, no overlap.
- **shim** — compatibility redirect to a Core 10 skill. Remove after one release once behavior tests confirm the canonical route catches the legacy trigger.

## Tier 0 — Router (1)

| Skill | Trigger purpose | Verdict |
|---|---|---|
| `using-rolepod` | Phase router; fires first on every request | **keep** |

## Tier 1 — Core 10 phase skills (9)

| Skill | Phase | Trigger purpose | Absorbs (now shims) | Verdict |
|---|---|---|---|---|
| `write-spec` | Define | Vague feature → spec + approval gate | `spec-driven-development`, `doc-coauthoring` | **keep** |
| `write-plan` | Plan | Spec → tasks + agent routing + cohesion contract | `planning-and-task-breakdown`, `team-routing`, `parallel-contract-orchestration`, `api-and-interface-design`, `source-driven-development` | **keep** |
| `implement-plan` | Build | Plan → TDD + delegation + worktrees + artifact writing | `subagent-task-execution`, `test-driven-development`, `using-worktrees`, `frontend-ui-engineering`, `interface-design`, `interaction-design`, `claude-api`, `seo`, `documentation-and-adrs`, `user-facing-content`, `internal-comms`, `conversion-copywriting` | **keep** |
| `debug-issue` | Build (bug) | Bug / failing test → reproduce → root → failing test → fix | `systematic-debugging`, `debugging-and-error-recovery`, `root-cause-tracing` | **keep** |
| `check-work` | Verify | Done claim → evidence required | `post-change-verify`, `webapp-testing`, `browser-testing-with-devtools` | **keep** |
| `review-code` | Review | Pre-merge multi-axis review + adversarial for high-risk | `code-review-and-quality`, `reviewer-flow`, `doubt-driven-development`, `web-design-guidelines`, `security-and-hardening`, `performance-optimization` | **keep** |
| `finish-work` | Ship | Pre-merge gate + CI lanes + 4-option finish + launch | `pre-merge-gate`, `finishing-a-development-branch`, `shipping-and-launch`, `ci-cd-and-automation` | **keep** |
| `simplify-code` | Simplify | Behavior-preserving cleanup | `code-simplification`, `anti-spaghetti` | **keep** |
| `manage-context` | Recovery | Context heavy / stuck / unfamiliar repo / advisor / onboarding | `context-engineering`, `session-hygiene`, `zoom-out`, `triage-deep`, `advisor-escalation`, `new-project-onboarding` | **keep** |

## Tier 2 — Specialist (0 public)

Empty by default. Domain depth lives in the 18 specialist agents and is routed from inside each Core 10 phase skill. Optional exception: `check-security` may be added later if product direction demands an explicit public security workflow surface.

## Tier 3 — Compatibility shims (43)

Each shim has `tier: 3`, `redirect_to: <core-skill>`, and a tiny fallback (5-8 bullets) so a copy-only install still works.

### → `write-spec` (2)

| Shim | Legacy trigger |
|---|---|
| `spec-driven-development` | "start a new feature", "write a spec", "requirements not pinned" |
| `doc-coauthoring` | "write a document together" |

### → `write-plan` (5)

| Shim | Legacy trigger |
|---|---|
| `planning-and-task-breakdown` | "break this into tasks", "too big for one session" |
| `team-routing` | "choose agent", "multi-agent parallel", "team layout" |
| `parallel-contract-orchestration` | "spawn parallel agents", "cohesion contract" |
| `api-and-interface-design` | "design REST/GraphQL", "module interface" |
| `source-driven-development` | "integrate SDK", "plugin manifest", "schema-bound config" |

### → `implement-plan` (12)

| Shim | Legacy trigger |
|---|---|
| `subagent-task-execution` | "delegate to subagent", "two-stage review" |
| `test-driven-development` | "TDD", "failing test first", "Prove-It" |
| `using-worktrees` | "parallel agents overlapping paths", "hotfix interrupt", "compare branches" |
| `frontend-ui-engineering` | "build component", "frontend implementation" |
| `interface-design` | "dashboard", "admin panel", "operational UI" |
| `interaction-design` | "motion", "microinteraction", "hover/focus/press states" |
| `claude-api` | "Anthropic SDK", "prompt cache", "Claude model migration" |
| `seo` | "SEO audit", "Core Web Vitals", "site migration" |
| `documentation-and-adrs` | "ADR", "runbook", "durable tech docs" |
| `user-facing-content` | "FAQ", "error message", "empty state", "onboarding copy" |
| `internal-comms` | "status update", "decision memo", "escalation" |
| `conversion-copywriting` | "landing page", "email campaign", "CTA" |

### → `debug-issue` (3)

| Shim | Legacy trigger |
|---|---|
| `systematic-debugging` | "error appears", "test fails", "recurring bug different surface" |
| `debugging-and-error-recovery` | "something worked before and stopped" |
| `root-cause-tracing` | "stack trace late-stage symptom", "fix moves the bug" |

### → `check-work` (3)

| Shim | Legacy trigger |
|---|---|
| `post-change-verify` | "verify change", "evidence after edit", "show test pass output" |
| `webapp-testing` | "Playwright", "UI verify with persistent suite" |
| `browser-testing-with-devtools` | "DevTools", "live page inspect", "console error capture" |

### → `review-code` (6)

| Shim | Legacy trigger |
|---|---|
| `code-review-and-quality` | "review this PR", "multi-axis review before merge" |
| `reviewer-flow` | "spawn reviewer", "Codex review", "Gemini review", "review cascade" |
| `doubt-driven-development` | "adversarial review", "irreversible operation review" |
| `web-design-guidelines` | "audit design quality", "a11y review" |
| `security-and-hardening` | "auth flow", "secret handling", "vuln audit" |
| `performance-optimization` | "perf regression", "Core Web Vitals", "p95/p99" |

### → `finish-work` (4)

| Shim | Legacy trigger |
|---|---|
| `pre-merge-gate` | "before push", "before merge", "ship gate", "ship it" |
| `finishing-a-development-branch` | "branch end", "4-option finish menu" |
| `shipping-and-launch` | "production launch", "monitoring", "rollback plan" |
| `ci-cd-and-automation` | "CI/CD lane", "pipeline config", "flaky pipeline" |

### → `simplify-code` (2)

| Shim | Legacy trigger |
|---|---|
| `code-simplification` | "refactor for clarity", "behavior-preserving cleanup" |
| `anti-spaghetti` | "duplication", "dead code", "dependency drift" |

### → `manage-context` (6)

| Shim | Legacy trigger |
|---|---|
| `context-engineering` | "context budget", "lazy loading", "multi-agent context isolation" |
| `session-hygiene` | "/clear", "/compact", "/rewind", "switching task" |
| `zoom-out` | "stuck in details", "drift from goal", "lost the actual problem" |
| `triage-deep` | "multi-file task", "scope unclear", "phase abort" |
| `advisor-escalation` | "stuck", "consult Opus", "third agent same issue" |
| `new-project-onboarding` | "first time in repo", "/init", "unfamiliar project" |

## Summary

| Tier | Count | All "keep" / "shim" ? |
|---|---:|---|
| 0 — Router | 1 | keep |
| 1 — Core 10 phase skills | 9 | keep |
| 2 — Specialist (public) | 0 | — |
| 3 — Compatibility shims | 43 | shim → remove after one migration release |

- Total skill files on disk: **53**.
- Public non-shim skills: **10** (1 router + 9 Core 10 phase skills).
- Default Lead surface (Tier 0 + Tier 1 in entry docs): **10**.

## When to act on this audit

- **Now (PR 1):** Core 10 in place + shims preserve legacy triggers. Tests + render-clean enforce the contract.
- **Release N+1:** delete shims after one migration release once behavior tests confirm the canonical Core 10 route catches every legacy trigger phrase in production usage. Move surviving notes to `docs/legacy-skills.md`.
- **Release N+2:** distill agent playbooks (18 specialists) to absorb the deep domain expertise that used to live in shims. PR 2 of this consolidation owns that work — see `docs/agent-standalone-audit.md`.

## Optional exception

`check-security` is the only Tier 2 candidate left on the table. It is NOT shipped in PR 1. Add it only if product direction confirms users want an explicit public security workflow; otherwise security routes through `review-code` (fallback inside the skill) and escalates to `security-engineer` agent.
