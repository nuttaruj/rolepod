# Rules Index

Layout (Anthropic `.claude/rules/` spec):

- `always-on/` — eager-loaded every session. Small, judgment-shaping.
- `code/` — lazy via `paths:` frontmatter (source code globs).
- `test/` — lazy via `paths:` frontmatter (test file globs).

Skills (`core/skills/<name>/SKILL.md`) load on trigger phrase via `description:` — not rules.

## Always-on rules (eager)

| File | What |
|------|------|
| `always-on/communication.md` | Tone, language, output volume, CEO oversight modes |
| `always-on/verify-first.md` | Verify facts before claims |
| `always-on/code-search.md` | Tool picker — GitNexus for symbols, rg for plain text |
| `always-on/agent-protocol.md` | Mandatory protocol for every subagent |

## Path-scoped rules (lazy, load when matching path touched)

| File | Triggers on |
|------|-------------|
| `code/code-quality.md` | Source files (ts/tsx/js/py/go/rs/rb/java/kt/swift/cs/cpp/c/h/php/lua/sh) |
| `code/code-intel.md` | Same source-file globs — GitNexus / MemPalace / rg / CLI tool reference |
| `code/code-intel-workflow.md` | Same source-file globs — when to fire each code-intel tool |
| `test/testing.md` | `test/**`, `tests/**`, `__tests__/**`, `*test*`, `*spec*`, `*.test.*`, `*.spec.*` |

## Skill triggers (trigger-phrase load, not rules)

| Trigger | Skill |
|---------|-------|
| Before push/merge, `gh pr merge`, `git push`, ship gate, "ship it" | `finish-work` |
| Spawn reviewer, Codex/Gemini review, code review cascade, adversarial review | `review-code` |
| Stuck, consult Opus, advice mode, `/advice`, third agent same issue | `advisor-escalation` |
| `/clear`, `/compact`, `/rewind`, long session, context near limit, switching task | `session-hygiene` |
| Multi-file task, scope unclear, drift suspected, mid-implement creep, phase abort | `triage-deep` |
| First time in repo, `/init`, unfamiliar project, bootstrap mode | `new-project-onboarding` |
| Choose agent, multi-agent parallel, team layout, agent picker, cohesion contract | `write-plan` |
| Verify change, evidence after edit, verify build, verify task done | `check-work` |

## Maintenance

Add rule only after a real mistake would have been prevented. Prune monthly.

- Must happen 100% of time → Hook (`.claude/settings.json`), NOT file
- Rarely needed → Skill (`core/skills/<name>/SKILL.md`), NOT rule
- Path-scoped → `paths:` frontmatter in `code/` or `test/`
- Always-on → keep small; judgment, not deep procedure
