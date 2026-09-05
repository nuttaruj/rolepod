<!-- Model-tier routing policy — referenced by using-rolepod router + agent frontmatter. -->

## Model tiers

Rolepod ships a cost-aware policy that maps **role + risk → model tier**. Each agent's per-CLI overlay carries only a **`tier:`** (a stable, semantic label) — never a model name. `build/merge-agent.py`'s `TIER_MODELS` resolves tier → model per CLI at render time, so a model rename or a new generation is **one edit there**, not 48 across the overlays. This table is the human-readable view of that map; the static gate verifies the two never drift.

| Tier | Claude | Codex | Gemini | Use for |
|---|---|---|---|---|
| **cheap** | `haiku` | `gpt-5.6-luna` | `gemini-3-flash-preview` | docs, PM (feature + commercial), customer-facing copy, marketing, FAQ, ADR drafting, read-only scout sweeps — repeatable structured output, no deep architectural reasoning |
| **balanced** | `sonnet` | `gpt-5.6-terra` | `gemini-3-pro-preview` | ALL implementation — high-risk paths included (billing / payments / migrations: the net is the strong Lead at dispatch + the strong adversarial review floor, never the dev's tier), QA test writing — the default working tier |
| **strong** | `inherit` | `gpt-5.6-sol` | `gemini-3-pro-preview` | architecture, security audit, adversarial code review — wrong judgment costs real money or blocks recovery; reviewer must match implementer depth |

**Why the tiers resolve the way they do**

- **cheap / balanced pin LOW on purpose.** A cheap component stays cheap even under an expensive Lead — that is the cost saving. Claude uses aliases (`haiku` / `sonnet`), which auto-resolve to the newest model of that family, so a Claude version bump needs no edit.
- **strong on Claude is `inherit` — with a hook-side floor (v2.47.0).** The subagent runs on the **same model as the Lead**: a Fable Lead gets a Fable reviewer (never downgraded to a fixed older model), and there is no model name to go stale. The cost of `inherit` is the silent downgrade under a low Lead — and the measured reality is that Leads DO run sonnet (one project: 66 % of turns) and never wrote the explicit strong override doctrine asked for (0 across the project). So `workflow-tier-nudge.sh` supplies what frontmatter cannot express — `max(session, opus)`: `security-engineer` / `universal-reviewer` dispatched with no `model` under a **known-low** Lead (haiku / sonnet family) get `model: opus` written into the Agent call (`updatedInput`); a strong or unknown Lead is left alone. Explicit `model:` on the call is never rewritten. Result: **role → tier is Lead-independent in both directions** — writers pinned balanced under an opus Lead, reviewers lifted to strong under a sonnet Lead (live-verified 2026-08-17: lifted reviewer transcript = `claude-opus-5`) — and the commit gate counts a strong reviewer only when it was not explicitly dispatched low. Residual edge: the very first assistant action of a fresh session has no prior turn to read the Lead from → not lifted, logged as `floor: missed`.
- **The Workflow path is where cost leaks, and it cannot be pinned by frontmatter (v2.48.0).** Workflow `agent()` calls default to the Lead's model and no plugin config changes that default; a hook cannot safely rewrite a script either. So the fleet-tier gate in `workflow-tier-nudge.sh` denies, under a strong-class Lead, a fan-out that is model-less, that pastes ONE balanced tier on every stage, or that runs a judgment stage below the Lead — until the script names a tier per stage (or states `// tier-reason: <why>`). v2.50.0 widened it after four probe tasks under an opus Lead all came back sonnet-on-every-stage: the first gate was passed, not applied. This is the one place doctrine was measured to fail on its own — six fleets in one day at opus/fable with the nudge ignored — and it is exactly the ultracode usage pattern (auto-Workflow under an opus/fable Lead). Under a low-class Lead the gate is silent on cost: inherit is already the cheap choice there — but not on the judge floor: since v2.72.0 a high-risk fleet whose judgment stage carries no strong tier is denied under any Lead, and v2.74.0 closed the two holes that let a sonnet Lead run a 30-agent billing review at sonnet (CourtBook `technician-payout-review`): a strong-role `agentType` renders `inherit` and now counts as strong only under a strong Lead, and the prescribed fix is **one strong slot** (the security reviewer or one final adjudicator at `opus`, every fan-out at sonnet/haiku) — a strong pin on a fan-out / ≥2 stages / a sweep under a low Lead is denied as `strong-spread` and never yields. The commit gate mirrors it: a Workflow `agentType` strong reviewer with no explicit strong `model:` counts as the strong pass only when the Lead is not known-low.
- **The high-risk floor is NOT this pin.** A Lead weaker than the strong tier (e.g. a Sonnet Lead touching billing) still gets an independent strong check, because `review-code`'s Iron Rule mandates a **cross-family** adversarial pass (a different vendor's CLI) on high-risk surfaces, and the commit gate requires a strong reviewer dispatch since the last commit. Depth on money/security paths is guaranteed by those, not by pinning a model here.
- **Cross-CLI: pinning is already the rule elsewhere.** Codex (`gpt-5.6-sol`) and Gemini (`gemini-3-pro-preview`) pin strong to an explicit id — they expose no `inherit`, so the "silent downgrade" class of failure does not exist there and the hook floor is Claude-only by construction (the shared `precommit-gate.sh` / `gate-reminder.sh` changes are inert where no transcript is passed). Their pins are versioned ids and DO rot on rename — `make doctor` prints them; nothing new. What DOES carry over is the fan-out shape: a Codex / Gemini native subagent spawned from a plain prompt (no rolepod role) inherits the Lead exactly like a Workflow `agent()` call, and no hook can deny it there (Codex `SubagentStart` is post-spawn). The one-strong-slot rule is therefore doctrine on those CLIs (router skill, rendered everywhere): the judgment slot gets the strong id (`gpt-5.6-sol` / `gemini-3-pro-preview`), the per-item fan-out stays balanced/cheap. Codex resolves an un-pinned child by explicit spawn value → `agents.default_subagent_model` / `agents.default_subagent_reasoning_effort` → the parent (official precedence); a rolepod role file always pins (strong = `sol`), so those two config keys decide what Ultra's proactive delegation and every plain-prompt spawn cost. The Lead CAN tier a child itself: `spawn_agent` accepts `model` / `reasoning_effort` (binary strings, codex 0.147.0: "Spawned agents inherit your current model by default … set `model` only when an explicit override is needed" and "Only set `model` or `reasoning_effort` when explicitly requested by the user, applicable `AGENTS.md` instructions, or skill…"; full-history forks accept no override; the V2 picker list is gated by `expose_spawn_agent_model_overrides`). rolepod's Codex `AGENTS.md` IS that instruction — tier per child, one named strong role as the judgment slot, child count the model's call. The config floor `[agents] default_subagent_model = "gpt-5.6-terra"` + `default_subagent_reasoning_effort = "high"` catches every spawn that omits `model` (Ultra's proactive delegation included); `make doctor` flags the key when unset or strong-class, and flags any installed role still pinned `ultra`. Effort on a balanced model never clears the strong floor.
- **Rename-safety of the Claude floor.** The hook classifies the Lead by FAMILY word only (`haiku` / `sonnet` / `opus|fable|mythos`), never a version — `claude-sonnet-5 → claude-sonnet-6` changes nothing — and writes the `opus` alias, which Claude Code resolves to the newest of that family. Failure modes are asymmetric on purpose: an unknown family (a new tier, a gateway id) is left untouched, i.e. today's behavior, and `dispatch-auto-log.sh` records `lead_class: unknown` so `make stats` shows the blind spot; if the `opus` alias were ever retired the Agent call would fail loudly (visible), not silently downgrade.
- **strong on Codex pins its ceiling (`sol`)** — Codex exposes no `inherit`, so the top model is the safe default: an upgrade for a lower Lead, a match when the Lead is already `sol`.
- **Gemini values are advisory.** Antigravity (`agy`) auto-selects the model per task and does not consume this field; it is recorded only to keep the frozen Gemini-CLI adapter internally consistent (see the Antigravity note below).

**Apex — the second rung inside strong.** On a CLI that exposes more than one
model above balanced (Claude: opus-class, then fable-class), `strong` resolves
to the FIRST rung and the ceiling is reserved as **apex** — a dispatch-time
escalation, not a tier label: agent overlays never carry it and `TIER_MODELS`
does not encode it. Strong review asks "is this done right per the existing
pattern?"; apex asks "is the pattern itself right?". Escalate a strong
dispatch to apex only on a trigger: (1) irreversible with no rollback
(destructive migration, key rotation, live money movement); (2) novel design
with no existing pattern to diff against; (3) deep cross-system reasoning
(races on financial invariants, distributed consistency); (4) the previous
strong round missed blockers; (5) explicit user ask. No trigger → strong is
the paid ceiling. A CLI whose strong pin already IS its ceiling (Codex `sol`;
Gemini) collapses apex into strong. The dispatch-log `override` field records
which rung was sent, so `make stats` audits apex use after the fact.

**Effort** layers on top of the model. Claude uses `effort`, Codex uses `model_reasoning_effort` (documented levels `low` / `medium` / `high` / `xhigh` / `max` / `ultra`, per the official subagent docs, re-verified 2026-09-03 against codex 0.147.0 — `max` = "especially demanding reasoning", `ultra` = "deepest reasoning" AND "proactive delegation": the agent spawns its own sub-agents, how many is the model's call per task — rolepod never prescribes a count); Gemini has no effort field.

- `xhigh` — the effort ceiling on every CLI (Claude `effort`, Codex `model_reasoning_effort`) — security-engineer only (breach blast radius). **Never `max` or `ultra` on a role** (v2.75.0; `ultra` was pinned until v2.73, `max` in v2.74): Ultra is a fan-out, so the adversarial reviewer would spawn children inheriting `sol`, strong × N per dispatch; `max` sits above the doctrine ceiling — depth past `xhigh` buys little on a review and bills the strong slot's full price.
- `high` — strong tier (system-architect, universal-reviewer) + balanced-tier roles where reasoning depth pays off (billing-engineer, ai-ml-engineer, performance-engineer, qa-tester).
- `medium` — everything else, and deliberately the floor for every agent whose
  artifact feeds downstream phases (specs, ADRs, implementations). Effort cuts
  only thinking tokens — pennies at cheap/balanced output pricing — while a
  shallower artifact taxes every later phase that consumes it. Do not trade
  down for cost here; the lever is delegation, not effort.
- `low` — scout only: mechanical sweeps whose deliverable is pointers, not
  judgment. The one role where nothing downstream consumes its reasoning.

**Codex** runs the GPT-5.6 line — `luna` (fast/cheap), `terra` (balanced workhorse), `sol` (deepest). All three verified against the local `codex exec -m`.

**Gemini / Antigravity.** Google retired the standalone Gemini CLI for individual accounts on 2026-06-18; the live path is now Antigravity (`agy`), which **auto-selects** the model per task and does not consume a per-agent API model id. The `gemini-3-*-preview` values above are frozen artifacts of the retired Gemini-CLI adapter (kept only so the frozen adapter stays internally consistent; the ids still resolve as aliases). On `agy` the tier is advisory, not enforced. Do not treat these ids as an active knob until an agy-native per-agent model field is verified — pinning an unverified id there would silently break dispatch.

## Default agent → tier mapping

| Agent | Tier | Rationale |
|---|---|---|
| `backend-developer` | balanced | Normal API/business-logic work |
| `frontend-developer` | balanced | Component + state + routing work |
| `mobile-developer` | balanced | Native + cross-platform |
| `ai-ml-engineer` | balanced | LLM/RAG features in production code |
| `data-scientist` | balanced | Analytics + pipelines |
| `qa-tester` | balanced | Test authoring, business-logic verify |
| `performance-engineer` | balanced | Profiling + optimization with measured evidence |
| `ui-ux-designer` | balanced | Visual polish + a11y |
| `devops-sre` | balanced | Infra + CI/CD + release |
| `billing-engineer` | balanced | Money code WRITER — depth is guaranteed by the strong Lead at dispatch + the mandatory strong adversarial review on billing paths, not the writer's tier (2026-08 decision: fan-out strong across implementers measured wasteful; `effort: high` stays) |
| `security-engineer` | **strong** | Auth + secrets + crypto; wrong code = breach |
| `system-architect` | **strong** | Architecture decisions are load-bearing across the codebase |
| `universal-reviewer` | **strong** | Adversarial code review; must match implementer's depth |
| `product-manager` | cheap | Spec writing + prioritization |
| `scout` | cheap | Read-only wide sweeps — research report only, never edits |
| `content-strategist` | cheap | All human-readable written output — internal docs / ADRs / READMEs (`audience: dev`), FAQ / onboarding / user-facing copy (`audience: user`), SEO / conversion copy (`audience: prospect`) |

## Override path

Change what a whole tier resolves to: edit `TIER_MODELS` in `build/merge-agent.py` (the one map) and re-render — e.g. point Claude `strong` at a fixed `opus` instead of `inherit`, or bump the Codex line to a new generation. Move a single agent between tiers: edit its `tier:` in the three overlays (or just the one CLI you use).

Per-user override: edit `~/.claude/agents/<agent-name>.md` frontmatter `model:` field on the installed file. User override takes precedence (Claude Code precedence: user > project > plugin defaults).

Per-task override: explicit user instruction always wins. If the user says "use opus for this," that overrides the tier policy for the turn.

## When to escalate tier

Auto-escalate to the **strong** tier for adversarial review (regardless of agent default) when:

- Touching auth / authn / authz / authentication / authorization / billing / payment / migration / credit / permission / secret / crypto / token / oauth / jwt / sso / saml / webhook / stripe / paypal / charge / invoice paths (illustrative — the canonical regex lives in `hooks/precommit-gate.sh` / `gate-reminder.sh`, parity-pinned by lean-surface).
- About to ship to production (final `finish-work` review).
- 3rd agent attempt on same surface (per CLAUDE.md hard stops).
- User explicit "use careful mode" or `/rolepod` invocation.

`gate-reminder.sh` names, on every high-risk edit, what the commit gate will require, and `precommit-gate.sh` blocks the commit of a high-risk diff without a strong reviewer dispatched since the last commit (v2.47.0: one hard checkpoint, at commit). The tier policy makes the *which* reviewer explicit.

## Cross-family externals run their own default model

`TIER_MODELS` — and every effort pin — governs the CLI that is the **Lead**
(its subagents, its role files, its fan-out). A cross-family external
(`rolepod-cross-family --kind review|consult|advise`) is another owner's
CLI: it runs whatever that CLI's config sets as default, and the runner
never passes a model or effort flag (the phase-log records `model:
default`). The only place a model flag is legitimate on an external call is
the **vertical fallback** — the Lead consulting its own CLI at a stronger
tier — because that CLI IS the Lead. The pool is **opt-in** and the user's
choice: `~/.rolepod/cross-family` (machine) / `.rolepod/cross-family`
(project), one CLI per line; no file or `none` = off, and the SessionStart
context asks once rather than enabling anything; the runner excludes the
Lead's family and drops members that fail at invoke. Doctor prints the
resolved pool; `ROLEPOD_DOCTOR_PROBE=1 make doctor` sends each member a
one-line prompt to prove it answers.

## Advisor mode interplay (Claude Code)

Claude Code's native Advisor mode (`/advisor <model>` / `advisorModel` in
settings) lets the Lead consult a stronger model inline, server-side. It is
the same philosophy as this policy — cheap executor, targeted escalation —
and Anthropic's published numbers back the pairing (Sonnet + Opus advisor:
+2.7pp SWE-bench Multilingual at −11.9% cost per task). Three interplay
rules keep it from fighting rolepod's own consult machinery:

1. **Advisor IS the vertical-consult channel when configured.** debug-issue
   §9's vertical fallback and review-code's fix-round circuit breaker use
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
| Claude | ✓ mechanical — `make doctor` asserts installed `model:` per tier; strong = `inherit` + the tier-nudge floor lifts `security-engineer` / `universal-reviewer` to `opus` under a low Lead | ✓ via transcript scan — subagent transcripts (`~/.claude/projects/<project>/<session>/subagents/**/agent-*.jsonl`) record `message.model` per turn; grep the agent's transcript to prove which model actually ran (verified 2026-08-05: four haiku-dispatched scouts all show `claude-haiku-4-5` on disk). The dispatch-log (now with `lead_class` + `override: auto-upgrade`) stays the intent record; the transcript is the execution proof. Reading tip: the MAIN session file is the Lead's own turns — do not read its `model` histogram as dispatch proof (a Lead that flips `/model` shows several models there). |
| Codex | ✓ mechanical — doctor asserts TOML `model =` per tier; pinned ids rot with CLI updates (doctor prints them) | ◐ hook-reported — SubagentStop stdin carries `model`; `subagent-model-log.sh` appends a dispatch-proof line per finished subagent (provenance hook-stdin, whether it is the subagent's own model or the parent's is not live-verified upstream; the logged `agent_transcript_path` allows manual deep audit) |
| Gemini | ✓ mechanical — doctor asserts `model:` per tier; `-preview` ids WILL rot | ✗ field is advisory — dispatch-log audit |
| Cursor | n/a — the agent spec has no model field | doctrine + dispatch-log |
| opencode | n/a by design — big catalogs map classes once per session (see AGENTS specifics) | doctrine + dispatch-log |
| Antigravity | n/a — agy auto-selects the model per task | ◐ hook-reported — PreInvocation stdin carries `modelName`; `model-log.sh` appends a dispatch-proof line on every model CHANGE (deduped), the only visibility into what agy actually picked |

The dispatch-log (`{"phase":"dispatch","tier":"strong","override":...}` in
`phase-log.jsonl`, read by `make stats`) is the CLI-agnostic audit: it cannot
prove what ran, but it makes every silent-downgrade decision visible after
the fact.
