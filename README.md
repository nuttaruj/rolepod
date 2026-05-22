# Rolepod

**Rolepod turns Claude Code, Codex CLI, and Gemini CLI into a disciplined software-house team — a workflow router, 18 specialist agents, and gates that catch bugs before they reach a commit.**

It is one source of truth rendered into a native plugin for each CLI. No CLI is the "default" — all three are first-class. Rolepod carries zero project-specific configuration, so it works in any repository from the first session.

## What it helps with

- **Vague ideas → sharp specs.** A half-stated feature request becomes an agreed spec before any code is written.
- **Multi-file work → a real plan.** Tasks, agent ownership, and a cohesion contract so parallel work doesn't collide.
- **Test-first builds.** RED → GREEN discipline instead of tests bolted on afterward.
- **Bugs caught at commit time.** Scope creep, single-use abstractions, weak assertions, and missing tests are flagged before they land — not in review.
- **The right specialist on the job.** Frontend, security, performance, billing, docs — domain work routes to a specialist agent instead of one generalist guessing.

## How it works

Rolepod starts the moment you give your CLI a task — you don't run a command or pick a mode. A router skill reads the request and places it in the workflow: a one-line typo fix goes straight to the edit; a vague "build me X" gets pulled back into a spec conversation first.

Every real change then moves through six phases:

```
Define → Plan → Build → Verify → Review → Ship
```

Each phase has one skill that runs it, and each skill pulls in specialist agents when the work needs depth. Before any commit, gates fire automatically — simplicity, tests, failure-mode — as soft reminders on ordinary code and hard blocks on high-risk paths like auth, billing, and migrations.

You invoke nothing for this; it just happens. For a deliberate run through every phase with no skips, invoke **`/rolepod-full`**.

## The workflow

1. **Define — `write-spec`.** Turns a fuzzy request into a spec, shown back in chunks short enough to actually read and approve.
2. **Plan — `write-plan`.** Breaks the spec into tasks, assigns agent ownership, writes a cohesion contract before any parallel work.
3. **Build — `implement-plan`.** Executes the plan test-first with bounded delegation. Bug fixes take the `debug-issue` path: reproduce → failing test → minimal fix.
4. **Verify — `check-work`.** Proves the change with evidence — tests, build, curl, a screenshot — never just a "done".
5. **Review — `review-code`.** Multi-axis review, with adversarial pressure on high-risk diffs.
6. **Ship — `finish-work`.** Pre-merge gate, CI lanes, and a 4-option finish menu.

Two skills run across phases: **`simplify-code`** (behavior-preserving cleanup) and **`manage-context`** (recovery when a session is long, stuck, or in an unfamiliar repo).

## Install

Pick your CLI. Rolepod installs **only itself** — agents, skills, hooks, manifests. No third-party tools are installed for you.

### Claude Code

```bash
# Install
claude plugin marketplace add nuttaruj/rolepod
claude plugin install rolepod@rolepod

# Update
claude plugin marketplace update rolepod
claude plugin update rolepod@rolepod

# Uninstall
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --uninstall --target=claude
```

### Codex CLI

```bash
# Install — the plugin carries skills + hooks; the 18 agents need the installer
codex plugin marketplace add nuttaruj/rolepod
codex plugin install rolepod@rolepod
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --target=codex

# Update
codex plugin marketplace upgrade rolepod
codex plugin remove rolepod@rolepod && codex plugin add rolepod@rolepod

# Uninstall
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --uninstall --target=codex
```

Codex hooks are registered but **inert until you opt in** — run `codex features enable plugin_hooks`. Agents, skills, and the `AGENTS.md` gate rules work without it.

### Gemini CLI

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --target=gemini

# Update — re-run with --force
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --target=gemini --force

# Uninstall
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --uninstall --target=gemini
```

**Install all three at once** with `--target=all`. **One repo only, no global config:** add `--scope=project`. Restart the CLI after installing. Full per-CLI matrix and install scopes: [docs/cli-support.md](docs/cli-support.md).

## What's inside

- **18 specialist agents** — strategy, architecture, engineering, quality, ops, design, docs, and review. Each owns a path or concern and runs on a cost-tiered model (~50-60% cheaper than all-strong). → [docs/agents.md](docs/agents.md), [docs/model-tier-policy.md](docs/model-tier-policy.md)
- **Core 10 skills** — one router plus nine phase skills, the workflow spine. → [docs/skills.md](docs/skills.md)
- **7 core hooks** — deterministic enforcement: gate reminders, a pre-commit test gate, a sub-agent commit block, session safety. → [docs/hooks.md](docs/hooks.md)
- **Active gates** — Q1-Q4 delegation, S1-S5 simplicity, T1-T6 tests, F1-F5 failure-mode — checked before every commit.

The source lives in `core/`; per-CLI adapters render it into a native plugin for each CLI.

## Recommended add-ons

Rolepod ships pure framework. These optional tools pair well — install any of them yourself and rolepod auto-integrates; nothing breaks and nothing nags if they are absent.

| Add-on | What it adds | Fallback without it |
|--------|--------------|---------------------|
| [CodeGraph](https://www.npmjs.com/package/codegraph) · [GitNexus](https://github.com/abhigyanpatwari/GitNexus) | Sub-millisecond symbol / caller / impact queries | `rg` + `find` text search |
| [MemPalace](https://github.com/mempalace/mempalace) | Cross-session knowledge graph of past decisions | Built-in per-project memory |
| [rtk](https://github.com/rtk-ai/rtk) · [caveman](https://github.com/JuliusBrussee/caveman) | Token cuts on routine commands and replies | Normal output |
| [Codex CLI](https://www.npmjs.com/package/@openai/codex) · [Gemini CLI](https://www.npmjs.com/package/@google/gemini-cli) | Cross-model adversarial review inside `review-code` | `qa-tester` agent alone |
| [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | Design recipes for the `ui-ux-designer` agent | Bundled design skills |

## Docs

- [CHEATSHEET.md](CHEATSHEET.md) — one-page quick reference
- [docs/cli-support.md](docs/cli-support.md) — per-CLI capabilities, install scopes, runtime status
- [docs/skills.md](docs/skills.md) · [docs/agents.md](docs/agents.md) · [docs/hooks.md](docs/hooks.md) — workflow reference
- [docs/model-tier-policy.md](docs/model-tier-policy.md) — per-agent model assignments

---

MIT licensed — see [LICENSE](LICENSE). Personal workflow system — fork freely; runtime reports for Codex and Gemini are especially welcome via [issues](https://github.com/nuttaruj/rolepod/issues).
