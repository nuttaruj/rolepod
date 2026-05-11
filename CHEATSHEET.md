# Rolepod — Cheatsheet

1-page reference. Works on all 3 supported CLIs (Claude Code / Codex CLI / Gemini CLI).

## Core layout — per CLI

| Component | Claude Code | Codex CLI | Gemini CLI |
|-----------|-------------|-----------|------------|
| Entry doc (always loaded) | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.gemini/GEMINI.md` |
| Lazy-load rules | `~/.claude/rules/` | (same content inlined in AGENTS.md) | (same content inlined in GEMINI.md) |
| Agents (18 specialists) | `~/.claude/agents/*.md` | `~/.codex/plugins/rolepod/agents/*.toml` | inlined roster in `GEMINI.md` |
| Skills (34 bundled) | `~/.claude/skills/<name>/SKILL.md` | `~/.codex/plugins/rolepod/skills/<name>/SKILL.md` | `~/.gemini/extensions/rolepod/skills/<name>/SKILL.md` |
| Hooks (3 scripts) | registered in `~/.claude/settings.json` | `~/.codex/plugins/rolepod/hooks/hooks.json` | `~/.gemini/extensions/rolepod/hooks/hooks.json` |
| Slash commands | `~/.claude/commands/*.md` + native | n/a (Codex schema) | `~/.gemini/extensions/rolepod/commands/*.toml` |

## Active gates (memorize)

| Gate | Trigger | Questions |
|------|---------|-----------|
| **Q1-Q4** | before any code edit | files>1 / verify-run / design-judgment / tools>3 → delegate |
| **S1-S5** | before commit (simplicity) | feature beyond / abstraction single-use / config nobody asked / defensive impossible / pattern in 3+ |
| **T1-T6** | before commit (test) | task needs test / new pass / existing pass / fast / isolated / assertion correct (1-char bug still passes?) |
| **F1-F6** | before declaring done | hallucinated action / scope creep / cascading error / context loss / tool misuse / structurally fixable |
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
4. Pre-commit gate (S1-S5 simplicity + T1-T6 test + F1-F6 failure-mode)
5. Reviewer (per PR profile)
6. CI (auto-merge after green)
```

## Lifecycle phases (6-phase taxonomy)

| Phase | Trigger | Key skills | Key agents | Key gates |
|-------|---------|------------|------------|-----------|
| **Define** | new feature / spec | `spec-driven-development` | product-manager, system-architect | verify-first (intent) |
| **Plan** | spec → tasks | `planning-and-task-breakdown`, `parallel-contract-orchestration`, `api-and-interface-design` | system-architect | Q1-Q4 |
| **Build** | code edit | `test-driven-development`, `frontend-ui-engineering`, `anti-spaghetti`, `claude-api`, `interface-design`, `interaction-design`, `doc-coauthoring`, `conversion-copywriting` | backend/frontend/mobile/billing/ai-ml/data, ui-ux-designer, tech-writer | S1-S5, F1-F6 |
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

## Key commands — per-CLI equivalents

| Action | Claude Code | Codex CLI | Gemini CLI |
|--------|-------------|-----------|------------|
| Start session | `claude` | `codex` | `gemini` |
| Reset context (unrelated task) | `/clear` | exit + restart `codex` | exit + restart `gemini` |
| Restore checkpoint | `/rewind` (or `Esc Esc`) | n/a — use git | n/a — use git |
| Manual compaction | `/compact <focus>` | auto (Codex handles natively) | auto (Gemini handles natively) |
| Side question (no context bloat) | `/btw` | n/a | n/a |
| Resume last session | `claude --continue` | `codex resume` | `gemini` (history auto) |
| Pick from session list | `claude --resume` | `codex resume --list` | n/a |
| Starter entry doc | `/init` (Anthropic native) | edit `~/.codex/AGENTS.md` directly | edit `~/.gemini/GEMINI.md` directly |
| One-shot exec | `claude -p "..."` | `codex exec "..."` | `gemini -p "..."` |
| Rolepod slash commands shipped | `/careful` + `/team-define /team-plan /team-build /team-verify /team-review /team-ship` | n/a (Codex schema lacks commands today) | `/careful /ship /review /test /plan /spec` |

> **Team workflow (Claude) — two opt-in patterns.**
> - "use team" (broad) → full lifecycle: all 6 phases use team recipes
> - `/team-build` / `/team-verify` / etc. (surgical) → only that phase uses team; rest stay default Subagent
>
> Default Subagent pattern is unchanged when neither trigger fires. Mandatory gates (S1-S5, T1-T6, F1-F6, pre-merge, CI 3-phase) apply in all cases. See [docs/agent-teams.md](docs/agent-teams.md).

## Skill picker (when many skills look similar)

The 34 rolepod-bundled skills. External plugin skills (caveman, gitnexus-*, ui-ux-pro-max, xlsx/docx/pptx/pdf, skill-creator, web-artifacts-builder, idea-refine, mcp-builder, git-workflow-and-versioning, canvas-design) ship via separate marketplaces — not included in this list.

| Task type | Use skill |
|-----------|-----------|
| Spec before code | `spec-driven-development` |
| Plan → tasks | `planning-and-task-breakdown` |
| Parallel agents need shared contract | `parallel-contract-orchestration` |
| API / interface design | `api-and-interface-design` |
| Write tests first / Prove-It | `test-driven-development` |
| Build production UI | `frontend-ui-engineering` |
| Dashboard / admin panel | `interface-design` |
| Microinteractions / motion | `interaction-design` |
| Marketing copy / landing | `conversion-copywriting` |
| Co-author docs / spec | `doc-coauthoring` |
| Anthropic API / prompt caching | `claude-api` |
| Check duplication / dead code / drift | `anti-spaghetti` |
| Subagent task brief / two-stage review | `subagent-task-execution` |
| Real filesystem isolation for agents | `using-worktrees` |
| Debug failing test / behavior | `debugging-and-error-recovery` |
| Trace error to true cause | `root-cause-tracing` |
| Run Playwright tests | `webapp-testing` |
| Inspect browser DOM / console | `browser-testing-with-devtools` |
| Performance optimization | `performance-optimization` |
| Security hardening | `security-and-hardening` |
| Code review (multi-axis) | `code-review-and-quality` |
| Reduce code complexity | `code-simplification` |
| WCAG / a11y audit | `web-design-guidelines` |
| Adversarial review (irreversible ops) | `doubt-driven-development` |
| Pre-launch checklist | `shipping-and-launch` |
| Build CI/CD pipeline | `ci-cd-and-automation` |
| ADR / architecture decision | `documentation-and-adrs` |
| Internal company comms | `internal-comms` |
| User-facing FAQ / help / error msgs | `user-facing-content` |
| SEO audit | `seo` |
| Finishing a dev branch (4-option menu) | `finishing-a-development-branch` |
| Stuck / drifted / lost focus | `zoom-out` |
| Source-grounded implementation | `source-driven-development` |
| Optimize agent context | `context-engineering` |

## Hooks active

Rolepod ships **3 hooks** per CLI (auto-registered on install). External plugins (MemPalace, GitNexus, rtk, qa-pass-check) add their own hooks when installed.

### Rolepod-shipped (Claude / Codex — same 3 scripts)

| Event | Hook script | What |
|-------|-------------|------|
| SessionStart | `project-context-loader.sh` | git branch + recent commits + gates banner |
| PostToolUse (Edit/Write) | `verify-reminder.sh` | nudges to verify after code edits |
| PostToolUse (Bash) | `post-ship-detect.sh` | suggests `gitnexus analyze` after big merges |

### Rolepod-shipped (Gemini — 3 scripts, Gemini envelope)

| Event | Hook script | What |
|-------|-------------|------|
| SessionStart | `session-start.sh` | git context + gates banner |
| BeforeTool (write_file / replace / edit) | `before-tool.sh` | verify-first reminder before edits |
| AfterTool (write_file / replace / edit) | `after-tool.sh` | verify-after evidence reminder |

### External plugins (optional, not part of rolepod core)

| Event | Hook (plugin) |
|-------|---------------|
| SessionStart | MemPalace recall |
| PreToolUse | GitNexus enrich / rtk proxy / qa-pass-check |
| PostToolUse Bash | GitNexus freshness check |
| PostToolUse Agent | qa-pass-record |
| Stop | MemPalace capture (self-improvement loop) |
| PreCompact | MemPalace save state |

## Self-improvement loop

```
Session N → Stop hook → MemPalace KG saves learnings
Session N+1 → SessionStart → MemPalace recall → smarter
```

## Rule priority on conflict

1. User explicit instruction this turn
2. Project nested entry doc (CLAUDE.md / AGENTS.md / GEMINI.md)
3. Project root entry doc
4. `core/rules/*.md` (lazy-load on trigger)
5. Global entry doc (~/.claude/CLAUDE.md / ~/.codex/AGENTS.md / ~/.gemini/GEMINI.md)
6. CLI vendor best practice

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

For full guide: read your CLI's entry doc (`~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md` / `~/.gemini/GEMINI.md`) then drill into `core/rules/` files via [`core/rules/INDEX.md`](core/rules/INDEX.md).
