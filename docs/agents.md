# Rolepod Agent Catalog

Full 15-agent specialist roster. Lead never picks from this list directly — the Lead picks the owner from the agent listing when delegation helps.

This doc is the **reference**. No entry doc embeds the roster; each agent file's `description:` is what the CLI shows.

## Routing principle

```
User intent
  → using-rolepod router picks the phase (Define / Plan / Build / Verify / Review / Ship)
  → the Lead picks the specialist agent from the agent listing
  → agent's own per-CLI frontmatter picks the model tier (cheap / balanced / strong)
```

Lead is never the picker of last resort. Each step narrows the choice.

## Source of truth

Source of truth: [`core/agents/*.md`](../core/agents/) — each role's own per-CLI frontmatter overlay picks the model tier; `Skill` and `skills:` are generated from the role's Skill Mapping by `build/merge-agent.py`.

## How to add a new agent

1. Add `core/agents/<name>.md` with `name:` + `description:` + `color:` frontmatter plus five sections (Role & Identity, Objective & Focus, Skill Mapping, Persona & Tone, Constraints & Guardrails) — the single source for every CLI; no overlay repeats `name:` or `description:`.
2. Skill Mapping (in the role file) lists the skills that will be available to the agent. `build/merge-agent.py` generates `Skill` tool access and `skills:` from this mapping; the overlay holds neither.
3. Add `adapters/claude/agent-frontmatter/<name>.yml` with `tier:` (cheap / balanced / strong) + `effort:` + no `memory:` on any role (a sub-agent starts from a fresh context; the Lead keeps project memory). The concrete model comes from `TIER_MODELS` — do NOT put a model name in the overlay.
4. Add `adapters/codex/agent-frontmatter/<name>.yml` (`tier:` + `model_reasoning_effort` + `sandbox_mode`) and `adapters/antigravity/agent-frontmatter/<name>.yml` (`tier:`). Add the agent's row to the "Default agent → tier mapping" table in `model-tier-policy.md` so the static gate can verify it.
5. `bash build/render.sh` — regenerates the per-CLI agent files (Codex `.toml` generated from the core body, no hand-maintained copy).

## Why not fewer agents?

`product-manager` was retired in v2.115.0: over 90 days it was dispatched 0 times because the user IS the product owner — `write-spec` Discovery gathers scope, priorities and commercial framing from them directly, so an agent standing in between was a role with no work.

The 15-specialist count comes from cost-aware role separation, not workflow stages. A senior backend developer model is cheap; a strongest model doing security review is expensive. Mixing them inside one agent collapses the cost-control dimension and forces the workflow to pay strongest-model rates for every task. Keeping them separate lets each agent carry its own tier-mapped model.

One within-tier consolidation exists in the roster. `content-strategist` folds tech-writer + customer-success + growth-marketer (all cheap-tier writers) into a single agent that takes a mandatory `audience: dev | user | prospect` parameter. (A second consolidation, `product-manager` absorbing the former business-analyst, was retired whole in v2.115.0 — see above.) Each audience keeps its own scope, hard stops, and framework set, so specialist depth is preserved while selection overhead at the Lead shrinks.

The one addition outside the specialist pattern is `scout` — a read-only, cheapest-tier researcher backing the always-on "Scout for wide sweeps" rule. It exists so every CLI has a dispatchable, tool-restricted scout with the research-report contract built in, instead of the Lead improvising a brief each time.

Model tiering per agent: Claude pins the model, Codex pins `reasoning_effort`, Antigravity writes an advisory `model:` that agy does not enforce — see [model-tier-policy.md](model-tier-policy.md). Cursor agent files ship with `name` + `description` frontmatter, plus a derived `readonly: true` on the two roles whose Claude overlay holds no Edit / Bash and no Write beyond a report-only grant (`scout`, `universal-reviewer`, whose lone `Write` is its report) — Cursor users pick the model in-IDE, so per-agent tiering is not enforced there.
