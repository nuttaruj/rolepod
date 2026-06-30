# Rolepod

**Rolepod turns Claude Code, Codex CLI, Gemini CLI, and Cursor IDE into a disciplined software-house team — a workflow router, 16 specialist agents, and gates that catch bugs before they reach a commit.**

It is one source of truth rendered into a native plugin for each CLI. No CLI is the "default" — all four are first-class. Rolepod carries zero project-specific configuration, so it works in any repository from the first session.

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

## Works with Claude Code Ultracode

Rolepod composes with Claude Code's **Ultracode** mode out of the box — no setup. Ultracode is the harness orchestration layer (parallel multi-agent workflows, adversarial verification); Rolepod is the structure it runs — phases, specialist agents, cohesion contracts, and gates. Ultracode supplies the horsepower; Rolepod keeps it targeted and safe. The two principles are orthogonal, not opposed: Rolepod's *simplest-viable* governs the solution, Ultracode's *exhaustiveness* governs the process — so an exhaustive run still converges on a simple result. For a deliberate max-rigor pass, invoke **`/rolepod-full`**.

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
# Install — the plugin carries skills + hooks; the 16 agents need the installer
codex plugin marketplace add nuttaruj/rolepod
codex plugin add rolepod@rolepod
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

### Cursor IDE

**Install via `bootstrap.sh`** — copies the plugin tree to `~/.cursor/plugins/local/rolepod/`:

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --target=cursor

# Update — re-run with --force
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --target=cursor --force

# Uninstall
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --uninstall --target=cursor
```

Restart Cursor (or reload the window) so the plugin registers. Verify under **Cursor → Settings → Plugins**.

The always-on judgment core ships as an `alwaysApply: true` rule (`rules/always-on-core.mdc`) — loaded automatically on every Cursor session. Disabling **Settings → Features → Rules** suppresses it.

> **Teams / Enterprise plans** can alternatively add `https://github.com/nuttaruj/rolepod` as a team marketplace under Settings → Plugins for one-click install. Team Marketplaces are not available on Free / Pro plans.

**Install all four at once** with `--target=all`. **One repo only, no global config:** add `--scope=project`. Restart the CLI after installing. Full per-CLI matrix and install scopes: [docs/cli-support.md](docs/cli-support.md).

## What's inside

- **16 specialist agents** — strategy, architecture, engineering, quality, ops, design, content, and review. Each owns a path or concern and runs on a cost-tiered model (~50-60% cheaper than all-strong). → [docs/agents.md](docs/agents.md), [docs/model-tier-policy.md](docs/model-tier-policy.md)
- **Core 10 skills** — one router plus nine phase skills, the workflow spine. → [docs/skills.md](docs/skills.md)
- **Per-CLI hooks** — deterministic enforcement: gate reminders, a pre-commit test gate, a sub-agent commit block, a concurrent-edit stomp guard, session safety. Counts vary by CLI capability (Claude 8 / Codex 3 / Gemini 4 / Cursor 3). → [docs/hooks.md](docs/hooks.md)
- **Active gates** — Q1-Q4 delegation, S1-S5 simplicity, T1-T6 tests, F1-F5 failure-mode — checked before every commit.

The source lives in `core/`; per-CLI adapters render it into a native plugin for each CLI.

## Plugin family — standalone × combined

Rolepod is the **parent** of a plugin family. Each sibling works standalone; together they unlock end-to-end flows across domains. Children plug into the parent via **Extension Protocol v1** — they detect `<git-root>/.rolepod/parent-active` and switch from standalone mode to with-rolepod mode, routing evidence into `.rolepod/evidence/` for `check-work` to aggregate.

See [docs/EXTENSION-PROTOCOL.md](docs/EXTENSION-PROTOCOL.md) for the full contract.

| Install | Standalone value | What it adds when combined |
|---|---|---|
| **rolepod** (this repo) | Workflow + 16 agents + judgment for any project | Routes by phase, aggregates evidence, suggests siblings by domain signal |
| [**rolepod-uiproof**](https://github.com/nuttaruj/rolepod-uiproof) (v0.6+) | 5 browser skills — `/verify-ui`, `/audit-a11y`, `/visual-diff`, `/scaffold-e2e`, `/check-errors` + 26 MCP tools | Verify-phase provider for UI artifacts; evidence auto-routes to `check-work` |
| [**rolepod-wplab**](https://github.com/nuttaruj/rolepod-wplab) (v1.9+) | 14 WordPress skills + 82 MCP tools — wp-cli + REST + scoped fs | Build/Verify/Review primitives for WP; phase-flavored skills narrow under parent |
| [**rolepod-dblab**](https://github.com/nuttaruj/rolepod-dblab) (v0.1+) | 5 Postgres skills — `/db-introspect`, `/db-query`, `/db-explain`, `/db-migrate-verify`, `/db-write` + 5 MCP tools | Data-layer provider; `check-work` gains DB evidence, `finish-work` gates on schema drift |

### Synergy matrix

| Combo | Flows unlocked |
|---|---|
| rolepod + uiproof | Verify reads browser evidence automatically; UI regressions blocked at pre-commit |
| rolepod + wplab | `implement-plan` knows `/wp-edit-*`; `debug-issue` routes to `/wp-diagnose`; `check-work` reads `/wp-health-check` |
| rolepod + dblab | `check-work` reads DB state as PASS/FAIL evidence; `review-code` / `finish-work` call `/db-migrate-verify` on migration/auth/billing paths; `debug-issue` inspects live data state. Seam rule: WordPress DB → wplab, any other DB → dblab |
| uiproof + wplab (no parent) | Browser test on WP site, a11y on themes, visual-diff on migrations — each runs standalone |
| **rolepod + uiproof + wplab** | Full WP dev flow with verified evidence at every phase — spec → plan → wp-edit-theme → wp-health-check + verify-ui + audit-a11y + visual-diff → review → ship |

### Other recommended add-ons

| Add-on | What it adds | Fallback without it |
|--------|--------------|---------------------|
| [CodeGraph](https://www.npmjs.com/package/codegraph) · [GitNexus](https://github.com/abhigyanpatwari/GitNexus) | Sub-millisecond symbol / caller / impact queries | `rg` + `find` text search |
| [claude-mem](https://github.com/thedotmack/claude-mem) | Automatic cross-session memory — captures observations, injects project-scoped context, zero manual upkeep | Built-in per-project memory |
| [rtk](https://github.com/rtk-ai/rtk) · [caveman](https://github.com/JuliusBrussee/caveman) | Token cuts on routine commands and replies | Normal output |
| [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | Design recipes for the `ui-ux-designer` agent | Bundled design skills |

**Tip:** add `.rolepod/` to your repo's `.gitignore`. The parent writes session markers and child plugins write evidence under that path — both are ephemeral and shouldn't be committed.

## Docs

- [CHEATSHEET.md](CHEATSHEET.md) — one-page quick reference
- [docs/cli-support.md](docs/cli-support.md) — per-CLI capabilities, install scopes, runtime status
- [docs/skills.md](docs/skills.md) · [docs/agents.md](docs/agents.md) · [docs/hooks.md](docs/hooks.md) — workflow reference
- [docs/model-tier-policy.md](docs/model-tier-policy.md) — per-agent model assignments

---

MIT licensed — see [LICENSE](LICENSE). Personal workflow system — fork freely; runtime reports for Codex and Gemini are especially welcome via [issues](https://github.com/nuttaruj/rolepod/issues).
