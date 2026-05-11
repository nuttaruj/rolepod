# Rolepod — Cheatsheet

1-page reference for the workflow system at `~/.claude/`.

## Core layout

```
CLAUDE.md              # always loaded — workflow gates + role
rules/                 # lazy-load via Read on trigger
agents/                # 18 specialists (path/concern ownership)
skills/                # auto-pull on description match
hooks/                 # auto-fire (deterministic)
```

## Active gates (memorize)

| Gate | Trigger | Questions |
|------|---------|-----------|
| **Q1-Q4** | before any code edit | files>1 / verify-run / design-judgment / tools>3 → delegate |
| **S1-S5** | before commit (simplicity) | feature beyond / abstraction single-use / config nobody asked / defensive impossible / pattern in 3+ |
| **T1-T5** | before commit (test) | task needs test / new pass / existing pass / fast / isolated |
| **CI 3-phase** | merge | Phase 1 always / Phase 2 path-triggered / Phase 3 nightly |
| **Hard stops** | escalation | 3rd agent / 3rd PR / file vs agent / destructive / 50k+ |

## Verify-first

```
Internal:  Read / gitnexus_context / run cmd / mempalace_kg_query
External:  WebFetch / WebSearch / CLI / MCP
Can't verify → "Assuming X. Risk Y. Verify by Z"
```

## Agent picker (one-line)

| Need | Agent |
|------|-------|
| Spec / roadmap / user story | `product-manager` |
| Pricing / ROI / competitor | `business-analyst` |
| SEO / marketing / conversion | `growth-marketer` |
| Onboarding / FAQ / support | `customer-success` |
| Architecture / API contract / data model | `system-architect` |
| Visual / Tailwind / a11y | `ui-ux-designer` |
| Backend (excl. specialist paths) | `backend-developer` |
| Frontend logic (state/API/routing) | `frontend-developer` |
| iOS/Android native | `mobile-developer` |
| Billing / payments / credits | `billing-engineer` |
| LLM / RAG / agents / prompts | `ai-ml-engineer` |
| Analytics / stats / pipelines | `data-scientist` |
| Tests / business logic / races | `qa-tester` |
| Security / compliance / pentest | `security-engineer` |
| Load test / profile / p95 | `performance-engineer` |
| Code quality / DRY / structure | `universal-reviewer` |
| Infra / CI/CD / deploy / release | `devops-sre` |
| Code docs / READMEs / ADRs | `tech-writer` |

## Reviewer routing (PR profile)

| PR profile | Reviewer set |
|-----------|--------------|
| <5 files (hotfix) | qa-tester only |
| 5-30 files (feature) | Gemini + qa-tester |
| >30 files (refactor) | Gemini + qa-tester + Codex |
| High-risk (auth/billing/migration/locks) | Codex adversarial + qa-tester |
| UI/frontend only | Gemini + qa-tester |

**qa-tester = minimum floor + universal fallback.**

## CI 3-phase

```
Phase 1 (REQUIRED, every PR, <5 min):
  lint / typecheck / smoke unit / auth guard / tenant isolation /
  money core / migration apply / build

Phase 2 (REQUIRED when path matched):
  <path-glob> touched → <module> full tests

Phase 3 (NOT required, cron):
  full stable / integration full / docker / chaos / security deep /
  E2E / perf benchmark
```

## Auto-merge

User OK + commit + PR → ALL Phase 1 + triggered Phase 2 green → merge auto. NO re-ask.

## Workflow phases

```
1. Explore  (plan mode, read, understand)
2. Plan     (Ctrl+G to edit, simplicity check)
3. Implement (TDD-light, every line traces to request)
4. Pre-commit gate (S1-S5 simplicity + T1-T5 test)
5. Reviewer (per PR profile)
6. CI (auto-merge after green)
```

## Lifecycle phases (6-phase taxonomy)

| Phase | Trigger | Key skills | Key agents | Key gates |
|-------|---------|------------|------------|-----------|
| **Define** | new feature / spec | `spec-driven-development` | product-manager, system-architect | verify-first (intent) |
| **Plan** | spec → tasks | `planning-and-task-breakdown`, `parallel-contract-orchestration`, `api-and-interface-design` | system-architect | Q1-Q4 |
| **Build** | code edit | `test-driven-development`, `frontend-ui-engineering`, `anti-spaghetti`, `claude-api`, `interface-design`, `interaction-design`, `doc-coauthoring`, `conversion-copywriting` | backend/frontend/mobile/billing/ai-ml/data, ui-ux-designer, tech-writer | S1-S5, F1-F5 |
| **Verify** | post-edit evidence | `debugging-and-error-recovery`, `webapp-testing`, `browser-testing-with-devtools`, `performance-optimization`, `security-and-hardening` | qa-tester, security-engineer, performance-engineer | T1-T6, verify-first |
| **Review** | pre-merge | `code-review-and-quality`, `code-simplification`, `web-design-guidelines`, `doubt-driven-development` | universal-reviewer, qa-tester | pre-merge-gate, hard stops |
| **Ship** | deploy | `shipping-and-launch`, `ci-cd-and-automation`, `deprecation-and-migration`, `internal-comms`, `user-facing-content`, `documentation-and-adrs`, `seo` | devops-sre, growth-marketer, customer-success | CI 3-phase |
| **Cross-cutting** | any phase | `zoom-out`, `source-driven-development`, `context-engineering` | (any) | (any) |

## Stuck escalation (Sonnet/Haiku Lead)

```
1. Fresh angle / re-frame
2. MemPalace kg_query (past similar?)
3. Specialist subagent (different context)
4. Advisor (Opus) — consult bigger model
5. Hard stop — ask user
```

Lead = Opus → skip Advisor.

## Rule files quick reference

| Trigger | File |
|---------|------|
| Pre-merge | `pre-merge-gate.md` |
| Spawn reviewer | `reviewer-flow.md` |
| Multi-agent / scope unclear | `triage-deep.md` |
| Pick agent / parallel plan | `team-org.md` |
| Subagent protocol | `agent-protocol.md` |
| Tools (search/GitNexus/MemPalace/CLI) | `code-intel.md` |
| Workflow stage map | `code-intel-workflow.md` |
| Claim a fact | `verify-first.md` |
| Verify code change | `verification.md` |
| Tone / language | `communication.md` |
| Code edit pattern | `code-quality.md` |
| New project / `/init` | `new-project.md` |
| Context full / `/clear` / `/rewind` | `session-management.md` |
| Stuck (Sonnet/Haiku) | `advisor.md` |
| Testing / CI lanes | `testing.md` |

## Key commands

| Command | Purpose |
|---------|---------|
| `/clear` | reset context between unrelated tasks |
| `/rewind` (Esc Esc) | restore checkpoint |
| `/compact <focus>` | manual compaction |
| `/btw` | side question (no context bloat) |
| `claude --continue` | resume last session |
| `claude --resume` | pick from list |
| `/init` | generate starter CLAUDE.md (Anthropic native) |

## Skill picker (when many skills look similar)

| Task type | Use skill |
|-----------|-----------|
| Debug failing test/behavior | `debugging-and-error-recovery` |
| Stuck/drifted/lost focus | `zoom-out` |
| Write tests first | `test-driven-development` |
| Run Playwright tests | `webapp-testing` |
| Inspect browser DOM/console | `browser-testing-with-devtools` |
| Code review (multi-axis) | `code-review-and-quality` |
| Check duplication/dead code | `anti-spaghetti` |
| Reduce code complexity | `code-simplification` |
| Build production UI | `frontend-ui-engineering` |
| Design system / palette / fonts | `ui-ux-pro-max` |
| Dashboard / admin panel | `interface-design` |
| WCAG / a11y audit | `web-design-guidelines` |
| Microinteractions / motion | `interaction-design` |
| HTML artifacts | `web-artifacts-builder` |
| ADR / architecture decision | `documentation-and-adrs` |
| Co-author docs/spec | `doc-coauthoring` |
| Internal company comms | `internal-comms` |
| User-facing FAQ/help | `user-facing-content` |
| Marketing copy / blog | `conversion-copywriting` |
| SEO audit | `seo` |
| API/interface design | `api-and-interface-design` |
| Spec before code | `spec-driven-development` |
| Source-grounded implementation | `source-driven-development` |
| Plan → tasks | `planning-and-task-breakdown` |
| Small incremental steps | `incremental-implementation` |
| Build CI/CD pipeline | `ci-cd-and-automation` |
| Pre-launch checklist | `shipping-and-launch` |
| Performance optimization | `performance-optimization` |
| Security hardening | `security-and-hardening` |
| Deprecation / migration | `deprecation-and-migration` |
| Git workflow patterns | `git-workflow-and-versioning` |
| GitNexus impact / explore / debug / refactor / PR review | `gitnexus-*` (7 skills) |
| Anthropic API / prompt caching | `claude-api` |
| Optimize agent context | `context-engineering` |
| Build MCP server | `mcp-builder` |
| Refine vague idea | `idea-refine` |
| Create new skill | `skill-creator` |
| Discover skills | `using-agent-skills` |
| Excel / Word / PPT / PDF | `xlsx` / `docx` / `pptx` / `pdf` |
| Visual art (PNG/PDF) | `canvas-design` |

## Hooks active

| Event | Hook |
|-------|------|
| SessionStart | mempalace recall + project context loader |
| PreToolUse | rtk + qa-pass-check + gitnexus enrich |
| PostToolUse Bash | gitnexus freshness + post-ship detect |
| PostToolUse Agent | qa-pass-record |
| Stop | mempalace capture (self-improvement) |
| PreCompact | mempalace save state |

## Self-improvement loop

```
Session N → Stop hook → MemPalace KG saves learnings
Session N+1 → SessionStart → MemPalace recall → smarter
```

## Rule priority on conflict

1. User explicit instruction this turn
2. Project nested CLAUDE.md
3. Project root CLAUDE.md
4. ~/.claude/rules/*.md
5. ~/.claude/CLAUDE.md
6. Anthropic best practice

Conflict unsafe → ask user.

## Anti-bloat / anti-spaghetti

- Match existing style, don't refactor adjacent unbroken code
- One source of truth (search before adding helper/schema/type)
- Same pattern in 3+ places → centralize
- No "just this one place" for auth/permissions/billing/credits/SSRF/cookies/logging/external API

## Fallback when tool unavailable

| Tool down | Fallback |
|-----------|----------|
| GitNexus | `rg` + Read for context |
| MemPalace | git log + READMEs |
| No internet | state assumption + risk explicitly |
| MCP server down | CLI tool / raw API |
| Codex/Gemini fail | qa-tester takes over scope |

---

For full guide: read `~/.claude/CLAUDE.md` then drill into `rules/` files via INDEX.md.
