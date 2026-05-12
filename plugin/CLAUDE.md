# Claude Code — Core Rules

Universal core. Deep rules `~/.claude/rules/` (trigger→file: `INDEX.md`). Priority: user-this-turn > nested CLAUDE.md > project root > `~/.claude/rules/*.md` > this file > Anthropic default. Conflict unsafe → ask.

## Identity + setup + workflow

Lead = whichever model reads this; Opus/Sonnet/Haiku same rules; self-do OR delegate to subagent. Subagents at `~/.claude/agents/*.md` (Task tool, Q1-Q4) · Hooks `.claude/settings.json` (SessionStart/PreToolUse/PostToolUse/Stop/PreCompact) · Skills `.claude/skills/<name>/SKILL.md` (auto-trigger from frontmatter) · Peer review high-risk → qa-tester/security-engineer/universal-reviewer + Codex/Gemini adversarial · Cohesion contracts multi-agent → `parallel-contract-orchestration` skill BEFORE spawn. Language: match user; concise (result+risk+next); commits/PRs/code English normal tone (`always-on/communication.md`). Non-trivial: Explore (Plan mode) → Plan (simplicity check) → Implement (every line traces) → Pre-commit gate → Commit + PR; skip plan if 1-sentence diff. Phases/gates: Define (verify-first) → Plan (Q1-Q4) → Build (S1-S5, F1-F5) → Verify (T1-T6) → Review (skill pre-merge-gate) → Ship (CI 3-phase). Cross-cutting: `zoom-out`, `source-driven-development`, `context-engineering`.

## Verify-first — NO guessing

Confirm from primary source before plan/edit/answer. Internal (file/symbol) → Read or `gitnexus_context`. Live state → run command. External (pricing/lib/news) → WebFetch/WebSearch. Past decisions → `mempalace_kg_query` + verify code matches.

Can't verify → state `Assuming: X. Risk: Y. Verify by: Z`. Don't proceed silently. Uncertain intent → ask. Simpler approach → push back. Details: `~/.claude/rules/always-on/verify-first.md`

## Team workflow trigger

Default = Subagent + Task spawn. Opt-in: "use team" → all 6 phases (5-10x cost) · `/team-<phase>` → that phase only. Recipes (phase → spawn → gate): **define** product-manager+business-analyst+system-architect / verify-first · **plan** system-architect (contract+RED)+product-manager / Q1-Q4 · **build** parallel engineers by path, owner=system-architect / S1-S5,F1-F5 · **verify** qa-tester+security-engineer+performance-engineer / T1-T6 · **review** universal-reviewer+qa-tester (doubt-driven bounded 3) / pre-merge · **ship** devops-sre+tech-writer+growth-marketer+customer-success / CI 3-phase. Mandatory gates apply both. Skip for single-file/typo / <3 agents / independent / hotfix. Rolepod team = single-session Lead orchestration via Task tool. NOT Anthropic experimental agent-teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1; multi-process). Both coexist.

## Decision protocol — simplest viable wins

Fires BEFORE writing code with ≥2 viable options. Upstream of S1-S5.

<EXTREMELY-IMPORTANT>
NEVER pick complex when simple meets requirement. NEVER add abstractions for hypothetical needs. NEVER add config flexibility nobody asked for. NEVER pre-optimize without measured evidence. Default: SIMPLEST viable wins. Complex needs user approval + reason.
</EXTREMELY-IMPORTANT>

5-step: enumerate → analyze (tradeoffs) → compare (complexity/blast/reversibility/cost) → pick simplest viable → document. Red flags: interface w/1 impl · config w/1 value · plugin w/0 plugins · generic wrapper · retry w/o observed failure · refactor "while I'm here" · pre-split <500 lines. Reject "might need later"/"small abstraction"/"best practice"/"already started". Details: skill `code-simplification`.

## Simplicity gate — before every commit

```
S1: Feature beyond request?           yes → cut
S2: Abstraction for single-use?       yes → inline
S3: Config/flexibility nobody asked?  yes → cut
S4: Defensive code for impossible?    yes → make structurally impossible
                                      (type system / data model / API
                                      constraint). Structural unavailable →
                                      case NOT impossible, handle properly.
S5: Same pattern in 3+ places?        yes → centralize before commit
```

Any "yes" → revise. S4 example: runtime null check → `Optional<T>` compiler-enforced. Details: `~/.claude/rules/code/code-quality.md`

## CI lanes — 3-phase + auto-merge

```
Phase 1 (every PR, REQUIRED, <5min): lint/typecheck/smoke unit/auth guard/tenant isolation/money core/migration apply/build
Phase 2 (path-triggered, REQUIRED when matched): module's full test suite
Phase 3 (nightly/manual, NOT required): integration/docker/chaos/security/E2E/perf
```

User OK + PR → ALL Phase 1 + triggered Phase 2 green → merge auto, no re-ask. Required red → Lead fix + re-push. Details: `~/.claude/rules/test/testing.md`

## Test gate — before every commit

```
T1: Task type requires test (bug/feature/migration/auth/billing/race/contract/perf/security)?
     yes + no test → block, write test
T2: New tests pass?                          no → fix
T3: Existing tests pass?                     no → fix regression
T4: Tests fast enough for pre-commit tier?   no → mark slow, move tier
T5: Tests isolated (no order dependency)?    no → fix
T6: Assertion correct? 1-char bug still passes?
     Bad: `assert result is not None`  Good: `assert result == expected_value`
     yes-too-weak → tighten (62% LLM tests weak, arXiv 2402.13521)
```

Skip — ALL true: ≤5 lines · single file · zero logic-bearing (comments/docstrings/whitespace/typechecked renames) · NOT high-risk (auth/billing/payment/migration/credit/permission/secret/crypto/token). Any fail → write tests. PreCommit hook enforces. Internal only. Details: `~/.claude/rules/test/testing.md`

## Before any code edit — 4 questions

```
Q1: Files to edit?           >1   → delegate
Q2: Run tests/build/server?  yes  → delegate
Q3: Design judgment?         yes  → delegate
Q4: Tool calls total?        >3   → delegate
```

All "no" → self-do. Any "yes" → delegate via Agent. Pick by path/concern/strategy per agent roster below.

## Failure-mode gate — before declaring done

```
F1: Hallucinated action?  fn/file/API doesn't exist?  → Read/Grep verify
F2: Scope creep?          diff > user request?        → cut unrequested
F3: Cascading error?      fix introduced new bug?     → run full tests
F4: Context loss?         forgot constraint?          → re-read request + gates
F5: Tool misuse?          destructive unannounced?    → review, announce, re-verify
```

Any "yes" → fix before declaring done. Skip — ALL true: ≤5 lines · single file · zero logic-bearing · NOT high-risk path. Structural-fix folded into S4. Source: DAPLab failure-pattern research.

## Operational notes

**Anti-bloat:** CLAUDE.md always-on judgment / Skills on-demand / Hooks enforcement. **GitNexus + MemPalace** auto via hooks; manual: `gitnexus_impact` before edit · `gitnexus_detect_changes` before commit · `mempalace_kg_query` before re-deciding · `mempalace_kg_add` after major decision · `npx gitnexus analyze` after ≥5 files merged (`code/code-intel.md`). **Session hygiene:** `/clear` between tasks · `/rewind` (Esc Esc) · `/compact <focus>` · `/rename`+`claude --continue` (skill `session-hygiene`). **Before ship — STOP:** `gh pr merge`/`git push` → skill `pre-merge-gate`; reviewer → skill `reviewer-flow`; roles: Codex correctness+security+adversarial · Gemini breadth+cross-file+smell · qa-tester business logic+tests+floor+fallback. **Hard stops (ask user):** 3rd agent same issue · 3rd PR same surface · file disagrees with agent · destructive cmd · 50k+ tokens no convergence · Sonnet/Haiku stuck → Advisor Opus (skill `advisor-escalation`); drift/scope/briefing/creep/abort: skill `triage-deep`. **Search:** `rg` text · GitNexus symbol/caller/impact/rename · MemPalace past decision · WebFetch/WebSearch external. **Verification:** every change → evidence (test/screenshot/curl/log); can't verify → state why+risk; UI → drive browser (Playwright/Chrome MCP), NEVER ask user for screenshot (skill `post-change-verify`). **Quality + anti-spaghetti:** match existing style · one source of truth · surgical changes · comments for intent only · no new deps without win · same pattern in 3+ → centralize (no "just this one place" for auth/permissions/billing/credits/URL validation/redirects/SSRF/cookies/logging/retries/external API) (`code/code-quality.md`). **Goal-driven:** "add validation" → test invalid → pass · "fix bug" → reproducing test → fix · "refactor X" → tests pass before+after · multi-step `[step] → verify: [check]`. **New project:** skill `new-project-onboarding` + `/init`. **Careful mode (high-risk: auth/billing/migrations/payments/data deletion):** run all S1-S5 + T1-T6 · delegate to qa-tester + security-engineer/universal-reviewer for adversarial · ≤3 files per commit · mandatory peer review.

## Skill index (auto-generated)

Trigger phrases in each skill's frontmatter.

<!-- Auto-generated by build/render.sh from core/skills/*/SKILL.md frontmatter. Do not edit. -->
<!-- Grouped by the 6-phase lifecycle taxonomy: Define / Plan / Build / Verify / Review / Ship / Cross-cutting. -->

### Define

| Skill | Description | Path |
|-------|-------------|------|
| `spec-driven-development` | Write a structured spec before writing code. Produces a PRD-style document that becomes the contr... | `core/skills/spec-driven-development/SKILL.md` |

### Plan

| Skill | Description | Path |
|-------|-------------|------|
| `planning-and-task-breakdown` | Break a goal or spec into ordered, verifiable tasks. Pair with spec-driven-development for new fe... | `core/skills/planning-and-task-breakdown/SKILL.md` |
| `parallel-contract-orchestration` | Write a cohesion contract before spawning multiple parallel agents on the same feature. Pattern a... | `core/skills/parallel-contract-orchestration/SKILL.md` |
| `api-and-interface-design` | Design stable APIs and module boundaries that survive change. Covers naming, versioning, error sh... | `core/skills/api-and-interface-design/SKILL.md` |

### Build

| Skill | Description | Path |
|-------|-------------|------|
| `anti-spaghetti` | Prevent code rot — duplication, dead code, drift, circular dependencies, and creeping complexit... | `core/skills/anti-spaghetti/SKILL.md` |
| `claude-api` | Build, debug, and optimize Claude API and Anthropic SDK applications with prompt caching as a def... | `core/skills/claude-api/SKILL.md` |
| `conversion-copywriting` | Write marketing copy that gets a specific reader to take a specific action — copy whose success... | `core/skills/conversion-copywriting/SKILL.md` |
| `doc-coauthoring` | Co-author docs, specs, and proposals with a user through structured iteration — interview, outl... | `core/skills/doc-coauthoring/SKILL.md` |
| `frontend-ui-engineering` | Build production-quality UI. Covers component boundaries, state colocation, data fetching, and th... | `core/skills/frontend-ui-engineering/SKILL.md` |
| `interaction-design` | Design and implement microinteractions, motion, transitions, and feedback. Covers when motion hel... | `core/skills/interaction-design/SKILL.md` |
| `interface-design` | Design dashboards, admin panels, and tool/app interfaces — interfaces users return to and opera... | `core/skills/interface-design/SKILL.md` |
| `subagent-task-execution` | Two-stage per-task review pattern when Lead delegates an implementation task to a subagent — fr... | `core/skills/subagent-task-execution/SKILL.md` |
| `test-driven-development` | Drive implementation with a failing test first. Red → Green → Refactor. | `core/skills/test-driven-development/SKILL.md` |
| `using-worktrees` | Use a git worktree (not a fresh clone, not a branch swap in place) when you need real filesystem ... | `core/skills/using-worktrees/SKILL.md` |

### Verify

| Skill | Description | Path |
|-------|-------------|------|
| `browser-testing-with-devtools` | Verify browser code by inspecting the live page — read the DOM, capture console errors, watch n... | `core/skills/browser-testing-with-devtools/SKILL.md` |
| `debugging-and-error-recovery` | Systematic root-cause debugging when tests fail, builds break, or behavior diverges from expectat... | `core/skills/debugging-and-error-recovery/SKILL.md` |
| `performance-optimization` | Optimize app performance — Core Web Vitals, load time, bundle size, render perf, query latency.... | `core/skills/performance-optimization/SKILL.md` |
| `root-cause-tracing` | Trace an error upstream from where it fires to where it was actually caused, instead of patching ... | `core/skills/root-cause-tracing/SKILL.md` |
| `security-and-hardening` | Defend code against real-world abuse — input validation, auth, secret handling, vuln auditing. | `core/skills/security-and-hardening/SKILL.md` |
| `webapp-testing` | Test local web apps with Playwright. Covers when to use Playwright over manual DevTools, scripted... | `core/skills/webapp-testing/SKILL.md` |

### Review

| Skill | Description | Path |
|-------|-------------|------|
| `code-review-and-quality` | Conduct multi-axis code review across correctness, readability, architecture, security, and perfo... | `core/skills/code-review-and-quality/SKILL.md` |
| `code-simplification` | Refactor for clarity without changing behavior. Behavior-preserving — every change is provable ... | `core/skills/code-simplification/SKILL.md` |
| `doubt-driven-development` | Adversarial 5-step review with reasoning-stripping. A fresh reviewer sees only artifact + contrac... | `core/skills/doubt-driven-development/SKILL.md` |
| `web-design-guidelines` | Review UI for Web Interface Guidelines compliance — accessibility, hierarchy, consistency, and ... | `core/skills/web-design-guidelines/SKILL.md` |

### Ship

| Skill | Description | Path |
|-------|-------------|------|
| `ci-cd-and-automation` | Set up and harden CI/CD pipelines — quality gates, lane splitting by speed/risk, slow/flaky pip... | `core/skills/ci-cd-and-automation/SKILL.md` |
| `documentation-and-adrs` | Write durable technical docs and architectural decision records (ADRs). | `core/skills/documentation-and-adrs/SKILL.md` |
| `finishing-a-development-branch` | At the end of a development task, present a 4-option decision menu (merge, PR, keep open, discard... | `core/skills/finishing-a-development-branch/SKILL.md` |
| `internal-comms` | Write clear internal communication — status updates, announcements, decision memos, escalations... | `core/skills/internal-comms/SKILL.md` |
| `seo` | Audit and improve SEO across technical, on-page, structured-data, and content layers. | `core/skills/seo/SKILL.md` |
| `shipping-and-launch` | Run a disciplined production launch — launch checklist, monitoring/alerts, rollback planning. | `core/skills/shipping-and-launch/SKILL.md` |
| `user-facing-content` | Write user-facing content that helps people, not impresses them. | `core/skills/user-facing-content/SKILL.md` |

### Cross-cutting

| Skill | Description | Path |
|-------|-------------|------|
| `context-engineering` | Optimize agent context — what gets loaded, when, and at what cost. Covers lazy loading, isolati... | `core/skills/context-engineering/SKILL.md` |
| `source-driven-development` | Ground every framework or library decision in official documentation, not training-cached recall.... | `core/skills/source-driven-development/SKILL.md` |
| `zoom-out` | Step back from implementation details to high-level perspective. Meta-cognitive recovery tool. | `core/skills/zoom-out/SKILL.md` |

## Agent roster

18 specialists. Dispatch via Task tool. Q1-Q4 applies.

<!-- Auto-generated by build/render.sh from core/agents/*.md frontmatter. Do not edit. -->

| Agent | Description |
|-------|-------------|
| `ai-ml-engineer` | AI/ML Engineer specializing in LLM integration, RAG systems, prompt engineering, agent design, embeddings, and Anthropic/OpenAI API usage. Distinct from data-scientist (statistics) — focus is applied AI features in production code. |
| `backend-developer` | Backend Specialist. Builds APIs, business logic, database models, integrations. Excludes specialist domains (billing/AI/data analytics) which have dedicated agents. |
| `billing-engineer` | FinTech / Monetization Engineer. Owns billing, payments, credits, subscriptions, financial data integrity. Path-scoped to billing/payments/credits modules. |
| `business-analyst` | Business Strategist for pricing models, cost/ROI analysis, financial modeling, competitor research. Commercial layer — distinct from product-manager (feature decisions). |
| `customer-success` | Customer Success — user onboarding, FAQ, support content, technical-to-user translation. Distinct from tech-writer (internal docs) and growth-marketer (acquisition). |
| `data-scientist` | Data Scientist focused on statistical analysis, analytics queries, dashboards, and data pipelines. Distinct from ai-ml-engineer (LLM/RAG/agents). |
| `devops-sre` | DevOps + SRE. Owns infra, CI/CD, deploy, monitoring, release process, versioning, runbooks. Includes release-management responsibilities. |
| `frontend-developer` | Frontend Specialist. Builds UI components with focus on state management, API integration, routing, and logic. Distinct from ui-ux-designer (visual design + polish). |
| `growth-marketer` | Growth + Content Strategist. SEO, copywriting, conversion, marketing campaigns. For deep technical SEO (sitemaps/schema/Google APIs) → install claude-seo plugin sub-agents. |
| `mobile-developer` | Mobile Engineer for native iOS/Android + cross-platform (React Native / Flutter). Owns platform-specific code; cross-platform UI logic may overlap with frontend-developer. |
| `performance-engineer` | Performance Engineer focused on load testing, profiling, latency optimization, bundle size, DB query performance, and p95/p99 metrics. Owns speed concern — distinct from qa-tester (correctness) and security-engineer (security). |
| `product-manager` | Product Manager for feature prioritization, roadmap, user requirements, spec writing. Distinct from business-analyst (financial/ROI) and growth-marketer (acquisition/conversion). |
| `qa-tester` | QA + Test Automation. Owns correctness — write/run tests, business logic verify, race conditions, integration. Universal floor + fallback when Codex/Gemini fail. |
| `security-engineer` | Security Engineer for vuln audit, pentest, system hardening, compliance (GDPR/SOC2/HIPAA). Owns security concern across all layers. |
| `system-architect` | Architect for system design, API contracts, data flow, technical decisions. Pre-engineering bottleneck — produces specs that engineers parallel-execute. Includes API + data architecture concerns. |
| `tech-writer` | Technical writer for code docs, API docs, READMEs, ADRs, internal docs. Distinct from customer-success (user-facing) and growth-marketer (marketing copy). |
| `ui-ux-designer` | UI/UX Designer + Frontend Polisher. Owns design system, components, visual polish, micro-interactions, accessibility (WCAG/a11y). |
| `universal-reviewer` | Code reviewer focused on code quality (logic / DRY / structure / smell). Distinct from qa-tester (correctness/tests) and security-engineer (security). Final judge for code-quality gate. |

@RTK.md
