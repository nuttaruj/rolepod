# Rolepod — Cheatsheet

Quick reference for all 6 CLIs (Claude / Codex / Gemini / Cursor / Antigravity / opencode). Install, architecture, and full hook / model reference live in [README](README.md) and [docs/](docs/).

## Workflow — phase → skill

```
Define → Plan → Build → Verify → Review → Ship
```

The `using-rolepod` router fires first on every request and picks the phase.

| Phase | Skill | Fires when |
|-------|-------|-----------|
| Router | `using-rolepod` | every request — picks the phase |
| Define | `write-spec` | vague feature, scope unclear, high-risk surface |
| Plan | `write-plan` | spec approved, or work spans multiple files |
| Build | `implement-plan` | approved plan or a clear code task |
| Build (bug) | `debug-issue` | error / failing test / regression |
| Verify | `check-work` | a "done / fixed / works" claim, before reporting |
| Review | `review-code` | before merge / multi-file / high-risk diff |
| Ship | `finish-work` | "ship / merge / push / PR" |
| Simplify | `simplify-code` | over-engineered / duplicated / single-use abstraction |
| Recovery | `manage-context` | stuck / context heavy / unfamiliar repo / onboarding |

**Skip the spine** only for trivial answer-only work, a ≤5-line / single-file / zero-logic / non-high-risk diff, or an explicit user "skip" — and state the skip.

## Active gates

| Gate | When | Checks |
|------|------|--------|
| **Q1-Q4** | before edit | files >1 / must run-verify / design judgment / tools >3 → delegate |
| **S1-S5** | before commit | feature beyond request / single-use abstraction / config nobody asked / defensive-for-impossible / pattern in 3+ |
| **T1-T6** | before commit | needs a test / new pass / existing pass / fast / isolated / assertion correct |
| **F1-F5** | before done | hallucinated / scope creep / cascading error / context loss / tool misuse |
| **CI 3-phase** | merge | Phase 1 always (<5 min) / Phase 2 path-triggered / Phase 3 nightly |
| **Hard stops** | escalate | 3rd failed attempt / file vs claim / destructive cmd / 50k+ no convergence |

## Verify-first

```
Internal fact → Read / rg / run the command / git log
External fact → WebFetch / WebSearch / a CLI / an MCP tool
Can't verify  → state "Assuming X. Risk Y. Verify by Z" — never proceed silently
```

## Agent picker

| Need | Agent |
|------|-------|
| Spec / roadmap / requirements | `product-manager` |
| Pricing / ROI / competitor research | `product-manager` (`mode: commercial`) |
| Architecture / API contract / data model | `system-architect` |
| Visual / Tailwind / a11y / interaction | `ui-ux-designer` |
| Backend (general) | `backend-developer` |
| Frontend logic / components / state | `frontend-developer` |
| iOS / Android / React Native | `mobile-developer` |
| Billing / payments / credits | `billing-engineer` |
| LLM / RAG / prompts / agents | `ai-ml-engineer` |
| Analytics / statistics / dashboards | `data-scientist` |
| Tests / business logic / race conditions | `qa-tester` |
| Security / vulnerabilities / compliance | `security-engineer` |
| Load / profiling / p95-p99 | `performance-engineer` |
| Infra / CI-CD / deploy / release | `devops-sre` |
| Any human-readable written output (caller picks `audience: dev \| user \| prospect`) — code docs / ADRs / runbooks, FAQ / onboarding / in-app copy, SEO / marketing / conversion copy | `content-strategist` |
| Code quality / DRY / structure | `universal-reviewer` |

## Reviewer routing

`qa-tester` is the always-on internal floor. An external reviewer = a CLI from the user's **opt-in** cross-family pool on a different model **family** from the Lead — off until `~/.rolepod/cross-family` (or the project's `.rolepod/cross-family`) lists CLIs (`codex` / `claude` / `agy` / `cursor` / `opencode`; `none` = off; rolepod asks once, never enables it for you). `rolepod-cross-family --kind review --brief <brief> --attach <diff> --detach` picks the first usable one, runs it read-only on **its own default model** with a stated time budget (`codex timeout=1800` / `consult: agy codex` in the config), and anchors the pass (`--collect <job>` waits for it); `--pool` / `--candidates` show the resolution, `--kind consult` / `--kind advise --all` are the debug and plan channels. Gemini CLI is retired (agy is the Google family).

| PR profile | Reviewers |
|-----------|-----------|
| <5 files | qa-tester only |
| 5-30 files | qa-tester + 1 external |
| >30 files | qa-tester + 2 external |
| Money / auth (billing · payments · credits · auth · crypto · secrets · deletion) | qa-tester + external adversarial + internal strong — **both**, one dispatch |
| Other high-risk (migration / permissions / tokens / locks) | qa-tester + external adversarial (internal strong on apex or a weak external) |
| UI / frontend only | qa-tester + 1 external (breadth) |

## Stuck escalation

```
1. Re-frame — try a fresh angle
2. Re-check decision records / git log
3. Hand to a specialist subagent
4. Advisor (Opus)        ← skip if the Lead is already Opus
5. Hard stop — ask the user
```

## Key commands — per CLI

| Action | Claude | Codex | Gemini | Cursor | Antigravity | opencode |
|--------|--------|-------|--------|--------|-------------|----------|
| Start | `claude` | `codex` | `gemini` | open Cursor | `agy` | `opencode` |
| Force-full lifecycle | `/rolepod-full` | `$rolepod-full` | `/rolepod-full` | `/rolepod-full` | `/rolepod-full` | `/rolepod-full` |
| Reset context | `/clear` | exit + restart | exit + restart | new chat | exit + restart | new session |
| Restore checkpoint | `/rewind` (`Esc Esc`) | git | git | git | git | git |
| Manual compaction | `/compact <focus>` | auto | auto | auto | auto | auto |
| Resume last session | `claude --continue` | `codex resume` | `gemini` | last chat (sidebar) | `agy` | `opencode` (session list) |
| Pick a session | `claude --resume` | `codex resume --list` | — | chat history (sidebar) | — | session list |
| One-shot prompt | `claude -p "…"` | `codex exec "…"` | `gemini -p "…"` | Cmd+K | `agy -p "…"` | `opencode run "…"` |

## Hooks

12 Claude / 9 Codex / 5 Gemini / 3 Cursor / 6 Antigravity core hook scripts (opencode: plugin-event bridge, best-effort) — self-guarded, auto-fire, no add-on hooks. All CLIs fire hooks by default (Codex: `[features] hooks = true`, default-enabled). Full reference: [docs/hooks.md](docs/hooks.md).

## Evidence stats

`rolepod-stats` (on PATH after install.sh) — run inside any project: reads its `.rolepod/evidence/` and reports tier distribution, verify pass/fail, review verdicts, strong dispatches with/without explicit override (silent-downgrade audit), and unreasoned bypasses. `rolepod-junit <report.xml>` — counted JUnit totals + failed test names. In the source repo: `make stats`. Marketplace installs (no install.sh) carry the same scripts under the plugin's `scripts/` dir. Want a literal `make stats` in your own project? Add: `stats: ; @rolepod-stats`.

## Optional sibling plugins

Children plug in via **Extension Protocol v1** — parent writes `<git-root>/.rolepod/parent-active` at SessionStart, children read it to route evidence into `.rolepod/evidence/` for `check-work` aggregation. Spec: [docs/EXTENSION-PROTOCOL.md](docs/EXTENSION-PROTOCOL.md).

| Plugin | Adds | Used by |
|--------|------|---------|
| [rolepod-uiproof](https://github.com/nuttaruj/rolepod-uiproof) (v0.6+) | `/verify-ui`, `/audit-a11y`, `/visual-diff`, `/scaffold-e2e`, `/check-errors` — browser automation + UI evidence MCP (26 tools). | `check-work` (UI verify + a11y + visual), `debug-issue` (browser repro / console errors), `review-code` (a11y + visual regression). Falls back through [Playwright MCP](https://github.com/microsoft/playwright-mcp) → [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) → manual when absent. |
| [rolepod-wplab](https://github.com/nuttaruj/rolepod-wplab) (v1.9+) | 14 WordPress skills + 82 MCP tools — wp-cli + REST + scoped fs. | `check-work` (`/wp-health-check`), `debug-issue` (`/wp-diagnose`), `implement-plan` (`/wp-edit-*`, `/wp-scaffold`), `review-code` (`/wp-changes`). Skills narrow to tool-only role when parent is active; full flow when standalone. |
| [rolepod-seo](https://github.com/nuttaruj/rolepod-seo) (v0.3+) | `/seo-audit`, `/seo-fix-plan`, `/seo-schema`, `/seo-page-brief` — SEO / GEO / AEO site audit → scored report (chat + markdown + JSON sidecar + HTML, Artifact on Claude, Save-as-PDF via browser print) → fix plan. Skills only, no MCP, no hooks. | `content-strategist` (stops on technical SEO → `/seo-audit` / `/seo-schema`; `/seo-page-brief` feeds prospect copy); `/seo-fix-plan` routes fixes to wplab (WordPress meta), uiproof (rendered DOM / CWV), `frontend-developer` (code). |

## Rule priority on conflict

```
1. User instruction this turn
2. Project entry doc — nested, then repo root
3. Global entry doc / always-on core
4. CLI vendor best practice
```

Conflict that risks harm → ask the user.

---

Full reference: [docs/cli-support.md](docs/cli-support.md) · [docs/skills.md](docs/skills.md) · [docs/agents.md](docs/agents.md) · [docs/hooks.md](docs/hooks.md) · [docs/model-tier-policy.md](docs/model-tier-policy.md)
