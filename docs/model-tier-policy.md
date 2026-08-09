<!-- Model-tier routing policy — referenced by using-rolepod router + agent frontmatter. -->

## Model tiers

Rolepod ships a cost-aware policy that maps **role + risk → model tier**. Each agent's per-CLI overlay carries only a **`tier:`** (a stable, semantic label) — never a model name. `build/merge-agent.py`'s `TIER_MODELS` resolves tier → model per CLI at render time, so a model rename or a new generation is **one edit there**, not 48 across the overlays. This table is the human-readable view of that map; the static gate verifies the two never drift.

| Tier | Claude | Codex | Gemini | Use for |
|---|---|---|---|---|
| **cheap** | `haiku` | `gpt-5.6-luna` | `gemini-3-flash-preview` | docs, PM (feature + commercial), customer-facing copy, marketing, FAQ, ADR drafting, read-only scout sweeps — repeatable structured output, no deep architectural reasoning |
| **balanced** | `sonnet` | `gpt-5.6-terra` | `gemini-3-pro-preview` | normal implementation (backend, frontend, mobile, AI/ML features, data pipelines, perf, UI/UX, devops), QA test writing — the default working tier |
| **strong** | `inherit` | `gpt-5.6-sol` | `gemini-3-pro-preview` | architecture, billing/payments, security implementation, migrations, adversarial code review — wrong code costs real money or blocks recovery; reviewer must match implementer depth |

**Why the tiers resolve the way they do**

- **cheap / balanced pin LOW on purpose.** A cheap component stays cheap even under an expensive Lead — that is the cost saving. Claude uses aliases (`haiku` / `sonnet`), which auto-resolve to the newest model of that family, so a Claude version bump needs no edit.
- **strong on Claude is `inherit`** — the subagent runs on the **same model as the Lead**. This is the direct expression of "reviewer must match implementer depth": a Fable Lead gets a Fable reviewer (never downgraded to a fixed older model), and there is no model name to go stale. Claude Code supports `inherit` and treats it as the default.
- **The high-risk floor is NOT this pin.** A Lead weaker than the strong tier (e.g. a Sonnet Lead touching billing) still gets an independent strong check, because `review-code`'s Iron Rule mandates a **cross-family** adversarial pass (a different vendor's CLI) on high-risk surfaces. Depth on money/security paths is guaranteed by that pass, not by pinning a model here.
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

**Effort** layers on top of the model. Claude uses `effort`, Codex uses `model_reasoning_effort` (documented levels `low` / `medium` / `high` / `xhigh` / `ultra`, per the official subagent docs, verified against codex 0.144.1); Gemini has no effort field.

- CLI effort ceiling (`xhigh` on Claude, `ultra` on Codex) — security-engineer only (breach blast radius): the role rides each CLI's highest documented level, never an undocumented one.
- `high` — strong tier (system-architect, billing-engineer, universal-reviewer) + balanced-tier roles where reasoning depth pays off (ai-ml-engineer, performance-engineer, qa-tester).
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
| `billing-engineer` | **strong** | Money flows; wrong code = revenue/audit risk |
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

- Touching auth / authn / authz / billing / payment / migration / credit / permission / secret / crypto / token / oauth / jwt / sso / saml / webhook / stripe / paypal / charge / invoice paths.
- About to ship to production (final `finish-work` review).
- 3rd agent attempt on same surface (per CLAUDE.md hard stops).
- User explicit "use careful mode" or `/rolepod` invocation.

The `gate-reminder.sh` and `precommit-gate.sh` hooks already block edits on high-risk paths without a reviewer agent dispatched. The tier policy makes the *which* reviewer explicit.

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
   inside the author's own context and family — Iron Rule 2 still requires
   a fresh cross-family reviewer on high-risk diffs. "The advisor looked at
   it" is a limitation note, not a review.
3. **Subagents inherit the configured advisor.** A haiku scout carrying an
   opus/fable advisor can quietly consult expensive tokens from a cheap
   dispatch — set `max_uses` to cap consult frequency on dispatch-heavy
   sessions, and remember advisor input is billed on the full conversation
   at advisor rates (long sessions pay more per consult; rolepod's
   curated-brief subagent consults stay bounded by comparison).

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
| Claude | ✓ mechanical — `make doctor` asserts installed `model:` per tier | ✓ via transcript scan — subagent transcripts (`~/.claude/projects/<project>/*.jsonl`) record `message.model` per turn; grep the agent's transcript to prove which model actually ran (verified 2026-08-05: four haiku-dispatched scouts all show `claude-haiku-4-5` on disk). The dispatch-log stays the intent record; the transcript is the execution proof. |
| Codex | ✓ mechanical — doctor asserts TOML `model =` per tier; pinned ids rot with CLI updates (doctor prints them) | ◐ hook-reported — SubagentStop stdin carries `model`; `subagent-model-log.sh` appends a dispatch-proof line per finished subagent (provenance hook-stdin, whether it is the subagent's own model or the parent's is not live-verified upstream; the logged `agent_transcript_path` allows manual deep audit) |
| Gemini | ✓ mechanical — doctor asserts `model:` per tier; `-preview` ids WILL rot | ✗ field is advisory — dispatch-log audit |
| Cursor | n/a — the agent spec has no model field | doctrine + dispatch-log |
| opencode | n/a by design — big catalogs map classes once per session (see AGENTS specifics) | doctrine + dispatch-log |
| Antigravity | n/a — agy auto-selects the model per task | ◐ hook-reported — PreInvocation stdin carries `modelName`; `model-log.sh` appends a dispatch-proof line on every model CHANGE (deduped), the only visibility into what agy actually picked |

The dispatch-log (`{"phase":"dispatch","tier":"strong","override":...}` in
`phase-log.jsonl`, read by `make stats`) is the CLI-agnostic audit: it cannot
prove what ran, but it makes every silent-downgrade decision visible after
the fact.
