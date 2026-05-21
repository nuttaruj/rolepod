# PLAN — Codex marketplace publishable repo

Spec: `docs/specs/codex-marketplace-publishable.md` (APPROVED · Approach A).
Shape: one PR, sequential, Lead-executed (rolepod editing its own build).
Mirrors PR #26 (the Claude equivalent) — proven template.

## Layout (target)

```
.agents/plugins/marketplace.json   committed — Codex marketplace catalog (repo root)
plugins/rolepod-codex/             committed — rendered Codex plugin tree
  .codex-plugin/plugin.json
  skills/<name>/SKILL.md
  hooks/hooks.json + *.sh
adapters/codex/
  .agents/plugins/marketplace.json source — source.path → ./plugins/rolepod-codex
  plugins/rolepod/                 source — .codex-plugin/, agents/*.toml, hooks/
  AGENTS.md.tmpl
build/rendered/codex/              gitignored — AGENTS.md + agent .toml staging (install.sh only)
```

Claude's `plugins/rolepod/` + `.claude-plugin/` are untouched. Codex agents
(`*.toml`) stay out of the plugin (Codex has no plugin agents component) —
install.sh keeps copying them to `~/.codex/agents/`.

## Files to touch

- `build/render.sh` — `render_codex`
- `adapters/codex/.agents/plugins/marketplace.json` — source `source.path`
- `plugins/rolepod-codex/**` — NEW committed rendered tree
- `.agents/plugins/marketplace.json` — NEW committed (rendered, repo root)
- `install.sh` — Codex install path
- `Makefile` — `test-render-clean`
- `tests/static/lean-surface.sh`, `tests/integration/cases/install-parity.sh`
- `.github/workflows/installer.yml`
- `README.md`, `docs/cli-support.md`

## Tasks (ordered)

### 1. marketplace.json source path
`adapters/codex/.agents/plugins/marketplace.json`: `source.path`
`./plugins/rolepod` → `./plugins/rolepod-codex`.
Test: `python3 -m json.tool` parses clean; `source.source` stays `local`.

### 2. render_codex → committed paths
`render_codex` writes the repo-root `.agents/plugins/marketplace.json` and
the `plugins/rolepod-codex/` tree (`.codex-plugin/`, `skills/` derefed from
`core/skills/`, `hooks/`). `rm -rf` only `plugins/rolepod-codex/`, never the
repo root. AGENTS.md + agent-`.toml` staging stay in `build/rendered/codex/`
(gitignored — read by install.sh).
Test: `bash build/render.sh --target=codex` → root `.agents/plugins/
marketplace.json` + `plugins/rolepod-codex/{.codex-plugin/plugin.json,
skills,hooks}` exist; `grep -r '{{INCLUDE' plugins/rolepod-codex/` empty.

### 3. Commit the rendered Codex tree
`git add .agents/ plugins/rolepod-codex/` and commit so the marketplace is
consumable from GitHub.
Test: `git status` clean after; `plugins/rolepod-codex/` tracked; no
`.DS_Store` / junk staged.

### 4. install.sh — Codex marketplace source = repo root
Codex path: `RENDERED_CODEX_DIR` for the marketplace-add becomes `$REPO_DIR`
(the repo is the marketplace), mirroring `RENDERED_CLAUDE_DIR="$REPO_DIR"`.
Fix the post-render sanity / verify paths (`plugins/rolepod` →
`plugins/rolepod-codex`; marketplace.json at `$REPO_DIR/.agents/plugins/`).
The agent-`.toml` copy reads from `adapters/codex/plugins/rolepod/agents/`
(committed source) or the `build/rendered/codex/agents/` staging — keep
whichever is already wired, just correct the path. AGENTS.md managed-block
step unchanged.
Test: `ROLEPOD_TARGET=$(mktemp -d) bash install.sh --target=codex --dry-run`
→ shows `codex plugin marketplace add <repo-root>`, no missing-path fail.

### 5. test-render-clean drift guard
`Makefile`: after render, `git diff --quiet -- .agents/ plugins/rolepod-codex/`
→ fail on drift (mirror the `plugins/rolepod/` guard from #26). Assert the
committed Codex marketplace files exist.
Test: `make test-static` green; edit a `core/skills/*` file without
re-rendering → guard fails.

### 6. tests + CI codex refs
`tests/static/lean-surface.sh` + `tests/integration/cases/install-parity.sh`
+ `.github/workflows/installer.yml` — any assertion tied to
`build/rendered/codex/` as the marketplace source updated to the repo-root
paths. Codex agents-to-`~/.codex/agents/` assertions unchanged.
Test: `make test-static` green; `bash tests/integration/run.sh` 8/8.

### 7. docs
`README.md` + `docs/cli-support.md`: document
`codex marketplace add nuttaruj/rolepod` as the Codex install (mirroring the
Claude marketplace-add lines); note the agents still need `install.sh`.
Test: `tests/static/lean-surface.sh` STALE-keyword grep green.

## Test plan (whole)

- `make test-static` green incl. the new Codex drift guard
- `bash tests/integration/run.sh` 8/8
- `install.sh --target=codex --dry-run` registers the repo root, no fail
- `.agents/plugins/marketplace.json` + `plugins/rolepod-codex/.codex-plugin/
  plugin.json` parse clean; `source.path` = `./plugins/rolepod-codex`
- post-merge live test: `codex plugin marketplace add nuttaruj/rolepod`

## High-risk surfaces

- `install.sh` Codex path — broken Codex install hits every Codex user.
  Mitigation: `--dry-run` before any real install; #26 is the proven template.

## Done criteria

`codex marketplace add nuttaruj/rolepod` resolves the rolepod plugin straight
from GitHub; the committed `.agents/` + `plugins/rolepod-codex/` tree matches
a fresh render (CI-guarded); Claude + Gemini untouched; static + integration
green; docs updated.

## Risks

- Codex `source: "local"` relative-path resolution — Approach A stays on
  `./plugins/<name>`, the form `openai/plugins` uses, so low risk.
- Render now writes two committed trees (`plugins/rolepod/` Claude +
  `plugins/rolepod-codex/` Codex) — the drift guard must cover both.
