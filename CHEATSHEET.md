# Rolepod — Cheatsheet

Quick reference for all 4 CLIs (Claude / Codex / Gemini / Cursor). Install, architecture, and full hook / model reference live in [README](README.md) and [docs/](docs/).

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
| Pricing / ROI / competitor research | `business-analyst` |
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

`qa-tester` is the always-on internal floor. An external reviewer = an installed CLI on a different model from the Lead (Claude / Codex / Gemini / Cursor, minus itself).

| PR profile | Reviewers |
|-----------|-----------|
| <5 files | qa-tester only |
| 5-30 files | qa-tester + 1 external |
| >30 files | qa-tester + 2 external |
| High-risk (auth / billing / migration / locks) | qa-tester + external adversarial |
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

| Action | Claude | Codex | Gemini | Cursor |
|--------|--------|-------|--------|--------|
| Start | `claude` | `codex` | `gemini` | open Cursor |
| Force-full lifecycle | `/rolepod-full` | `$rolepod-full` | `/rolepod-full` | `/rolepod-full` |
| Reset context | `/clear` | exit + restart | exit + restart | new chat |
| Restore checkpoint | `/rewind` (`Esc Esc`) | git | git | git |
| Manual compaction | `/compact <focus>` | auto | auto | auto |
| Resume last session | `claude --continue` | `codex resume` | `gemini` | last chat (sidebar) |
| Pick a session | `claude --resume` | `codex resume --list` | — | chat history (sidebar) |
| One-shot prompt | `claude -p "…"` | `codex exec "…"` | `gemini -p "…"` | Cmd+K |

## Hooks

7 Claude / 3 Codex / 4 Gemini / 3 Cursor core hooks — self-guarded, auto-fire, no add-on hooks. Codex hooks stay inert until `codex features enable plugin_hooks`. Cursor + Gemini hooks fire by default. Full reference: [docs/hooks.md](docs/hooks.md).

## Optional sibling plugins

Children plug in via **Extension Protocol v1** — parent writes `<git-root>/.rolepod/parent-active` at SessionStart, children read it to route evidence into `.rolepod/evidence/` for `check-work` aggregation. Spec: [docs/EXTENSION-PROTOCOL.md](docs/EXTENSION-PROTOCOL.md).

| Plugin | Adds | Used by |
|--------|------|---------|
| [rolepod-uiproof](https://github.com/nuttaruj/rolepod-uiproof) (v0.6+) | `/verify-ui`, `/audit-a11y`, `/visual-diff`, `/scaffold-e2e`, `/check-errors` — browser automation + UI evidence MCP (26 tools). | `check-work` (UI verify + a11y + visual), `debug-issue` (browser repro / console errors), `review-code` (a11y + visual regression). Falls back through [Playwright MCP](https://github.com/microsoft/playwright-mcp) → [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) → manual when absent. |
| [rolepod-wplab](https://github.com/nuttaruj/rolepod-wplab) (v1.9+) | 14 WordPress skills + 82 MCP tools — wp-cli + REST + scoped fs. | `check-work` (`/wp-health-check`), `debug-issue` (`/wp-diagnose`), `implement-plan` (`/wp-edit-*`, `/wp-scaffold`), `review-code` (`/wp-changes`). Skills narrow to tool-only role when parent is active; full flow when standalone. |

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
