---
name: new-project-onboarding
description: Onboard fast to an unfamiliar codebase — detect stack, find conventions, identify entry points.
when_to_use: '"first time in repo", "/init", "unfamiliar project", "bootstrap mode", "new project", "learn this codebase"'
context: fork
agent: Explore
---

# New Project — fast onboarding

Read when: first time in unfamiliar project / bootstrap session.

## Bootstrap mode — first session ever

No MemPalace data, no GitNexus index, no project CLAUDE.md → degraded but functional:

| Feature | Fallback |
|---------|----------|
| MemPalace recall | git log + git blame + READMEs |
| GitNexus impact | `rg` + manual Read |
| Project conventions | Read 2-3 nearby files |
| Past decisions | None — ask user when ambiguous |
| Auto-context loader | git log only |

After 1st productive session → suggest user:
- `npx gitnexus analyze` to index
- `mempalace mine <repo> --wing <project-name>` to capture session
- Create project `CLAUDE.md` (`/init` for starter)

Until then: conservative — verify more, claim less, ask user.

## Learn fast checklist

5-10 min context floor.

### Must know

- [ ] Tech stack — language + runtime version
- [ ] Package manager — npm/yarn/pnpm/pip/poetry/uv/cargo/go mod
- [ ] Framework — read main config
- [ ] Repo map — `tree -L 2` or `ls`
- [ ] Build / test / lint / typecheck / dev server commands (from `package.json` / `Makefile` / `pyproject.toml`)
- [ ] Required env vars — `.env.example` / README

### Should know (relevant)

- [ ] Deploy / CI — `.github/workflows/` / `vercel.json` / `railway.toml`
- [ ] Generated files + ownership boundaries
- [ ] DB migration tool + commands
- [ ] Project `CLAUDE.md`
- [ ] `.claude/rules/` and `.claude/skills/`
- [ ] GitNexus indexed? — `gitnexus://repo/<name>/context`

### Nice to know (JIT)

- Architecture decisions — `docs/` / `decisions/` / ADRs
- External services — `.env.example` clues
- Auth model — login route + middleware

## Order of operations

1. Project `CLAUDE.md` if exists (most important)
2. `package.json` / `pyproject.toml` / equivalent
3. `ls` repo root
4. `.claude/` dir — rules + skills
5. README briefly (setup / run / test sections)
6. git log recent activity

## Sanity check before editing

- GitNexus indexed?
- Project-specific style rules (`.editorconfig`, `pyproject.toml`)?
- Existing test for file?
- Build/test command for THIS project?

## Common pitfalls

- Wrong package manager (`npm install` in pnpm project breaks lockfile)
- Wrong test command (`pytest` instead of project's `make test`)
- Edit generated files (Prisma schema-output, OpenAPI clients, build artifacts)
- Miss project-specific style enforced by hook/CI
- Skip project `CLAUDE.md`, re-invent existing patterns

## `/init` command

Anthropic slash command. Run in project root → analyzes codebase → generates starter CLAUDE.md based on build systems, test frameworks, patterns.

Use when: no `CLAUDE.md` / want quick foundation.

After `/init`:
- Read generated
- Prune anything Claude can infer from code
- Add project-specific gotchas
- Commit to git

## Project CLAUDE.md template

```md
# Project Name

## What
Purpose / users / tech stack / repo map / key deps / env vars

## Why
Architecture decisions / code style / naming / anti-patterns / error handling / security

## How
install / dev / build / test / lint / typecheck / format / migrations / CI / PR conventions

## Verification
minimum check / broader check / UI checks / known flaky tests

## Gotchas
non-obvious behaviors / generated files / external services / local quirks
```
