# Rolepod Agent Catalog

The roster is four agent types. The Lead picks the type from the agent listing when delegation helps; the brief carries the domain (builder) or the lens (reviewer), and the call carries the model.

This doc is the **reference**. No entry doc embeds the roster; each agent file's `description:` is what the CLI shows.

## The four types

| Type | Does | Tools (Claude) | Preload | Tier / effort | Write scope (Claude) |
|---|---|---|---|---|---|
| `rolepod-builder` | Every build, in any domain; the brief's `domain:` tag adds `architecture` (design only, strong per call) or `writing` (the absolute path of `implement-plan/references/writing.md`; cheap per call for copy-only work) | Read Glob Grep Edit Bash Write Agent SendMessage WebFetch WebSearch | `implement-plan` | balanced / medium | owner (open) |
| `rolepod-reviewer` | One review lens per dispatch: `spec`, `standards`, `security`, `adversarial`, `perf`, `ui`, `arch`; report `<task>-<lens>.md` | Read Glob Grep Write Edit Bash WebFetch WebSearch | `review-code` | balanced / medium | test paths + `.md` |
| `rolepod-qa` | Ship-time QA pass over user-visible flows; test files only | the qa tool set + the four browser MCP servers | `implement-plan` | balanced / medium | test paths + `.md` |
| `rolepod-scout` | Read-only wide sweep, online research; pointers only | Read Glob Grep WebFetch WebSearch | none | cheap / medium, `omitClaudeMd` | `.md` only |

Strength follows the work, not the type: the Lead passes a strong model per call for the `security` and `adversarial` lenses and for `domain: architecture`. No hook enforces it; `strong-fanout` denies a fan-out that passes a strong model.

On Cursor and opencode there is no write-scope hook, so `rolepod-reviewer` and `rolepod-qa` render writable; their bodies state the scope.

## Routing principle

```
User intent
  → using-rolepod router picks the phase (Define / Plan / Build / Review / Ship)
  → the Lead picks the type from the agent listing (+ domain tag or lens in the brief)
  → the type's own per-CLI frontmatter picks the model tier (cheap / balanced)
```

## Source of truth

Source of truth: [`core/agents/*.md`](../core/agents/) — each type's own per-CLI frontmatter overlay picks the model tier; `Skill` and `skills:` are generated from the type's Skill Mapping by `build/merge-agent.py`.

## Old role names

A plan that names a role from the 15-role roster maps by one sentence in `orchestrating-plans` step 2; no hook aliases the old names. `stats.sh` folds the old names into the four rows of history.

## How to add a new agent

1. Add `core/agents/<name>.md` (name starts with `rolepod-`: Codex, Cursor and opencode have no namespace) with `name:` + `description:` + `color:` frontmatter plus the sections Role & Identity, Skill Mapping, Persona & Tone, Constraints & Guardrails — the single source for every CLI; no overlay repeats `name:` or `description:`.
2. Skill Mapping (in the file) lists the skills available to the agent. `build/merge-agent.py` generates `Skill` tool access and `skills:` from this mapping; the overlay holds neither.
3. Add `adapters/claude/agent-frontmatter/<name>.yml` with `tier:` (cheap / balanced / strong) + `effort:` + no `memory:` (a sub-agent starts from a fresh context; the Lead keeps project memory). The concrete model comes from `TIER_MODELS` — do NOT put a model name in the overlay.
4. Add `adapters/codex/agent-frontmatter/<name>.yml` (`tier:` + `model_reasoning_effort` + `sandbox_mode`) and `adapters/antigravity/agent-frontmatter/<name>.yml` (`tier:`). Add the agent's row to the "Default agent → tier mapping" table in `model-tier-policy.md` so the static gate can verify it.
5. `bash build/render.sh` — regenerates the per-CLI agent files (Codex `.toml` generated from the core body, no hand-maintained copy).

## Why four

The roster was fifteen role files. A round-2 measurement showed the difference between roles is the tool profile, not the name: four profiles remain (open builder, reviewer with a review preload, qa with browser servers, read-only scout). The reviewer is its own type because it preloads `review-code` instead of `implement-plan` (no skill listing in its context) and is test-only on Claude. Domain knowledge a model already has was cut from the bodies; the rules that are not general knowledge live in the skill of the step that uses them.

Model tiering per agent: Claude pins the model, Codex pins `reasoning_effort`, Antigravity writes an advisory `model:` that agy does not enforce — see [model-tier-policy.md](model-tier-policy.md). Cursor agent files ship with `name` + `description` frontmatter, plus a derived `readonly: true` on the one type whose Claude overlay holds no Edit / Write / Bash (`rolepod-scout`) — Cursor users pick the model in-IDE, so per-agent tiering is not enforced there.
