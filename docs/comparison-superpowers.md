# Rolepod vs Superpowers — comparison

This doc compares Rolepod against [obra/superpowers](https://github.com/obra/superpowers), the closest peer in the AI-workflow-discipline space. Both are independent projects with different design choices; this is a respectful side-by-side, not a takedown.

## Positioning

> Superpowers makes one agent disciplined.
> Rolepod makes one agent operate like a disciplined full-stack software house.

Superpowers ships a tight single-agent workflow spine. Rolepod adopts a similar spine (`using-rolepod` → Define → Plan → Build → Verify → Review → Ship), then layers an 18-specialist software-house on top of it.

## Side-by-side

| Dimension | Superpowers | Rolepod |
|---|---|---|
| **Workflow router skill** | `using-superpowers` | `using-rolepod` |
| **Workflow spine** | brainstorm → worktree → plan → subagent → TDD → review → finish | Define → Plan → Build → Verify → Review → Ship |
| **Skill count** | ~25 focused skills | 43 skills (Tier 0 router + Tier 1 core 11 + Tier 2 specialist 29 + Tier 3 shims 2) |
| **Specialist agents** | none (one agent does it all) | 18 specialist agents (`backend-developer`, `frontend-developer`, `qa-tester`, `security-engineer`, `billing-engineer`, etc.) |
| **CLI support** | Claude Code (primary) | Claude Code + Codex CLI + Gemini CLI (native plugin/extension each) |
| **Hooks** | yes (Claude Code-native) | yes (Claude full; Codex opt-in via `plugin_hooks`; Gemini full) |
| **Sub-agent commit ban** | doctrine | **structural** (PreToolUse Bash hook denies via `agent_id` check) |
| **High-risk gates** | doctrine | structural (5 hooks: gate-reminder / precommit-gate / block-subagent-commit / cohesion-contract-check / verify-reminder) |
| **Behavior tests** | yes (`tests/skill-triggering/`) | yes (`tests/workflow-behavior/` — 10 cases, skip-friendly runner) |
| **Project / global install** | global only | both (`--scope=global` default, `--scope=project` for one-repo install) |
| **External adversarial reviewers** | qa-tester equivalent | qa-tester + Codex CLI + Gemini CLI (each routes via `reviewer-flow`) |
| **MemPalace cross-session memory** | none / external | optional via `--with-tools=mempalace` (SessionStart recall + Stop capture + PreCompact snapshot) |
| **GitNexus code intelligence** | none / external | optional via `--with-tools=gitnexus` (auto-reindex bg wrapper + stale-notice suppression) |

## Where Superpowers wins today

- **Path clarity by force of small surface.** Fewer skills = fewer wrong doors. Rolepod's specialist library is bigger; we counter by tiering (Tier 1 = default path, Tier 2 = domain-fired).
- **Single CLI focus.** Less surface to keep honest across vendors. Rolepod's multi-CLI parity is honest but adds maintenance: Codex hooks are opt-in (`plugin_hooks` flag), Gemini event model differs from Claude.

## Where Rolepod wins today

- **Software-house team.** 18 path-scoped specialists with hand-off protocols + cohesion contracts. Same path consistently picks the same specialist, parallelizable by path.
- **Structural enforcement, not doctrine alone.** Hooks block sub-agent commits, high-risk-without-test edits, ≥2 high-risk edits without reviewer, parallel-agent spawn without contract, commit on high-risk session without test. Doctrine survives flow-state drift only when backed by hard blocks.
- **Multi-CLI native primitives.** Same workflow runs on Claude Code, Codex CLI (cache populated, agents + skills load), Gemini CLI (extension + commands + hooks).
- **Honest docs about each CLI's quirks.** Codex `plugin_hooks` opt-in is called out explicitly, not glossed over.
- **Self-improving optional layer.** MemPalace KG hooks auto-recall + auto-capture session learnings when installed; system degrades gracefully when absent.

## Where Rolepod is intentionally NOT trying to beat Superpowers

- We don't out-skill-count Superpowers as a goal. More skills = worse routing if not tiered. The 4-tier index exists precisely so the default path stays small.
- We don't replicate `using-superpowers` verbatim. `using-rolepod` covers the same router responsibility but routes into Rolepod's spine + team-routing for specialist selection.
- We don't claim "100% no skip ever". The router has an explicit skip rule for trivial-answer-only tasks. User explicit instruction wins.

## Direction

Rolepod's roadmap (per `docs/rolepod-hardening-plan.md`) keeps Superpowers as the routing benchmark. When Superpowers ships a sharper trigger pattern or a new skill that fixes a real drift, Rolepod evaluates and either adopts (with attribution) or documents why the team-based design diverges.

Specific load-bearing ideas adopted from Superpowers:
- `using-<system>` router skill as Tier 0 (this hardening pass)
- root-cause-tracing recursion + three legitimate stopping points (folded into `systematic-debugging`, with attribution in that skill)

## Try both

Both projects ship under permissive licenses. There is no "winner" — they're designed for different team shapes:

- **Solo developer / single CLI / focused scope** → Superpowers is lean and disciplined.
- **Team / multi-CLI / cross-functional codebase / strong gate discipline needed** → Rolepod is built for that.

Pick the one that matches your repo. Don't run both on the same repo — the routers will fight.
