# Plan — opencode adapter (full parity)

Spec + plan combined. Verified against opencode.ai/docs (agents, skills,
plugins, rules — accessed 2026-07-28).

## Goal

`--target=opencode` renders + installs rolepod to the opencode CLI with the
same doctrine surface as the other adapters: 11 skills, 16 agents, always-on
core, best-effort hooks.

## Verified opencode facts (2026-07-28)

- Skills: native SKILL.md at `~/.config/opencode/skills/<name>/SKILL.md`;
  frontmatter requires `name` (must match dir, `^[a-z0-9]+(-[a-z0-9]+)*$`)
  + `description`; also reads Claude-compatible `~/.claude/skills/` paths.
- Agents: `~/.config/opencode/agents/<file>.md`; filename = agent id;
  frontmatter: `description`, `mode: subagent|primary|all`, optional
  `model` / `permission`. Subagents auto-invoked by description or `@` mention.
- Rules: global `~/.config/opencode/AGENTS.md` auto-loaded; project
  `AGENTS.md` / `CLAUDE.md` fallback chain.
- Plugins: JS/TS modules in `~/.config/opencode/plugins/`; hooks object with
  `event` stream (`session.created`, `session.compacted`, ...) and
  `tool.execute.before/after`; throwing in before-hook blocks the call.

## Non-goals (v1)

- Commit-ban enforcement in the plugin (agent-context detection in
  `tool.execute.before` is undocumented — gates stay skill-enforced; noted
  in AGENTS.md.tmpl).
- Marketplace packaging (opencode has none for this style).
- Model pins per agent (tier stays doctrine, opencode is multi-provider).

## Tasks

1. `adapters/opencode/opencode.json` — version metadata (bump-script parity)
   — Command: `python3 -m json.tool adapters/opencode/opencode.json`
2. `adapters/opencode/AGENTS.md.tmpl` — always-on core via {{INCLUDE}}
   fragments (mirror codex tmpl; opencode-specifics section)
   — Command: render then `grep '^## Risky actions' build/rendered/opencode/AGENTS.md`
3. `adapters/opencode/plugin/rolepod.js` — fail-open shim: session lock
   interop (`~/.rolepod/session-locks/` protocol) on `session.created`,
   post-compact re-anchor nudge on `session.compacted`
   — Command: `node --check adapters/opencode/plugin/rolepod.js`
4. `build/merge-agent.py` — `opencode` target: `description` +
   `mode: subagent` frontmatter (filename = id; no overlay dir)
   — Command: `python3 build/merge-agent.py --target=opencode --name=scout`
5. `build/render.sh` — `render_opencode()` → `build/rendered/opencode/`
   (AGENTS.md, agents/, skills/ stripped to name+description, plugin/,
   opencode.json); wire case + usage
   — Command: `bash build/render.sh --target=opencode`
6. `install.sh` — 7 sites: usage, arg case, default path
   (`~/.config/opencode`), `ROLEPOD_OPENCODE_TARGET` override, uninstall
   block, `opencode_selected` + install section (pure FS copy + managed
   AGENTS.md block), summary line
   — Command: `ROLEPOD_OPENCODE_TARGET=$(mktemp -d) ./install.sh --target=opencode --dry-run`
7. `tests/integration/cases/opencode-adapter.sh` — mirror
   antigravity-adapter.sh structure checks
   — Command: `bash tests/integration/cases/opencode-adapter.sh`
8. Docs: cli-fallbacks.md drops opencode as the no-adapter example;
   version bump 2.10.0 (0.10.0 gemini/agy); `make render && make test`
   — Command: `make test`

## Failure policy

A task's Command fails → fix within the task scope; render/test failures
block commit (Iron Rule). No opencode binary on PATH → structural checks
only (test skips live validation cleanly, same as agy).

## Parallel layout

None — single-owner sequential (Lead); each task feeds the next.
