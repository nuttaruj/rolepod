# Rolepod Agent Catalog

Full 15-agent specialist roster. Lead never picks from this list directly — the `write-plan` skill maps path + concern + risk to the right agent when delegation helps.

This doc is the **reference**. No entry doc embeds the roster; each agent file's `description:` is what the CLI shows.

## Routing principle

```
User intent
  → using-rolepod router picks the phase (Define / Plan / Build / Verify / Review / Ship)
  → write-plan picks the specialist agent by path + concern + risk
  → agent's own per-CLI frontmatter picks the model tier (cheap / balanced / strong)
```

Lead is never the picker of last resort. Each step narrows the choice.

## Source of truth

Source of truth: [`core/agents/*.md`](../core/agents/) — the domain map below picks the agent by path + concern; a role's own per-CLI frontmatter overlay picks the model tier.

## Domain map (which path → which agent)

| Path / concern | Agent |
|---|---|
| `**/backend/**`, API routes, business logic | `backend-developer` |
| `**/frontend/**`, components, hooks, state | `frontend-developer` |
| `**/mobile/**`, native iOS / Android | `mobile-developer` |
| `**/billing/**`, `**/payments/**`, `**/credits/**` | `billing-engineer` |
| `**/auth/**`, `**/security/**`, tokens, secrets | `security-engineer` |
| Performance budgets, p95/p99, perf-sensitive code | `performance-engineer` |
| User-visible tests (E2E / UI / browser / contract); a slice's unit tests belong to its writer | `qa-tester` |
| AI / LLM features, RAG, prompt engineering | `ai-ml-engineer` |
| Analytics, dashboards, data pipelines | `data-scientist` |
| API design, module boundaries, data flow | `system-architect` |
| Feature scope, priorities, pricing, ROI | the user — the product owner; `write-spec` Discovery gathers it, no agent stands in |
| Wide read-only sweep — repo or online — before a plan or answer | `scout` |
| Visual design, design system, a11y | `ui-ux-designer` |
| `.github/workflows/**`, `Dockerfile` / `docker-compose*`, `vercel.json` / `wrangler.*` / `fly.toml` / `railway.*`, `deploy/**`, `infra/**`, `terraform/**`, release scripts, monitoring | `devops-sre` |
| Any human-readable written output — docs / FAQ / marketing copy (caller specifies `audience: dev \| user \| prospect`) | `content-strategist` |
| Final code-quality review (logic / DRY / structure) | `universal-reviewer` |

## How to add a new agent

1. Add `core/agents/<name>.md` with `name:` + `description:` + `color:` frontmatter — the single source for every CLI; no overlay repeats `name:` or `description:`.
2. Add `adapters/claude/agent-frontmatter/<name>.yml` with `tier:` (cheap / balanced / strong) + `effort:` + `memory: project` (every role but `scout`, which carries no `memory:` — `memory:` auto-grants Write / Edit on Claude, and `scout` must stay read-only) + `tools:` including `Skill` (every role but `scout`). An explicit `tools:` list drops every MCP tool by default; `qa-tester` and `ui-ux-designer` allowlist the browser MCP servers only (`mcp__claude-in-chrome`, `mcp__playwright`, `mcp__chrome-devtools`, `mcp__plugin_rolepod-uiproof_rolepod-uiproof`) — never all MCP, which would also hand them Gmail / deploy / payment / WordPress-write servers. A pattern matches the server's registered name: a browser server installed under another name (a marketplace plugin registers `mcp__plugin_<plugin>_<server>`) needs its own pattern added here; until then the role reports "not observed" and the Lead observes. No `skills:` preload — a Claude role calls `Skill` on demand instead. The concrete model comes from `TIER_MODELS` in `build/merge-agent.py` — do NOT put a model name in the overlay, and no `maxTurns`: the brief carries the turn budget, the role file none (v2.119.0 — a cap measured as 12 of 105 reviewer runs paid for the read and dropped the report).
3. Add `adapters/codex/agent-frontmatter/<name>.yml` (`tier:` + `model_reasoning_effort` + `sandbox_mode`) and `adapters/antigravity/agent-frontmatter/<name>.yml` (`tier:`). Add the agent's row to the "Default agent → tier mapping" table in `model-tier-policy.md` so the static gate can verify it.
4. Update the domain map above + `write-plan` agent-routing guidance.
5. `bash build/render.sh` — regenerates the per-CLI agent files (Codex `.toml` generated from the core body, no hand-maintained copy).

## Why not fewer agents?

`product-manager` was retired in v2.115.0: over 90 days it was dispatched 0 times because the user IS the product owner — `write-spec` Discovery gathers scope, priorities and commercial framing from them directly, so an agent standing in between was a role with no work.

The 15-specialist count comes from cost-aware role separation, not workflow stages. A senior backend developer model is cheap; a strongest model doing security review is expensive. Mixing them inside one agent collapses the cost-control dimension and forces the workflow to pay strongest-model rates for every task. Keeping them separate lets each agent carry its own tier-mapped model.

One within-tier consolidation exists in the roster. `content-strategist` folds tech-writer + customer-success + growth-marketer (all cheap-tier writers) into a single agent that takes a mandatory `audience: dev | user | prospect` parameter. (A second consolidation, `product-manager` absorbing the former business-analyst, was retired whole in v2.115.0 — see above.) Each audience keeps its own scope, hard stops, and framework set, so specialist depth is preserved while selection overhead at the Lead shrinks.

The one addition outside the specialist pattern is `scout` — a read-only, cheapest-tier researcher backing the always-on "Scout for wide sweeps" rule. It exists so every CLI has a dispatchable, tool-restricted scout with the research-report contract built in, instead of the Lead improvising a brief each time.

Model tiering per agent: Claude pins the model, Codex pins `reasoning_effort`, Antigravity writes an advisory `model:` that agy does not enforce — see [model-tier-policy.md](model-tier-policy.md). Cursor agent files ship with `name` + `description` frontmatter, plus a derived `readonly: true` on the two roles whose Claude overlay holds none of Edit / Write / Bash (`scout`, `universal-reviewer`) — Cursor users pick the model in-IDE, so per-agent tiering is not enforced there.
