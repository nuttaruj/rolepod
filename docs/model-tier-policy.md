<!-- Model-tier routing policy — referenced by using-rolepod router + agent frontmatter. -->

## Model tiers

Rolepod ships a cost-aware policy that maps **role + risk → model tier**. Each agent's per-CLI overlay carries only a **`tier:`** (a stable, semantic label) — never a model name. `build/merge-agent.py`'s `TIER_MODELS` resolves tier → model at render time for the CLIs that take a pin (Claude aliases, Antigravity's own `gemini-3-*` ids), so a model rename or a new generation is **one edit there**, not 48 across the overlays. Codex takes no model pin at all (below). This table is the human-readable view of that map; the static gate verifies the two never drift.

| Tier | Claude | Codex | Antigravity | Use for |
|---|---|---|---|---|
| **cheap** | `haiku` | — (no pin; effort only) | `gemini-3-flash-preview` | docs, PM (feature + commercial), customer-facing copy, marketing, FAQ, ADR drafting, read-only scout sweeps — repeatable structured output, no deep architectural reasoning |
| **balanced** | `sonnet` | — (no pin; effort only) | `gemini-3-pro-preview` | ALL implementation — high-risk paths included (billing / payments / migrations: the net is the strong Lead at dispatch + the strong adversarial review floor, never the dev's tier), QA test writing — the default working tier |
| **strong** | `opus` | — (no pin; effort only) | `gemini-3-pro-preview` | architecture, security audit, adversarial code review — wrong judgment costs real money or blocks recovery; reviewer must match implementer depth |

**Why the tiers resolve the way they do**

- **cheap / balanced pin LOW on purpose.** A cheap component stays cheap even under an expensive Lead — that is the cost saving. Claude uses aliases (`haiku` / `sonnet`), which auto-resolve to the newest model of that family, so a Claude version bump needs no edit.
- **strong on Claude is `opus`, pinned in frontmatter (v2.104.0).** The pin holds everywhere a hook does not run: hooks off, the first action of a session, a Workflow `agentType:` call, another harness with no hooks.
  `opus` is the **paid ceiling** of the tier by owner decision: a fable-class Lead keeps its own model, but its strong reviewers run opus; apex (below) stays an explicit, triggered override.
  No hook rewrites a dispatch's model (the pre-v2.104 `updatedInput` lift was removed in v2.176.0 as a dead path). An explicit low `model:` on a strong role is a downgrade, and the commit gate does not count it as the strong pass.
  Result: **role → tier is Lead-independent in both directions** — writers pinned balanced under an opus Lead, reviewers at opus under a sonnet Lead.
- **The Workflow path is where cost leaks, and frontmatter cannot pin it.** Workflow `agent()` calls default to the Lead's model. The fleet gate in `workflow-tier-nudge.sh` (Workflow only, v2.176.0) keeps two denies, and neither yields:
  `bare-fanout` — a fan-out `agent()` with no tier under a strong-class or unknown Lead (measured: six fleets in one day ran at opus/fable with a nudge ignored); `bare-writer` — a writing stage with no `agentType:`, under any Lead.
  No script comment excuses them; the fix is to pin every fan-out (a `model:` class or a rolepod `agentType:`). The doctrine side stays **one strong slot**: sweep = cheap, build and per-item verify = balanced, the ONE judge or security reviewer = strong.
- **The high-risk floor is NOT this pin.** A Lead weaker than the strong tier (e.g. a Sonnet Lead touching billing) still gets an independent strong check, because `review-code`'s Iron Rule mandates a **cross-family** adversarial pass (a different vendor's CLI) on high-risk surfaces, and the commit gate requires a strong reviewer dispatch since the last commit. Depth on money/security paths is guaranteed by those, not by pinning a model here.
- **Cross-CLI.** Codex pins no model (next bullet); Antigravity pins an explicit id per tier (`gemini-3-flash-preview` / `gemini-3-pro-preview`, advisory — see below). The commit gate's evidence check is Claude-only (v2.176.0): on every other CLI the commit hook keeps only the private-docs deny. What DOES carry over is the fan-out shape: a Codex native subagent spawned from a plain prompt (no rolepod role) inherits the Lead exactly like a Workflow `agent()` call, and no hook can deny it there (Codex `SubagentStart` is post-spawn). The one-strong-slot rule is therefore doctrine on those CLIs (router skill, rendered everywhere): the judgment slot gets the strongest model the user runs at the highest effort, the per-item fan-out stays at lower effort. Codex resolves an un-pinned child by explicit spawn value → `agents.default_subagent_model` / `agents.default_subagent_reasoning_effort` → the parent (official precedence); a rolepod role file pins no model, so those two config keys decide what every rolepod role, Ultra's proactive delegation and every plain-prompt spawn run on. The Lead CAN tier a child itself: `spawn_agent` accepts `model` / `reasoning_effort` (binary strings, codex 0.147.0: "Spawned agents inherit your current model by default … set `model` only when an explicit override is needed" and "Only set `model` or `reasoning_effort` when explicitly requested by the user, applicable `AGENTS.md` instructions, or skill…"; full-history forks accept no override; the V2 picker list is gated by `expose_spawn_agent_model_overrides`). rolepod's Codex `AGENTS.md` IS that instruction — tier per child, one named strong role as the judgment slot, child count the model's call. The config floor `[agents] default_subagent_model` (the user picks the model) + `default_subagent_reasoning_effort = "high"` catches every spawn that omits `model` (Ultra's proactive delegation included). Effort on a balanced model never clears the strong floor — on Codex that floor is the user's model choice plus the cross-family pass.
- **Rename-safety of the Claude floor.** The hook classifies the Lead by FAMILY word only (`haiku` / `sonnet` / `opus|fable|mythos`), never a version — `claude-sonnet-5 → claude-sonnet-6` changes nothing — and the frontmatter pin writes the `opus` alias, which Claude Code resolves to the newest of that family. Failure modes are asymmetric on purpose: an unknown family (a new tier, a gateway id) is left untouched, i.e. today's behavior, and `dispatch-auto-log.sh` records `lead_class: unknown`; if the `opus` alias were ever retired the Agent call would fail loudly (visible), not silently downgrade.
- **Codex pins no model (owner, 2026-09-25).** rolepod is a workflow harness and never tracks vendor model ids: the `gpt-5.6-*` pins were already stale when the user ran `gpt-6-*`. A rolepod Codex role file carries `model_reasoning_effort` + `sandbox_mode` only; the model is the user's `default_subagent_model`, else the Lead's.
- **Antigravity's pin is advisory.** `TIER_MODELS["antigravity"]` writes agy's own `gemini-3-*` ids into every agy agent's `model:` field, but `agy` **auto-selects** the model per task and ignores it — the pin is recorded for consistency only, never enforced (see the Antigravity note below).

**Apex — the second rung inside strong.** On a CLI that exposes more than one
model above balanced (Claude: opus-class, then fable-class), `strong` resolves
to the FIRST rung and the ceiling is reserved as **apex** — a dispatch-time
escalation, not a tier label: agent overlays never carry it and `TIER_MODELS`
does not encode it. Strong review asks "is this done right per the existing
pattern?"; apex asks "is the pattern itself right?". Escalate a strong
dispatch to apex only on a trigger: (1) irreversible with no rollback
(destructive migration, key rotation, live money movement); (2) novel design
with no existing pattern to diff against; (3) deep cross-system reasoning
(races on financial invariants, distributed consistency); (4) explicit user
ask. No trigger → strong is
the paid ceiling. A CLI with no strong pin below a ceiling (Codex, which pins
nothing; Antigravity, whose balanced and strong resolve to the same id) collapses apex into strong. The dispatch-log `override` field records
which rung was sent.

**Effort** layers on top of the model. Claude uses `effort`, Codex uses `model_reasoning_effort` (documented levels `low` / `medium` / `high` / `xhigh` / `max` / `ultra`, per the official subagent docs, re-verified 2026-09-03 against codex 0.147.0 — `max` = "especially demanding reasoning", `ultra` = "deepest reasoning" AND "proactive delegation": the agent spawns its own sub-agents, how many is the model's call per task — rolepod never prescribes a count).

- `xhigh` — the effort ceiling on every CLI (Claude `effort`, Codex `model_reasoning_effort`) — security-engineer only (breach blast radius). **Never `max` or `ultra` on a role** (v2.75.0; `ultra` was pinned until v2.73, `max` in v2.74): Ultra is a fan-out, so the adversarial reviewer would spawn children inheriting its model, strong × N per dispatch; `max` sits above the doctrine ceiling — depth past `xhigh` buys little on a review and bills the strong slot's full price.
- `high` — strong tier (system-architect, universal-reviewer) + balanced-tier roles where reasoning depth pays off (billing-engineer, ai-ml-engineer, performance-engineer, qa-tester).
- `medium` — everything else, and deliberately the floor for every agent whose
  artifact feeds downstream phases (specs, ADRs, implementations). Effort cuts
  only thinking tokens — pennies at cheap/balanced output pricing — while a
  shallower artifact taxes every later phase that consumes it. Do not trade
  down for cost here; the lever is delegation, not effort.
- `low` — scout only: mechanical sweeps whose deliverable is pointers, not
  judgment. The one role where nothing downstream consumes its reasoning.

**Codex** role files name no model: the user's `[agents] default_subagent_model` (else the Lead's model) runs every rolepod role, and the tier shows only as `model_reasoning_effort`.

**Antigravity.** Google retired the standalone Gemini CLI for individual accounts on 2026-06-18 (removed from rolepod in v2.177.0 — no adapter, no `--target=gemini`); the live path is Antigravity (`agy`). `TIER_MODELS["antigravity"]` writes agy's own `gemini-3-flash-preview` / `gemini-3-pro-preview` ids into every agy agent's `model:` field (Antigravity is built on Google's Gemini model family — unrelated to the retired Gemini CLI, which shipped no adapter here), but `agy` **auto-selects** the model per task and ignores the field, so the pin is advisory only. Treat it as a comment, not an enforced knob, until an agy-native per-agent model field is verified.

## Default agent → tier mapping

| Agent | Tier | Rationale |
|---|---|---|
| `backend-developer` | balanced | Normal API/business-logic work |
| `frontend-developer` | balanced | Component + state + routing work |
| `mobile-developer` | balanced | Native + cross-platform |
| `ai-ml-engineer` | balanced | LLM/RAG features in production code |
| `data-scientist` | balanced | Analytics + pipelines |
| `qa-tester` | balanced | E2E / UI / contract test authoring, flake, spec-first test-case design |
| `performance-engineer` | balanced | Profiling + optimization with measured evidence |
| `ui-ux-designer` | balanced | Visual polish + a11y |
| `devops-sre` | balanced | Infra + CI/CD + release |
| `billing-engineer` | balanced | Money code WRITER — depth is guaranteed by the strong Lead at dispatch + the mandatory strong adversarial review on billing paths, not the writer's tier (2026-08 decision: fan-out strong across implementers measured wasteful; `effort: high` stays) |
| `security-engineer` | **strong** | Auth + secrets + crypto; wrong code = breach |
| `system-architect` | **strong** | Architecture decisions are load-bearing across the codebase |
| `universal-reviewer` | **strong** | Adversarial code review; must match implementer's depth |
| `scout` | cheap | Read-only wide sweeps — research report only, never edits |
| `content-strategist` | cheap | All human-readable written output — internal docs / ADRs / READMEs (`audience: dev`), FAQ / onboarding / user-facing copy (`audience: user`), SEO / conversion copy (`audience: prospect`) |

## Override path

Change what a whole tier resolves to: edit `TIER_MODELS` in `build/merge-agent.py` (the one map) and re-render — e.g. point Claude `strong` back at `inherit` (the reviewer then follows the Lead — no hook lifts it since v2.176.0). Codex has no line: its model is the user's `default_subagent_model`. Move a single agent between tiers: edit its `tier:` in the per-CLI overlays (or just the one CLI you use).

Per-user override: edit `~/.claude/agents/<agent-name>.md` frontmatter `model:` field on the installed file. User override takes precedence (Claude Code precedence: user > project > plugin defaults).

Per-task override: explicit user instruction always wins. If the user says "use opus for this," that overrides the tier policy for the turn.

## When to escalate tier

Auto-escalate to the **strong** tier for adversarial review (regardless of agent default) when:

- Touching auth / authn / authz / authentication / authorization / billing / payment / migration / credit / permission / secret / crypto / token / oauth / jwt / sso / saml / webhook / stripe / paypal / charge / invoice paths (illustrative — the canonical regex lives in `hooks/precommit-gate.sh` / `gate-reminder.sh`, parity-pinned by lean-surface).
- About to ship to production (final `finish-work` review).
- 3rd agent attempt on same surface (per CLAUDE.md hard stops).
- The user explicitly asks for a stronger review.

On Claude, `precommit-gate.sh` blocks the commit of a high-risk diff without a finished strong reviewer since the last commit (one hard checkpoint, at commit); `gate-reminder.sh` prints one line on a high-risk edit only when that commit would block now. The tier policy makes the *which* reviewer explicit.

## Cross-family externals run their own default model

`TIER_MODELS` — and every effort pin — governs the CLI that is the **Lead**
(its subagents, its role files, its fan-out). A cross-family external
(`rolepod-cross-family --kind review|consult|critique`) is another owner's
CLI: it runs whatever that CLI's config sets as default, and the runner
never passes a model or effort flag (the phase-log records `model:
default`). The only place a model flag is legitimate on an external call is
the **vertical fallback** — the Lead consulting its own CLI at a stronger
tier — because that CLI IS the Lead. The pool is **opt-in** and the user's
choice: `~/.rolepod/cross-family` (machine) / `.rolepod/cross-family`
(project), one CLI per line; no file or `none` = off, and the SessionStart
context asks once rather than enabling anything; the runner excludes the
Lead's own CLI and drops members that fail at invoke.

## Advisor mode interplay (Claude Code)

Claude Code's native Advisor mode (`/advisor <model>` / `advisorModel` in
settings) lets the Lead consult a stronger model inline, server-side. It is
the same philosophy as this policy — cheap executor, targeted escalation —
and Anthropic's published numbers back the pairing (Sonnet + Opus advisor:
+2.7pp SWE-bench Multilingual at −11.9% cost per task). Three interplay
rules keep it from fighting rolepod's own consult machinery:

1. **Advisor IS the vertical-consult channel when configured.** debug-issue
   §9's vertical fallback uses
   the inline advisor instead of shelling out to the CLI's strongest model.
   The discipline is unchanged: ONE consult, one advisor-informed round,
   never a second parallel consult for the same event — advisor on does not
   mean consult twice.
2. **Advisor never satisfies the adversarial pass.** It advises the author
   inside the author's own context and CLI — Iron Rule 2 still requires
   a fresh reviewer in a different CLI on high-risk diffs. "The advisor looked at
   it" is a limitation note, not a review.
3. **Subagents inherit the configured advisor** (with the pairing check
   re-run against each subagent's own model). A haiku scout carrying an
   opus advisor can quietly consult expensive tokens from a cheap
   dispatch. Claude Code exposes NO cap setting — control is
   instruction-level only: cheap-tier task briefs state "do not consult
   the advisor" (the sweep needs pointers, not judgment), and
   session-level offs are `/advisor off` or
   `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1`. Advisor input is billed on the
   full conversation at advisor rates and is never cached between calls
   — long sessions pay more per consult; rolepod's curated-brief
   subagent consults stay bounded by comparison.

## Lead tier choice — the session-level decision

The tier table governs subagents; the Lead's own model is the user's session
choice, and under rolepod the right default is a **balanced-class Lead**: with
delegation active the Lead is mostly a controller (briefs, verdicts, commits),
and the escalation valves — debug-issue's cross-model consult, strong-tier
reviewers, BLOCKED redispatch — pull strong-class intelligence in per-turn,
so a strong-class session pays flagship price for controller work. On Claude
Code, balanced Lead + a stronger advisor (`/advisor opus`) is the
numbers-backed sweet spot — better and cheaper than either model solo (see
Advisor mode interplay above). Open with
a strong-class Lead only when the day's MAIN work is architecture, a
multi-day debug, or a high-risk domain. The router's Lead-tier fit nudge
states this once per session when it detects a mismatch — tier classes only,
never model names, on every CLI including large multi-provider catalogs
(OpenRouter): map classes once per session onto the user's OPTED-IN model
set — configured providers / models they already pay for — and stay
consistent. The full catalog is exposure, not authorization: a rung
costlier than anything the user configured is dispatched only after
surfacing the cost. The opted-in ceiling is that machine's apex; strong
resolving below opus-class is a review-depth LIMITATION the report must
record. Fixed-menu CLIs are unaffected — there the exposed set IS the
opted-in set.

## Per-CLI tier verification — what is mechanical where

The install-half ("do the agent files on disk map tier→model as intended")
and the runtime-half ("did this dispatch actually run the intended class")
have different ceilings per CLI:

| CLI | Install-half | Runtime-half |
|---|---|---|
| Claude | ✓ mechanical — strong = `opus` in frontmatter (v2.104.0) | ✓ via transcript scan — subagent transcripts (`~/.claude/projects/<project>/<session>/subagents/**/agent-*.jsonl`) record `message.model` per turn; grep the agent's transcript to prove which model actually ran (verified 2026-08-05: four haiku-dispatched scouts all show `claude-haiku-4-5` on disk). The dispatch-log (with `lead_class`) stays the intent record; the transcript is the execution proof. Reading tip: the MAIN session file is the Lead's own turns — do not read its `model` histogram as dispatch proof (a Lead that flips `/model` shows several models there). |
| Codex | n/a — role files pin no model (the user's `default_subagent_model`) | doctrine — no hook logs the child's model (removed in v2.176.0) |
| Cursor | n/a — the agent spec has no model field | doctrine + dispatch-log |
| opencode | n/a by design — big catalogs map classes once per session (see AGENTS specifics) | doctrine + dispatch-log |
| Antigravity | ✓ mechanical — `-preview` ids WILL rot | ✗ field is advisory — dispatch-log audit |

The dispatch-log (`{"phase":"dispatch","tier":"strong","override":...}` in
`phase-log.jsonl`) is the CLI-agnostic audit: it cannot
prove what ran, but it makes every silent-downgrade decision visible after
the fact.
