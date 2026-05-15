# Skill Inventory Audit

Purpose: mark every shipped skill with its tier, trigger purpose, overlap status, and a future-action verdict. **No deletions in this pass.** Audit identifies merge / docs-only / keep candidates for future rounds — behavior tests must prove the route works *without* a skill before that skill can be retired.

## Verdict legend

- **keep** — load-bearing, no overlap.
- **merge later** — covered by another skill semantically; keep as compat shim or fold body when a behavior test proves no regression.
- **docs-only later** — content valuable as reference but doesn't need to be a triggerable skill; move into `docs/` and remove SKILL.md.
- **shim** — already a compatibility redirect; remove after a release once behavior tests confirm the canonical path catches the trigger.

## Tier 0 — Router (1)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `using-rolepod` | Phase router; fires first on every request | none | **keep** |

## Tier 1 — Core workflow (11)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `spec-driven-development` | Vague feature → write spec before code | none | **keep** |
| `planning-and-task-breakdown` | Big goal / spec → ordered task list | none | **keep** |
| `systematic-debugging` | Bug / failing test / regression → reproduce + trace + fix | absorbs `debugging-and-error-recovery` + `root-cause-tracing` | **keep** |
| `test-driven-development` | Write failing test → impl → green | none | **keep** |
| `team-routing` | Pick specialist agent by path/concern | none | **keep** |
| `parallel-contract-orchestration` | 2+ parallel agents → write contract first | hook-enforced by `cohesion-contract-check.sh` | **keep** |
| `subagent-task-execution` | Lead delegates → implementer + 2-stage review | none | **keep** |
| `post-change-verify` | Claim of done → evidence required | partial overlap with `webapp-testing` + `browser-testing-with-devtools` (verify ≠ test infra, but related) | **keep** |
| `code-review-and-quality` | Multi-axis review before merge | overlap with `reviewer-flow` (routing) — distinct: review vs route | **keep** |
| `pre-merge-gate` | Ship intent → S+T+F gates + CI lanes | overlap with `shipping-and-launch` (Tier 2 launch checklist) — distinct: gate vs launch ritual | **keep** |
| `code-simplification` | Refactor → behavior-preserving cut | partial overlap with `anti-spaghetti` (Tier 2 — duplication/dead code) | **keep** |

## Tier 2 — Specialist · Plan (1)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `api-and-interface-design` | API / module boundary design | none in Tier 2 (different layer than `system-architect` agent) | **keep** |

## Tier 2 — Specialist · Build (8)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `anti-spaghetti` | Duplication / dead code / drift | with `code-simplification` (Tier 1) — refactor vs hygiene | **merge later** if behavior tests prove `code-simplification` catches duplication |
| `claude-api` | Anthropic SDK + caching | none | **keep** |
| `conversion-copywriting` | Marketing copy with measured action | none | **keep** |
| `doc-coauthoring` | Co-author docs with user (interview pattern) | with `documentation-and-adrs` — co-author vs final-form | **keep** |
| `frontend-ui-engineering` | Production UI implementation | none | **keep** |
| `interaction-design` | Motion / microinteractions / transitions | partial overlap with `frontend-ui-engineering` | **keep** |
| `interface-design` | Dashboards / admin panels / dense apps | partial overlap with `frontend-ui-engineering` | **keep** |
| `using-worktrees` | Filesystem isolation for parallel work | none | **keep** |

## Tier 2 — Specialist · Verify (4)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `browser-testing-with-devtools` | DevTools MCP — live page inspection | with `webapp-testing` (Playwright) — interactive vs persistent suite | **keep** (complementary, documented boundary) |
| `performance-optimization` | Core Web Vitals / bundle / render perf | none | **keep** |
| `security-and-hardening` | Auth / secrets / vuln audit | overlap with `security-engineer` agent — skill vs agent | **keep** |
| `webapp-testing` | Playwright E2E suite | with `browser-testing-with-devtools` — see above | **keep** |

## Tier 2 — Specialist · Review (2)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `doubt-driven-development` | Adversarial 5-step review w/ reasoning strip | overlap with `code-review-and-quality` (Tier 1) — adversarial vs multi-axis | **keep** |
| `web-design-guidelines` | UI compliance checklist (a11y / hierarchy) | overlap with `interface-design` | **keep** |

## Tier 2 — Specialist · Ship (6)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `ci-cd-and-automation` | CI/CD pipeline + quality gates | none | **keep** |
| `documentation-and-adrs` | ADRs / runbooks / durable tech docs | with `doc-coauthoring` (build vs final-form) | **keep** |
| `finishing-a-development-branch` | 4-option menu at branch end | none (wired into router finish ritual) | **keep** |
| `internal-comms` | Status updates / decision memos / escalations | none | **keep** |
| `seo` | SEO audit (technical / on-page / content) | none | **keep** |
| `shipping-and-launch` | Launch checklist + rollback + monitoring | with `pre-merge-gate` (Tier 1) — launch vs gate | **keep** |
| `user-facing-content` | FAQ / error msgs / empty states | with `conversion-copywriting` — UX vs marketing | **keep** |

## Tier 2 — Specialist · Cross-cutting (3)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `context-engineering` | Load / unload / compress agent context | none | **keep** |
| `source-driven-development` | Cite official docs at write time | with `verify-first` (rule, not skill) | **keep** |
| `zoom-out` | Meta-cognitive recovery from drift | partial overlap with `triage-deep` (deep triage rules) | **keep** |

## Compatibility / utility (5 not yet tiered)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `advisor-escalation` | Sonnet/Haiku stuck → consult Opus | none | **keep** |
| `new-project-onboarding` | First time in unfamiliar repo | none | **keep** |
| `reviewer-flow` | Route review across Codex / Gemini / qa-tester | with `code-review-and-quality` — routing vs reviewing | **keep** |
| `session-hygiene` | `/clear` / `/compact` / `/rewind` decisions | none | **keep** |
| `triage-deep` | Multi-file / scope / drift control | with `zoom-out` — see above | **keep** |

## Tier 3 — Compatibility shims (2)

| Skill | Trigger purpose | Overlap | Verdict |
|---|---|---|---|
| `debugging-and-error-recovery` | Legacy bug-fix trigger | redirects to `systematic-debugging` | **shim** — remove after a release once `case-02-bug-fix.yml` proves canonical route catches both trigger phrasings |
| `root-cause-tracing` | Legacy upstream-trace trigger | redirects to `systematic-debugging` | **shim** — remove after same gate |

## Summary

| Tier | Count | All "keep"? |
|---|---|---|
| 0 — Router | 1 | yes |
| 1 — Core workflow | 11 | yes |
| 2 — Specialist | 24 | yes (1 marked "merge later" candidate: `anti-spaghetti`) |
| 2 — Compat / utility (not phase-tagged) | 5 | yes |
| 3 — Compat shims | 2 | "shim" → remove later |

Total skills on disk: **43**.
Default Lead surface (Tier 0 + 1 in entry docs): **12**.
Future-removal candidates after behavior tests prove canonical route works: **3** (`anti-spaghetti` merge-into-`code-simplification`, plus 2 Tier-3 shims).

## When to act on this audit

- **Now:** nothing. Audit captures state; no deletions or renames.
- **After 2 weeks of live use + workflow-behavior tests passing reliably:** evaluate the "merge later" + "shim" candidates. Behavior tests must show the canonical Tier 1 skill catches the legacy trigger phrase before the legacy skill can be removed.
- **Every release:** re-run this audit (or its successor). New skills must justify their tier per the non-negotiables in `docs/rolepod-hardening-plan.md` (unique trigger / behavior not covered / drift test exists).
