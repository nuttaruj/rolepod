# Rolepod Skill Catalog (Core 10 + 7 helpers + 2 commands + 1 on-demand)

Rolepod ships **20 skills total**: Core 10 (1 router + 9 workflow phase skills) plus seven helper skills — `cross-family` (another CLI's review / critique / consult), `tdd-flow` (red → green at a seam), `adversarial-review` (the R4 round-1 adversarial pass), `coordinating-parallel-tracks` (parallel task execution), `convening-code-review` (orders a review round: freeze the diff, dispatch the reviewer set, Fix-verify), `security-review` (the security engineer's threat-model method), and `check-work` (the done-claim helper; not a phase) — called by the phase skills that need them, plus two explicit-invoke commands — `deepen-codebase` (architecture report → pick a card → write-spec) and `rolepod-stats` (the project's evidence report) — and one on-demand skill: `write-prototype` (a throwaway layout or logic demo that answers one spec question; write-spec offers it). There are no legacy compatibility shim skill files in the install tree. Old skill names are preserved only as documentation in [legacy-skill-map.md](legacy-skill-map.md).

No entry doc embeds a skill index. Each skill's `description:` is its routing surface, shown by the CLI; `using-rolepod` routes by its own table, so the Lead does not spend context choosing among dozens of tiny workflow fragments. Deep domain expertise lives in the 4 agent types.

## Tier model

| Tier | Purpose | Count | Fire on |
|---|---|---:|---|
| **0** | Workflow router | 1 | Before the first action that creates, edits or deletes a file or runs a state-changing command |
| **1** | Core workflow skills | 9 | Phase match |
| — | Helpers (7 total) | 7 | Called by the phase skill or role that names them; allowed, never required. `cross-family`, `tdd-flow`, `adversarial-review`, `security-review`, `coordinating-parallel-tracks`, `convening-code-review`, `check-work` |
| — | Command (`deepen-codebase`) | 1 | Explicit `/deepen-codebase` invocation only (`disable-model-invocation: true`): scope → one full-strength sub-agent (the Lead's model, shell access) walks the codebase and reproduces its claims → the Lead verifies → HTML report of deepening candidates (six fields per card, Strength badge, bugs found on the way, Top recommendation) → the user picks a card and is offered a `write-spec` on it |
| — | Command (`rolepod-stats`) | 1 | User-invoked only (`disable-model-invocation: true`): type `/rolepod-stats` on Claude, `$rolepod-stats` on Codex; asked in words, the Lead tells you the command; runs its own `scripts/stats.sh` over `.rolepod/evidence/` — tier distribution, verify / review verdicts, strong-dispatch overrides, bypasses, gate, write-scope and external-verdict tables; the Lead and subagent tallies (which models ran) read Claude Code transcripts only |
| — | On demand (`write-prototype`) | 1 | write-spec offers it for a layout / state-logic question, or the user types /write-prototype; needs a settled spec (Product mode + one question); builds layout variants or a clickable logic demo in a spike worktree, never merged |
| **2** | Specialist public skills | 0 default | Domain depth lives in agents |
| **3** | Legacy compatibility shims | 0 | Removed; see migration map |

## Core 10 skills

| Phase | Skill | When it fires |
|-------|-------|---------------|
| Router | `using-rolepod` | Before the first action that creates, edits or deletes a file or runs a state-changing command — picks the tier and the first skill |
| Define | `write-spec` | Vague feature / scope unclear / high-risk surface — discovery dialogue + approval gate |
| Plan | `write-plan` | Approved spec or multi-file work — task list, test plan, agent routing, cohesion contracts |
| Build | `orchestrating-plans` (Lead) → `implement-plan` (owner) | Approved plan, inline R2 checklist or spec-as-plan list — one owner per task, TDD, worktrees, returns accepted, reviews at the seams |
| Build (bug) | `debug-issue` | Error / failing test / regression — reproduce → trace → failing test → minimal fix |
| Review | `convening-code-review` (Lead) → `review-code` (reviewers) | A diff, branch or PR, or a track end — freeze, pick the reviewer set, dispatch, Fix-verify; spec and standards axes; adversarial for high-risk |
| Ship | `finish-work` | "Ship / merge / push" — pre-merge gate, CI lanes, 3-option finish menu, launch ritual |
| Simplify | `simplify-code` | Over-engineered / duplicated / single-use abstraction — behavior-preserving cut |
| Recovery | `manage-context` | Stuck / context heavy / unfamiliar repo / advisor escalation / onboarding |

## Helpers — called by phase skills

| Skill | Called by | What it does |
|-------|-----------|---------------|
| `cross-family` | `convening-code-review`, `write-spec`, `debug-issue` | Runs another CLI's review, critique, or consult end to end. |
| `tdd-flow` | `implement-plan`, `debug-issue`, `simplify-code`, `check-work`, `write-plan` | Runs the failing-test-first red → green loop at a seam. |
| `adversarial-review` | `rolepod-reviewer` `lens: adversarial` | The adversarial reviewer's method (preloaded): stance, attack surface, report. The orderer picks the external `cross-family` run or the role in `convening-code-review`. |
| `security-review` | `rolepod-reviewer` `lens: security` | The security reviewer's method (preloaded): depth, threat model, an exploit scenario per BLOCKER / MAJOR, closure proof. |
| `coordinating-parallel-tracks` | `orchestrating-plans` | Orchestrates parallel task execution across plan tracks. |
| `convening-code-review` | `orchestrating-plans`, the Lead | Orders a review round: freezes the diff, dispatches the reviewer set, waits for every report, runs Fix-verify. |
| `check-work` | the Lead (a done claim past a trivial edit), `finish-work` | Proves the done claim with evidence (tests / build / curl / browser / log / screenshot) and guards against false greens. The Pre-merge gate calls it on the plan's full diff. |

## Domain expertise → the 4 agent types

Domain depth that used to live in standalone skills is carried by the 4 agent types (see [agents.md](agents.md)): `rolepod-builder` (every writer; the brief's `domain:` tag adds `architecture` or `writing`), `rolepod-reviewer` (one lens per dispatch: spec · standards · security · adversarial · perf · ui · arch), `rolepod-qa` and `rolepod-scout`. The domain hint goes into the brief, not a separate agent. Phase skills route to them:

| Domain | Phase skill that routes here | Agent type |
|--------|------------------------------|------------------|
| Implementation (frontend / backend / mobile / billing / AI / ML / infra, any domain) | `orchestrating-plans` | `rolepod-builder` |
| UI / interface / interaction / a11y / visual polish (review) | `convening-code-review` | `rolepod-reviewer` `lens: ui` |
| API / interface contract / module boundaries | `write-plan` | `rolepod-builder` with `domain: architecture` |
| Source-driven library / platform decisions | `write-plan` + `orchestrating-plans` | `rolepod-builder` with `domain: architecture` |
| Security review / hardening / token / crypto | `security-review` | `rolepod-reviewer` `lens: security` |
| Performance audit / Core Web Vitals / perf | `convening-code-review` + `check-work` | `rolepod-reviewer` `lens: perf` |
| Technical docs / ADRs / runbooks | `write-spec` + `orchestrating-plans` | `rolepod-builder` with `domain: writing` (`audience: dev`) |
| User-facing content / FAQ / onboarding / error msgs | `write-spec` + `orchestrating-plans` | `rolepod-builder` with `domain: writing` (`audience: user`) |
| Marketing / conversion copy / SEO | `write-spec` + `orchestrating-plans` + `convening-code-review` | `rolepod-builder` with `domain: writing` (`audience: prospect`) |
| CI/CD / deploy / monitoring / release | `finish-work` | `rolepod-builder` |
| User-visible tests (E2E / UI / contract) | `write-plan` + `check-work` | `rolepod-qa` |
| Unit tests for a slice (failing test first at the plan's seam) | `implement-plan` + `check-work` | the slice's owning `rolepod-builder` |
| LLM / RAG / Anthropic SDK / prompt cache | `orchestrating-plans` | `rolepod-builder` |

## Skill table

Source of truth: the `## Core 10 skills` table above, and each skill's own frontmatter (`description:`) in `core/skills/<name>/SKILL.md`.

## Execution context — inline vs fork

Skills can run inline (default — body becomes part of Lead's conversation) or as a forked subagent when a CLI supports that mode. All Core 10 phase skills run **inline** by default because they need the live conversation to make phase / approval / routing decisions.

`context: fork` may be added later when a phase skill grows a self-contained read-heavy sub-step, but Core 10 ships inline-only to keep the contract simple.

## How a skill is added or moved

1. Add `core/skills/<name>/SKILL.md` with `name:` and `description:`, following the minimal skeleton in `core/skills/_template.md`.
2. Add the row to the `## Core 10 skills` table above — it is the full catalog; there is no generated index to regenerate.

## Skill design principles

- **One public skill per workflow phase.** Domain expertise belongs in agents unless users naturally invoke that workflow directly.
- **Each core skill is standalone.** A delegating step names its role and carries the line "No subagents → the Lead does it", and `## Next phase` names the fallback when the next skill is not available, so a copy-only install still works. It is complete as ONE file: a runtime that ships only SKILL.md (no `templates/` `references/` `examples/`) still runs the whole workflow — the artifact line IS the template (it names every section in the template's words; the file only adds the layout).
- **No hard dependency language.** Forbidden: `Requires <agent>`, `Always delegate to <agent>`, `Only works inside full Rolepod`.
- **Frontmatter triggers are the routing surface.** `description:` must include the phrases users actually type.
- **Minimal skeleton, lean by the authoring guide.** Every skill follows the skeleton in `core/skills/_template.md` (frontmatter `name` + `description`, one-line framing, numbered steps each ending in a done-when, `## Next phase` with its fallback) and its writing levers; branch-only content moves into the skill's own `references/`. No prose line past 600 chars. Deep playbooks belong in agents.
- **Rule over mechanism.** A skill states the rule and the command; it does not narrate which hook denies under which sub-condition, exit codes, version history, or measurements — hooks print their own message when they bite.
