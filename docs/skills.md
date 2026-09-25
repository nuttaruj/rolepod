# Rolepod Skill Catalog (Core 10 + 2 helpers + 1 command + 1 on-demand)

Rolepod ships **14 skills total**: Core 10 (1 router + 9 workflow phase skills) plus two helper skills — `cross-family` (another CLI's review / critique / consult / draft) and `tdd-flow` (red → green at a seam) — called by the phase skills that need them, plus one explicit-invoke command — `deepen-codebase` (architecture report → pick a card → write-spec) — and one on-demand skill, `write-prototype` (a throwaway layout or logic demo that answers one spec question; write-spec offers it). There are no legacy compatibility shim skill files in the install tree. Old skill names are preserved only as documentation in [legacy-skill-map.md](legacy-skill-map.md).

No entry doc embeds a skill index. Each skill's `description:` is its routing surface, shown by the CLI; `using-rolepod` routes by its own table, so the Lead does not spend context choosing among dozens of tiny workflow fragments. Deep domain expertise lives in the 15 specialist agents.

## Tier model

| Tier | Purpose | Count | Fire on |
|---|---|---:|---|
| **0** | Workflow router | 1 | First read of every request |
| **1** | Core workflow skills | 9 | Phase match |
| — | Helpers (`cross-family`, `tdd-flow`) | 2 | Model-invoked by the phase skill that names them; allowed, never required |
| — | Command (`deepen-codebase`) | 1 | Explicit `/deepen-codebase` invocation only (`disable-model-invocation: true`): scope → one full-strength sub-agent (the Lead's model, shell access) walks the codebase and reproduces its claims → the Lead verifies → HTML report of deepening candidates (six fields per card, Strength badge, bugs found on the way, Top recommendation) → the user picks a card and is offered a `write-spec` on it |
| — | On demand (`write-prototype`) | 1 | write-spec offers it for a layout / state-logic question, or the user types /write-prototype; needs a settled spec (Product mode + one question); builds layout variants or a clickable logic demo in a spike worktree, never merged |
| **2** | Specialist public skills | 0 default | Domain depth lives in agents |
| **3** | Legacy compatibility shims | 0 | Removed; see migration map |

## Core 10 skills

| Phase | Skill | When it fires |
|-------|-------|---------------|
| Router | `using-rolepod` | Every request — picks the phase |
| Define | `write-spec` | Vague feature / scope unclear / high-risk surface — discovery dialogue + approval gate |
| Plan | `write-plan` | Approved spec or multi-file work — task list, test plan, agent routing, cohesion contracts |
| Build | `implement-plan` | Approved plan — TDD, bounded delegation, worktrees, all artifact-producing work |
| Build (bug) | `debug-issue` | Error / failing test / regression — reproduce → trace → failing test → minimal fix |
| Verify | `check-work` | Done claim before report — evidence (tests / build / curl / browser / log / screenshot) |
| Review | `review-code` | Before merge — multi-axis review, adversarial for high-risk diffs, reviewer routing |
| Ship | `finish-work` | "Ship / merge / push" — pre-merge gate, CI lanes, 4-option finish menu, launch ritual |
| Simplify | `simplify-code` | Over-engineered / duplicated / single-use abstraction — behavior-preserving cut |
| Recovery | `manage-context` | Stuck / context heavy / unfamiliar repo / advisor escalation / onboarding |

## Helpers — called by phase skills

| Skill | Called by | What it does |
|-------|-----------|---------------|
| `cross-family` | `review-code`, `write-spec`, `debug-issue`, `implement-plan` | Runs another CLI's review, critique, consult, or draft end to end. |
| `tdd-flow` | `implement-plan`, `debug-issue`, `simplify-code`, `check-work`, `write-plan` | Runs the failing-test-first red → green loop at a seam. |

## Domain expertise → specialist agents

Domain depth that used to live in standalone skills now lives in the 15 specialist agents (see [agents.md](agents.md)) and is routed from inside the Core 10 phase skills:

| Domain | Phase skill that routes here | Specialist agent |
|--------|------------------------------|------------------|
| Frontend implementation / components / state | `implement-plan` | `frontend-developer` |
| UI / interface / interaction / a11y / visual polish | `implement-plan` + `review-code` | `ui-ux-designer` |
| API / interface contract / module boundaries | `write-plan` | `system-architect` |
| Source-driven library / platform decisions | `write-plan` + `implement-plan` | `system-architect` + `ai-ml-engineer` |
| Security review / hardening / token / crypto | `review-code` | `security-engineer` |
| Performance audit / Core Web Vitals / perf | `review-code` + `check-work` | `performance-engineer` |
| Technical docs / ADRs / runbooks | `write-spec` + `implement-plan` | `content-strategist` (`audience: dev`) |
| User-facing content / FAQ / onboarding / error msgs | `write-spec` + `implement-plan` | `content-strategist` (`audience: user`) |
| Marketing / conversion copy / SEO | `write-spec` + `implement-plan` + `review-code` | `content-strategist` (`audience: prospect`) |
| CI/CD / deploy / monitoring / release | `finish-work` | `devops-sre` |
| User-visible tests (E2E / UI / contract) | `write-plan` + `check-work` | `qa-tester` |
| Unit tests for a slice (failing test first at the plan's seam) | `implement-plan` + `check-work` | the slice's owning role |
| LLM / RAG / Anthropic SDK / prompt cache | `implement-plan` | `ai-ml-engineer` |

## Skill table

Source of truth: the `## Core 10 skills` table above, and each skill's own frontmatter (`description:` + `when_to_use:`) in `core/skills/<name>/SKILL.md`.

## Execution context — inline vs fork

Skills can run inline (default — body becomes part of Lead's conversation) or as a forked subagent when a CLI supports that mode. All Core 10 phase skills run **inline** by default because they need the live conversation to make phase / approval / routing decisions.

`context: fork` may be added later when a phase skill grows a self-contained read-heavy sub-step, but Core 10 ships inline-only to keep the contract simple.

## How a skill is added or moved

1. Add `core/skills/<name>/SKILL.md` with `name:`, `description:` and `when_to_use:`, following the minimal skeleton in `core/skills/_template.md`.
2. Add the row to the `## Core 10 skills` table above — it is the full catalog; there is no generated index to regenerate.

## Skill design principles

- **One public skill per workflow phase.** Domain expertise belongs in agents unless users naturally invoke that workflow directly.
- **Each core skill is standalone.** A delegating step names its role and carries the line "No subagents → the Lead does it", and `## Next phase` names the fallback when the next skill is not available, so a copy-only install still works. It is complete as ONE file: a runtime that ships only SKILL.md (no `templates/` `references/` `examples/`) still runs the whole workflow — the artifact line IS the template (it names every section in the template's words; the file only adds the layout).
- **No hard dependency language.** Forbidden: `Requires <agent>`, `Always delegate to <agent>`, `Only works inside full Rolepod`.
- **Frontmatter triggers are the routing surface.** `description:` and `when_to_use:` must include the phrases users actually type.
- **Minimal skeleton, lean by the authoring guide.** Every skill follows the skeleton in `core/skills/_template.md` (frontmatter `name` + `description`, one-line framing, numbered steps each ending in a done-when, `## Next phase` with its fallback) and its writing levers; branch-only content moves into the skill's own `references/`. No prose line past 600 chars. Deep playbooks belong in agents.
- **Rule over mechanism.** A skill states the rule and the command; it does not narrate which hook denies under which sub-condition, exit codes, version history, or measurements — hooks print their own message when they bite.
