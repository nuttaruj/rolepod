# Rolepod — Cheatsheet

1-page reference. Works on all 3 CLIs (Claude / Codex / Gemini).

## Core layout — per CLI

| Component | Claude Code | Codex CLI | Gemini CLI |
|-----------|-------------|-----------|------------|
| Entry doc | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.gemini/extensions/rolepod/GEMINI.md` |
| Always-on rules | `~/.claude/rules/always-on/` | (inlined in AGENTS.md) | (inlined in GEMINI.md) |
| Path-scoped rules | `~/.claude/rules/{code,test}/` (paths: glob) | (inlined) | (inlined) |
| Agents (18) | auto-discovered in plugin | `~/.codex/plugins/rolepod/agents/*.toml` | inlined in `GEMINI.md` |
| Skills (10 + 1 alias) | auto-discovered in plugin | `~/.codex/plugins/rolepod/skills/<name>/SKILL.md` | `~/.gemini/extensions/rolepod/skills/<name>/SKILL.md` |
| Hooks (core only) | 6 core hooks in `~/.claude/plugins/rolepod/hooks/hooks.json` | 3 core hooks in `~/.codex/plugins/rolepod/hooks/hooks.json` | 4 core hooks in `~/.gemini/extensions/rolepod/hooks/hooks.json` |
| Slash commands | `/rolepod-full` (skill) | `$rolepod-full` (skill) | `/rolepod-full` (skill) |

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

## Lifecycle phases (Core 10)

One public skill per phase. Domain depth lives in the 18 specialist agents and is routed from inside each phase skill.

| Phase | Phase skill | Key agents | Key gates |
|-------|-------------|------------|-----------|
| **Define** | `write-spec` | product-manager, system-architect, tech-writer, business-analyst | verify-first, approval gate, self-review |
| **Plan** | `write-plan` | system-architect, backend / frontend / mobile, qa-tester, security-engineer | Q1-Q4, cohesion contract before parallel spawn |
| **Build** | `implement-plan` | frontend / backend / mobile / billing / ai-ml / data, ui-ux-designer, tech-writer, growth-marketer, customer-success | S1-S5, F1-F5, TDD for risky paths |
| **Build (bug)** | `debug-issue` | qa-tester, security-engineer, performance-engineer, devops-sre | reproduce-first, trace upstream, failing test |
| **Verify** | `check-work` | qa-tester, performance-engineer, security-engineer, devops-sre | evidence required, browser observation for UI |
| **Review** | `review-code` | qa-tester (floor), security-engineer, performance-engineer, ui-ux-designer, system-architect, universal-reviewer | adversarial for high-risk surfaces |
| **Ship** | `finish-work` | devops-sre, qa-tester, security-engineer, product-manager | pre-merge gate (S+T+F), CI lanes |
| **Simplify** | `simplify-code` | universal-reviewer, system-architect, security-engineer | behavior-preserving (tests green before + after) |
| **Recovery** | `manage-context` | system-architect, qa-tester, universal-reviewer | 3-attempt advisor escalation, onboarding before edit |

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
| Pre-merge / ship / merge | skill `finish-work` |
| Spawn reviewer / adversarial review | skill `review-code` |
| Multi-agent / scope unclear | skill `manage-context` |
| Pick agent / cohesion contract | skill `write-plan` |
| Subagent protocol | `agent-protocol.md` |
| Tools (search/GitNexus/MemPalace) | `code-intel.md` |
| Workflow stage map | `code-intel-workflow.md` |
| Claim a fact | `verify-first.md` |
| Verify code change | skill `check-work` |
| Tone / CEO modes | `communication.md` |
| Code edit pattern | `code-quality.md` |
| New project / `/init` | skill `manage-context` |
| Context / `/clear` / `/rewind` | skill `manage-context` |
| Stuck (Sonnet/Haiku) | skill `manage-context` |
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
| Rolepod commands | `/rolepod-full` (skill) | `$rolepod-full` (skill) | `/rolepod-full` (skill) |

> **Agent team (Claude only).** With `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + v2.1.32+, `/rolepod-full` runs on the teammate backend — a real Claude Code agent team (multi-process teammates, shared task list + mailbox) per [official spec](https://code.claude.com/docs/en/agent-teams). Without it, `/rolepod-full` falls back to Subagent + Task dispatch. Codex/Gemini use native subagents. See [docs/agent-teams.md](docs/agent-teams.md).

## Skill picker — Core 10 quick lookup

Default Lead path = **Tier 0 + Tier 1** (router + 9 Core 10 phase skills) = 10 skills total. Domain depth lives in the 18 specialist agents. Legacy skill names are documented in [docs/legacy-skill-map.md](docs/legacy-skill-map.md) but are not installed as executable shims.

| Task | Skill | Tier | Specialist agent (when available) |
|------|-------|------|------------------------------------|
| Workflow router (always loaded first) | `using-rolepod` | 0 | — |
| Spec before code (vague feature, define scope, get approval) | `write-spec` | 1 | product-manager / system-architect / tech-writer |
| Plan → tasks (file list, test plan, agent routing, cohesion contract) | `write-plan` | 1 | system-architect / backend / frontend / mobile / qa-tester |
| Implement / build (TDD, bounded delegation, worktrees, frontend / API / content / platform) | `implement-plan` | 1 | frontend-developer / backend-developer / ui-ux-designer / ai-ml-engineer / tech-writer / growth-marketer / customer-success |
| Debug bug (reproduce → trace → failing test → minimal fix) | `debug-issue` | 1 | qa-tester / security-engineer / performance-engineer / devops-sre |
| Verify edit landed (tests / build / curl / browser / log / screenshot) | `check-work` | 1 | qa-tester / performance-engineer / security-engineer |
| Multi-axis review (security / perf / UI / architecture / adversarial) | `review-code` | 1 | qa-tester (floor) / security-engineer / performance-engineer / ui-ux-designer / universal-reviewer |
| Pre-merge gate / merge / launch / CI | `finish-work` | 1 | devops-sre / qa-tester |
| Simplify code / cut abstraction / centralize | `simplify-code` | 1 | universal-reviewer / system-architect |
| Stuck / drift / context heavy / unfamiliar repo / advisor | `manage-context` | 1 | system-architect / qa-tester (advisor → Opus) |

Optional add-on skills (caveman, gitnexus-*, ui-ux-pro-max) integrate when the user installs them — see README → Recommended add-ons.

## Hooks active — 6 core hooks (no add-on hooks)

### Claude (6 core hooks in plugin `hooks/hooks.json`, all self-guarded)

| Event | Script | Role |
|-------|--------|------|
| SessionStart | `project-context-loader.sh` | git context (repo / branch / dirty / recent / hot 7d) |
| SessionStart | `session-lifecycle.sh --lock` | sibling-session warning |
| PreToolUse (Edit/Write on high-risk paths) | `gate-reminder.sh` | schema-bound + RED-test + reviewer-floor |
| PreToolUse (Bash on git commit) | `precommit-gate.sh` | test gate, hard block on high-risk + 0 tests |
| PreToolUse (Bash, sub-agent) | `block-subagent-commit.sh` | sub-agents cannot commit/push/merge |
| PreToolUse (Agent spawn) | `cohesion-contract-check.sh` | multi-agent contract required (2+ spawns) |
| Stop | `session-lifecycle.sh --unlock` | release sibling lock |

### Codex (3 core hooks)

| Event | Matcher | Script | Role |
|-------|---------|--------|------|
| SessionStart | `startup\|resume` | `project-context-loader.sh` | git context (repo / branch / dirty / recent / hot 7d) |
| PreToolUse | `apply_patch` | `gate-reminder.sh` | schema-bound + RED-test + reviewer-floor on high-risk paths |
| PreToolUse | `Bash` | `precommit-gate.sh` | test gate before commit |

Note: Codex hooks require `codex features enable plugin_hooks` (default `under development, false`). Without opt-in, hooks are registered but inert. Rolepod ships no add-on hooks — MemPalace / GitNexus integrate via their own vendor plugins.

### Gemini (4 commands across 4 event classes)

| Event | Script | Role |
|-------|--------|------|
| SessionStart | `session-start.sh` | git context + gates banner |
| BeforeTool (write/replace/edit) | `before-tool.sh` | verify-first reminder |
| AfterTool (write/replace/edit) | `after-tool.sh` | verify-after evidence reminder |
| PreCompress | `pre-compress.sh` | session-snapshot before context compaction |

### External add-ons (optional)

MemPalace and GitNexus register their own hooks through their own vendor
plugins / CLI — rolepod ships none of them and does not wrap or bridge them.
Install per README → "Recommended add-ons"; each integrates when present.

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
