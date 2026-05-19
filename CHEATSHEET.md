# Rolepod — Cheatsheet

1-page reference. Works on all 3 CLIs (Claude / Codex / Gemini).

## Core layout — per CLI

| Component | Claude Code | Codex CLI | Gemini CLI |
|-----------|-------------|-----------|------------|
| Entry doc | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.gemini/GEMINI.md` |
| Always-on rules | `~/.claude/rules/always-on/` | (inlined in AGENTS.md) | (inlined in GEMINI.md) |
| Path-scoped rules | `~/.claude/rules/{code,test}/` (paths: glob) | (inlined) | (inlined) |
| Agents (18) | `~/.claude/agents/*.md` | `~/.codex/plugins/rolepod/agents/*.toml` | inlined in `GEMINI.md` |
| Skills (44) | `~/.claude/skills/<name>/SKILL.md` | `~/.codex/plugins/rolepod/skills/<name>/SKILL.md` | `~/.gemini/extensions/rolepod/skills/<name>/SKILL.md` |
| Hooks (Claude 9 / Codex 5 / Gemini 4) | `~/.claude/settings.json` | `~/.codex/plugins/rolepod/hooks/hooks.json` | `~/.gemini/extensions/rolepod/hooks/hooks.json` |
| Slash commands | `~/.claude/commands/*.md` | n/a | `~/.gemini/extensions/rolepod/commands/*.toml` |

## Active gates

| Gate | Trigger | Questions |
|------|---------|-----------|
| **Q1-Q4** | before edit | files>1 / verify-run / design-judgment / tools>3 → delegate |
| **S1-S5** | before commit | feature beyond / abstraction single-use / config nobody asked / defensive impossible / pattern 3+ |
| **T1-T6** | before commit | needs test / new pass / existing pass / fast / isolated / assertion correct |
| **F1-F5** | before done | hallucinated / scope creep / cascading / context loss / tool misuse |
| **CI 3-phase** | merge | Phase 1 always / Phase 2 path / Phase 3 nightly |
| **Hard stops** | escalation | 3rd agent / 3rd PR / file vs agent / destructive / 50k+ |

## Verify-first

```
Internal:  Read / gitnexus_context / run cmd / mempalace_kg_query
External:  WebFetch / WebSearch / CLI / MCP
Can't verify → "Assuming X. Risk Y. Verify by Z"
```

## Agent picker

| Need | Agent |
|------|-------|
| Spec / roadmap | `product-manager` |
| Pricing / ROI | `business-analyst` |
| SEO / marketing | `growth-marketer` |
| Onboarding / FAQ | `customer-success` |
| Architecture / API / data model | `system-architect` |
| Visual / Tailwind / a11y | `ui-ux-designer` |
| Backend (general) | `backend-developer` |
| Frontend logic | `frontend-developer` |
| iOS/Android | `mobile-developer` |
| Billing / payments | `billing-engineer` |
| LLM / RAG / agents | `ai-ml-engineer` |
| Analytics / stats | `data-scientist` |
| Tests / races | `qa-tester` |
| Security / compliance | `security-engineer` |
| Load / profile / p95 | `performance-engineer` |
| Code quality / DRY | `universal-reviewer` |
| Infra / CI/CD / deploy | `devops-sre` |
| Code docs / ADRs | `tech-writer` |

## Reviewer routing

| PR profile | Reviewer set |
|-----------|--------------|
| <5 files | qa-tester only |
| 5-30 files | Gemini + qa-tester |
| >30 files | Gemini + qa-tester + Codex |
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
  full stable / integration / docker / chaos / security deep / E2E / perf
```

## Auto-merge

User OK + commit + PR → ALL Phase 1 + triggered Phase 2 green → merge auto. NO re-ask.

## Workflow phases

```
1. Explore   → plan mode, read, understand
2. Plan      → simplicity check
3. Implement → TDD-light, every line traces to request
4. Pre-commit gate (S1-S5 + T1-T6 + F1-F5)
5. Reviewer  (per PR profile)
6. CI        (auto-merge after green)
```

## Lifecycle phases (6-phase taxonomy)

| Phase | Key skills | Key agents | Key gates |
|-------|------------|------------|-----------|
| **Define** | `spec-driven-development` | product-manager, system-architect | verify-first |
| **Plan** | `planning-and-task-breakdown`, `parallel-contract-orchestration`, `api-and-interface-design` | system-architect | Q1-Q4 |
| **Build** | `test-driven-development`, `frontend-ui-engineering`, `anti-spaghetti`, `claude-api`, `interface-design`, `interaction-design`, `doc-coauthoring`, `conversion-copywriting` | backend/frontend/mobile/billing/ai-ml/data, ui-ux-designer, tech-writer | S1-S5, F1-F5 |
| **Verify** | `systematic-debugging`, `webapp-testing`, `browser-testing-with-devtools`, `performance-optimization`, `security-and-hardening` | qa-tester, security-engineer, performance-engineer | T1-T6, verify-first |
| **Review** | `code-review-and-quality`, `code-simplification`, `web-design-guidelines`, `doubt-driven-development` | universal-reviewer, qa-tester | pre-merge-gate |
| **Ship** | `shipping-and-launch`, `ci-cd-and-automation`, `internal-comms`, `user-facing-content`, `documentation-and-adrs`, `seo` | devops-sre, growth-marketer, customer-success | CI 3-phase |
| **Cross-cutting** | `zoom-out`, `source-driven-development`, `context-engineering` | (any) | (any) |

## Stuck escalation (Sonnet/Haiku Lead)

```
1. Fresh angle / re-frame
2. MemPalace kg_query
3. Specialist subagent
4. Advisor (Opus)
5. Hard stop — ask user
```

Lead = Opus → skip Advisor.

## Rule files quick reference

| Trigger | File |
|---------|------|
| Pre-merge | skill `pre-merge-gate` |
| Spawn reviewer | skill `reviewer-flow` |
| Multi-agent / scope unclear | skill `triage-deep` |
| Pick agent | skill `team-routing` |
| Subagent protocol | `agent-protocol.md` |
| Tools (search/GitNexus/MemPalace) | `code-intel.md` |
| Workflow stage map | `code-intel-workflow.md` |
| Claim a fact | `verify-first.md` |
| Verify code change | skill `post-change-verify` |
| Tone / CEO modes | `communication.md` |
| Code edit pattern | `code-quality.md` |
| New project / `/init` | skill `new-project-onboarding` |
| Context / `/clear` / `/rewind` | skill `session-hygiene` |
| Stuck (Sonnet/Haiku) | skill `advisor-escalation` |
| Testing / CI lanes | `testing.md` |

## Key commands per-CLI

| Action | Claude | Codex | Gemini |
|--------|--------|-------|--------|
| Start | `claude` | `codex` | `gemini` |
| Reset context | `/clear` | exit + restart | exit + restart |
| Restore checkpoint | `/rewind` (or `Esc Esc`) | use git | use git |
| Manual compaction | `/compact <focus>` | auto | auto |
| Side question | `/btw` | n/a | n/a |
| Resume last | `claude --continue` | `codex resume` | `gemini` |
| Pick session | `claude --resume` | `codex resume --list` | n/a |
| Starter doc | `/init` | edit `~/.codex/AGENTS.md` | edit `~/.gemini/GEMINI.md` |
| One-shot | `claude -p "..."` | `codex exec "..."` | `gemini -p "..."` |
| Rolepod commands | `/rolepod` + `/rolepod-team` | n/a | `/rolepod /ship /review /test /plan /spec` |

> **Agent team (Claude only).** `/rolepod-team` spawns a real Claude Code agent team — multi-process teammates with shared task list + mailbox per [official spec](https://code.claude.com/docs/en/agent-teams). Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + v2.1.32+. Codex/Gemini have no teammate equivalent — use default Subagent dispatch via `team-routing` skill. See [docs/agent-teams.md](docs/agent-teams.md).

## Skill picker — quick lookup

Default Lead path = **Tier 0 + Tier 1** only (router + 11 core workflow skills). Specialists fire on domain match via `team-routing`. Full 44-skill catalog: [docs/skills.md](docs/skills.md).

| Task | Skill | Tier |
|------|-------|------|
| Spec before code | `spec-driven-development` | 1 |
| Plan → tasks | `planning-and-task-breakdown` | 1 |
| Parallel agents shared contract | `parallel-contract-orchestration` | 1 |
| Tests first / Prove-It | `test-driven-development` | 1 |
| Debug failing test (incl. root-cause tracing) | `systematic-debugging` | 1 |
| Subagent brief / two-stage review | `subagent-task-execution` | 1 |
| Multi-axis code review | `code-review-and-quality` | 1 |
| Reduce complexity | `code-simplification` | 1 |
| Verify edit landed | `post-change-verify` | 1 |
| Pre-merge gate | `pre-merge-gate` | 1 |
| Workflow router (always loaded first) | `using-rolepod` | 0 |
| API / interface design | `api-and-interface-design` | 2 |
| Production UI / dashboard / motion | `frontend-ui-engineering` / `interface-design` / `interaction-design` | 2 |
| Browser / Playwright | `browser-testing-with-devtools` / `webapp-testing` | 2 |
| Security hardening | `security-and-hardening` | 2 |
| Perf optimization | `performance-optimization` | 2 |
| Reviewer flow / adversarial | `reviewer-flow` / `doubt-driven-development` | 2 |
| ADR / docs / comms | `documentation-and-adrs` / `doc-coauthoring` / `internal-comms` / `user-facing-content` | 2 |
| Ship / CI / SEO | `shipping-and-launch` / `ci-cd-and-automation` / `seo` | 2 |
| Stuck / drift recovery | `zoom-out` / `triage-deep` / `advisor-escalation` | 2 |

Optional add-on skills (caveman, gitnexus-*, ui-ux-pro-max) integrate when the user installs them — see README → Recommended add-ons.

## Hooks active

Counts differ per CLI surface — Claude has the deepest matcher model so it carries enforcement hooks; Codex/Gemini run context hooks only.

### Claude (9 registered: 6 context + 3 enforcement)

| Event | Script | Role |
|-------|--------|------|
| SessionStart | `project-context-loader.sh` | git context + gates banner |
| SessionStart | `session-lock.sh` | sibling-session warning |
| PreToolUse (Bash) | `gitnexus-wrap.sh` | gitnexus index freshness |
| PreToolUse (Edit/Write on high-risk paths) | `gate-reminder.sh` | RED-test + reviewer-floor reminders |
| PreToolUse (Bash on git commit) | `precommit-gate.sh` | test gate, hard block |
| PreToolUse (Bash, sub-agent) | `block-subagent-commit.sh` | sub-agents can't commit/push |
| PreToolUse (Agent spawn) | `cohesion-contract-check.sh` | multi-agent contract required |
| PostToolUse (Edit/Write) | `verify-reminder.sh` | verify-after evidence nudge |
| PostToolUse (Bash) | `post-ship-detect.sh` | suggest `gitnexus analyze` after big merges |
| Stop | `session-unlock.sh` | release sibling lock |

### Codex (5 commands across 3 event classes)

| Event | Matcher | Script | Role |
|-------|---------|--------|------|
| SessionStart | `startup\|resume` | `project-context-loader.sh` | git context + gates banner |
| PreToolUse | `apply_patch` | `gate-reminder.sh` | RED-test + reviewer-floor reminders on high-risk paths |
| PreToolUse | `Bash` | `precommit-gate.sh` | test gate before commit |
| PostToolUse | `apply_patch` | `verify-reminder.sh` | verify-after evidence nudge |
| PostToolUse | `Bash` | `post-ship-detect.sh` | suggest `gitnexus analyze` after big merges |

Note: Codex hooks require `codex features enable plugin_hooks` (default `under development, false`). Without opt-in, hooks are registered but inert.

### Gemini (4 commands across 4 event classes)

| Event | Script | Role |
|-------|--------|------|
| SessionStart | `session-start.sh` | git context + gates banner |
| BeforeTool (write/replace/edit) | `before-tool.sh` | verify-first reminder |
| AfterTool (write/replace/edit) | `after-tool.sh` | verify-after evidence reminder |
| PreCompress | `pre-compress.sh` | session-snapshot before context compaction |

### External plugins (optional)

| Event | Hook (plugin) |
|-------|---------------|
| SessionStart | MemPalace recall |
| PreToolUse | GitNexus enrich / rtk proxy / qa-pass-check |
| PostToolUse Bash | GitNexus freshness check |
| PostToolUse Agent | qa-pass-record |
| Stop | MemPalace capture |
| PreCompact | MemPalace save state |

## Self-improvement loop

```
Session N → Stop hook → MemPalace KG saves learnings
Session N+1 → SessionStart → MemPalace recall → smarter
```

## Rule priority on conflict

1. User explicit instruction this turn
2. Project nested entry doc
3. Project root entry doc
4. `core/rules/always-on/*.md` (eager) + `core/rules/{code,test}/*.md` (paths: lazy)
5. Global entry doc
6. CLI vendor best practice

Conflict unsafe → ask user.

## Anti-bloat / anti-spaghetti

- Match existing style — don't refactor adjacent unbroken code
- One source of truth — search before adding helper/schema/type
- Same pattern in 3+ places → centralize
- No "just this one place" for auth/permissions/billing/credits/SSRF/cookies/logging/external API

## Fallback when tool unavailable

| Tool down | Fallback |
|-----------|----------|
| GitNexus | `rg` + Read |
| MemPalace | git log + READMEs |
| No internet | state assumption + risk |
| MCP server down | CLI / raw API |
| Codex/Gemini fail | qa-tester absorbs scope |

---

Full guide: your CLI's entry doc → drill into `core/rules/` via [`core/rules/INDEX.md`](core/rules/INDEX.md).
