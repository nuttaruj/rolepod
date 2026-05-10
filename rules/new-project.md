# New Project — fast onboarding

Read when: first time in unfamiliar project / bootstrap session with no prior context.

## Bootstrap mode — first session ever in project

No MemPalace data, GitNexus not indexed, no project CLAUDE.md → degraded but functional:

| Feature | Bootstrap fallback |
|---------|-------------------|
| MemPalace recall | git log + git blame + READMEs as substitute |
| GitNexus impact | `rg` for symbol + manual Read for context |
| Project conventions | Read 2-3 nearby files before any edit |
| Past decisions | None — ask user when ambiguous |
| Auto-context loader | Reads git log only — no decision history |

After 1st productive session → suggest user run:
- `npx gitnexus analyze` to index for impact analysis
- `mempalace mine <repo> --wing <project-name>` to capture session for future recall
- Create project `CLAUDE.md` (use `/init` for starter)

Until then: be more conservative — verify more, claim less, ask user when uncertain.

## Learn fast — checklist

Goal: enough context to work safely in 5-10 minutes.

### Must know

- [ ] **Tech stack** — language + runtime version
- [ ] **Package manager** — npm/yarn/pnpm/pip/poetry/uv/cargo/go mod
- [ ] **Framework** — read main config (next.config / fastapi app / etc.)
- [ ] **Repo map** — `tree -L 2` or `ls` top-level
- [ ] **Build commands** — from `package.json` / `Makefile` / `pyproject.toml`
- [ ] **Test command** — same source
- [ ] **Lint / typecheck commands**
- [ ] **Dev server command**
- [ ] **Required env vars** — `.env.example` / README

### Should know (read when relevant)

- [ ] Deploy / CI commands — `.github/workflows/` / `vercel.json` / `railway.toml`
- [ ] Generated files + ownership boundaries (don't edit generated)
- [ ] DB migration tool + commands
- [ ] Project `CLAUDE.md` if exists
- [ ] `.claude/rules/` and `.claude/skills/` if exist
- [ ] GitNexus indexed? — check `gitnexus://repo/<name>/context`

### Nice to know (just-in-time)

- Architecture decisions — `docs/` / `decisions/` / ADRs
- External services in use — `.env.example` clues
- Auth model — find login route + middleware

## Order of operations

1. Read project `CLAUDE.md` if exists (most important)
2. Read top-level `package.json` / `pyproject.toml` / equivalent
3. `ls` repo root → understand layout
4. Check for `.claude/` dir → rules + skills
5. Read README briefly (sections: setup, run, test)
6. Check git log for recent activity context

## Sanity check before editing

- Is GitNexus indexed for this project? If yes → use impact analysis
- Are there project-specific style rules (`.editorconfig`, `pyproject.toml`, etc.)?
- Is there existing test for the file you're about to edit?
- What's the build/test command for THIS project specifically?

## Common pitfalls — new project

- Use wrong package manager (`npm install` in pnpm project breaks lockfile)
- Run wrong test command (`pytest` instead of project's `make test`)
- Edit generated files (Prisma schema-output, OpenAPI clients, build artifacts)
- Miss project-specific style enforced by hook/CI
- Skip project `CLAUDE.md` and re-invent existing patterns

## `/init` command — generate starter CLAUDE.md

Anthropic provides `/init` slash command. Run in project root → analyzes codebase → generates starter CLAUDE.md based on detected build systems, test frameworks, code patterns.

Use when:
- Project has no `CLAUDE.md` yet
- Want quick foundation to refine

After `/init`:
- Read generated file
- Prune anything Claude can already infer from code
- Add project-specific gotchas / non-obvious behaviors
- Commit to git so team shares it

## Project CLAUDE.md template

If project lacks one and user asks to create:

```md
# Project Name

## What
Purpose / users / tech stack / repo map / key deps / env vars

## Why
Architecture decisions / code style / naming / anti-patterns / error handling / security constraints

## How
install / dev / build / test / lint / typecheck / format / db-migrations / CI / PR conventions

## Verification
minimum check before finishing / broader check before commit / UI checks / known flaky tests

## Gotchas
non-obvious behaviors / generated files / external services / local quirks
```
